import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum HCVPhotoDetailVerdict {
  conforming,
  modified,
  inconclusive,
}

class HCVPhotoDetailComparison {
  const HCVPhotoDetailComparison({
    required this.verdict,
    required this.meanLumaDifference,
    required this.meanRgbDifference,
    required this.maxTileMeanDifference,
    required this.maxTileHighDifferenceRatio,
    required this.localizedTamperTiles,
  });

  final HCVPhotoDetailVerdict verdict;
  final double meanLumaDifference;
  final double meanRgbDifference;
  final double maxTileMeanDifference;
  final double maxTileHighDifferenceRatio;
  final int localizedTamperTiles;
}

class HCVPhotoDetailComparator {
  const HCVPhotoDetailComparator._();

  static const int width = 256;
  static const int height = 256;
  static const int gridColumns = 16;
  static const int gridRows = 16;
  static const int _rgbChannels = 3;
  static const int _frameBytes = width * height * _rgbChannels;
  static const int _tileWidth = width ~/ gridColumns;
  static const int _tileHeight = height ~/ gridRows;

  static const double _highDifferencePixel = 18.0;
  static const double _localizedMeanThreshold = 3.5;
  static const double _localizedHighRatioThreshold = 0.06;
  static const double _strongLocalizedMeanThreshold = 6.0;
  static const double _strongLocalizedHighRatioThreshold = 0.035;
  static const double _globalMeanLumaModifiedThreshold = 6.0;
  static const double _globalMeanRgbModifiedThreshold = 8.0;
  static const double _conformingMeanLumaThreshold = 3.0;
  static const double _conformingMeanRgbThreshold = 4.0;
  static const double _conformingMaxTileMeanThreshold = 3.5;
  static const double _conformingMaxHighRatioThreshold = 0.06;

  static Future<HCVPhotoDetailComparison> compareFiles(
    String expectedPath,
    String currentPath,
  ) async {
    final expected = await _normalizeRgb(expectedPath);
    final current = await _normalizeRgb(currentPath);
    return compareNormalizedRgb(expected, current);
  }

  static HCVPhotoDetailComparison compareNormalizedRgb(
    Uint8List expected,
    Uint8List current,
  ) {
    if (expected.length != _frameBytes || current.length != _frameBytes) {
      return const HCVPhotoDetailComparison(
        verdict: HCVPhotoDetailVerdict.inconclusive,
        meanLumaDifference: double.infinity,
        meanRgbDifference: double.infinity,
        maxTileMeanDifference: double.infinity,
        maxTileHighDifferenceRatio: 1,
        localizedTamperTiles: 0,
      );
    }

    final expectedLuma = _blurredLuma(expected);
    final currentLuma = _blurredLuma(current);

    var totalLumaDifference = 0.0;
    var totalRgbDifference = 0.0;
    for (var i = 0; i < expectedLuma.length; i++) {
      totalLumaDifference += (expectedLuma[i] - currentLuma[i]).abs();
    }
    for (var i = 0; i < _frameBytes; i++) {
      totalRgbDifference += (expected[i] - current[i]).abs();
    }

    final meanLumaDifference =
        totalLumaDifference / expectedLuma.length;
    final meanRgbDifference =
        totalRgbDifference / _frameBytes;

    var maxTileMeanDifference = 0.0;
    var maxTileHighDifferenceRatio = 0.0;
    var localizedTamperTiles = 0;

    for (var ty = 0; ty < gridRows; ty++) {
      for (var tx = 0; tx < gridColumns; tx++) {
        var tileDifference = 0.0;
        var highDifferencePixels = 0;
        for (var y = ty * _tileHeight;
            y < (ty + 1) * _tileHeight;
            y++) {
          for (var x = tx * _tileWidth;
              x < (tx + 1) * _tileWidth;
              x++) {
            final index = y * width + x;
            final difference =
                (expectedLuma[index] - currentLuma[index]).abs();
            tileDifference += difference;
            if (difference >= _highDifferencePixel) {
              highDifferencePixels++;
            }
          }
        }

        const tilePixels = _tileWidth * _tileHeight;
        final tileMeanDifference = tileDifference / tilePixels;
        final highDifferenceRatio = highDifferencePixels / tilePixels;
        maxTileMeanDifference =
            max(maxTileMeanDifference, tileMeanDifference);
        maxTileHighDifferenceRatio =
            max(maxTileHighDifferenceRatio, highDifferenceRatio);

        final localizedTamper =
            (tileMeanDifference >= _localizedMeanThreshold &&
                    highDifferenceRatio >=
                        _localizedHighRatioThreshold) ||
                (tileMeanDifference >= _strongLocalizedMeanThreshold &&
                    highDifferenceRatio >=
                        _strongLocalizedHighRatioThreshold);
        if (localizedTamper) localizedTamperTiles++;
      }
    }

    final globalTamper =
        meanLumaDifference > _globalMeanLumaModifiedThreshold ||
            meanRgbDifference > _globalMeanRgbModifiedThreshold;

    if (globalTamper || localizedTamperTiles > 0) {
      return HCVPhotoDetailComparison(
        verdict: HCVPhotoDetailVerdict.modified,
        meanLumaDifference: meanLumaDifference,
        meanRgbDifference: meanRgbDifference,
        maxTileMeanDifference: maxTileMeanDifference,
        maxTileHighDifferenceRatio: maxTileHighDifferenceRatio,
        localizedTamperTiles: localizedTamperTiles,
      );
    }

    final clearlyConforming =
        meanLumaDifference <= _conformingMeanLumaThreshold &&
            meanRgbDifference <= _conformingMeanRgbThreshold &&
            maxTileMeanDifference <=
                _conformingMaxTileMeanThreshold &&
            maxTileHighDifferenceRatio <
                _conformingMaxHighRatioThreshold;

    return HCVPhotoDetailComparison(
      verdict: clearlyConforming
          ? HCVPhotoDetailVerdict.conforming
          : HCVPhotoDetailVerdict.inconclusive,
      meanLumaDifference: meanLumaDifference,
      meanRgbDifference: meanRgbDifference,
      maxTileMeanDifference: maxTileMeanDifference,
      maxTileHighDifferenceRatio: maxTileHighDifferenceRatio,
      localizedTamperTiles: localizedTamperTiles,
    );
  }

  static Float64List _blurredLuma(Uint8List rgb) {
    final raw = Float64List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * _rgbChannels;
        raw[y * width + x] =
            0.2126 * rgb[offset] +
            0.7152 * rgb[offset + 1] +
            0.0722 * rgb[offset + 2];
      }
    }

    final blurred = Float64List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var sum = 0.0;
        var samples = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final yy = (y + dy).clamp(0, height - 1);
          for (var dx = -1; dx <= 1; dx++) {
            final xx = (x + dx).clamp(0, width - 1);
            sum += raw[yy * width + xx];
            samples++;
          }
        }
        blurred[y * width + x] = sum / samples;
      }
    }
    return blurred;
  }

  static Future<Uint8List> _normalizeRgb(String inputPath) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      throw ArgumentError('Photo not found: $inputPath');
    }

    final temp = await getTemporaryDirectory();
    final output = File(
      p.join(
        temp.path,
        'hcv_photo_detail_${DateTime.now().microsecondsSinceEpoch}.raw',
      ),
    );

    final safeInput = _escapePath(inputPath);
    final safeOutput = _escapePath(output.path);
    final command =
        "-y -i '$safeInput' -vf "
        "\"scale=$width:$height,format=rgb24\" "
        "-frames:v 1 -f rawvideo '$safeOutput'";

    try {
      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();
      if (code == null || !ReturnCode.isSuccess(code)) {
        throw StateError('PHOTO_DETAIL_NORMALIZATION_FAILED');
      }

      final bytes = await output.readAsBytes();
      if (bytes.length != _frameBytes) {
        throw StateError('PHOTO_DETAIL_RAW_SIZE_INVALID');
      }
      return Uint8List.fromList(bytes);
    } finally {
      try {
        if (await output.exists()) await output.delete();
      } catch (_) {}
    }
  }

  static String _escapePath(String value) {
    return value.replaceAll("'", r"'\\''");
  }
}
