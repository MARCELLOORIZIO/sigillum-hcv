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

  // BUILD148: keep the proven BUILD147 coarse comparator unchanged, then
  // supplement it with a higher-resolution local residual pass. The extra
  // pass is intentionally bounded: it is only allowed to turn an otherwise
  // conforming/inconclusive SHA-different photo into MODIFIED; it can never
  // turn a modified result back into conforming.
  static const int highDetailWidth = 512;
  static const int highDetailHeight = 512;
  static const int _fineGridColumns = 64;
  static const int _fineGridRows = 64;
  static const int _fineTileWidth = highDetailWidth ~/ _fineGridColumns;
  static const int _fineTileHeight = highDetailHeight ~/ _fineGridRows;
  static const int _fineFrameBytes =
      highDetailWidth * highDetailHeight * _rgbChannels;
  static const double _fineHighDifferencePixel = 18.0;
  static const double _fineTileMeanThreshold = 2.5;
  static const double _fineHighRatioThreshold = 0.03;
  static const int _fineMinimumClusterTiles = 2;
  static const int _fineMaximumSuspiciousTiles = 32;

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
    final coarse = compareNormalizedRgb(expected, current);
    if (coarse.verdict == HCVPhotoDetailVerdict.modified) return coarse;

    final expectedHigh = await _normalizeRgbAtSize(
      expectedPath,
      highDetailWidth,
      highDetailHeight,
    );
    final currentHigh = await _normalizeRgbAtSize(
      currentPath,
      highDetailWidth,
      highDetailHeight,
    );
    final fine = _fineLocalizedEvidence(expectedHigh, currentHigh);
    if (!fine.tampered) return coarse;

    return HCVPhotoDetailComparison(
      verdict: HCVPhotoDetailVerdict.modified,
      meanLumaDifference: coarse.meanLumaDifference,
      meanRgbDifference: coarse.meanRgbDifference,
      maxTileMeanDifference:
          max(coarse.maxTileMeanDifference, fine.maxTileMeanDifference),
      maxTileHighDifferenceRatio:
          max(coarse.maxTileHighDifferenceRatio, fine.maxTileHighDifferenceRatio),
      localizedTamperTiles:
          coarse.localizedTamperTiles + fine.largestClusterTiles,
    );
  }

  static bool detectsHighResolutionLocalizedTamper(
    Uint8List expected,
    Uint8List current,
  ) {
    return _fineLocalizedEvidence(expected, current).tampered;
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

    final meanLumaDifference = totalLumaDifference / expectedLuma.length;
    final meanRgbDifference = totalRgbDifference / _frameBytes;

    var maxTileMeanDifference = 0.0;
    var maxTileHighDifferenceRatio = 0.0;
    var localizedTamperTiles = 0;

    for (var ty = 0; ty < gridRows; ty++) {
      for (var tx = 0; tx < gridColumns; tx++) {
        var tileDifference = 0.0;
        var highDifferencePixels = 0;
        for (var y = ty * _tileHeight; y < (ty + 1) * _tileHeight; y++) {
          for (var x = tx * _tileWidth; x < (tx + 1) * _tileWidth; x++) {
            final index = y * width + x;
            final difference = (expectedLuma[index] - currentLuma[index]).abs();
            tileDifference += difference;
            if (difference >= _highDifferencePixel) {
              highDifferencePixels++;
            }
          }
        }

        const tilePixels = _tileWidth * _tileHeight;
        final tileMeanDifference = tileDifference / tilePixels;
        final highDifferenceRatio = highDifferencePixels / tilePixels;
        maxTileMeanDifference = max(maxTileMeanDifference, tileMeanDifference);
        maxTileHighDifferenceRatio =
            max(maxTileHighDifferenceRatio, highDifferenceRatio);

        final localizedTamper =
            (tileMeanDifference >= _localizedMeanThreshold &&
                    highDifferenceRatio >= _localizedHighRatioThreshold) ||
                (tileMeanDifference >= _strongLocalizedMeanThreshold &&
                    highDifferenceRatio >= _strongLocalizedHighRatioThreshold);
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
            maxTileMeanDifference <= _conformingMaxTileMeanThreshold &&
            maxTileHighDifferenceRatio < _conformingMaxHighRatioThreshold;

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
    final raw = _rawLuma(rgb, width, height);

    final blurred = Float64List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var sum = 0.0;
        var samples = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final yy = (y + dy).clamp(0, height - 1).toInt();
          for (var dx = -1; dx <= 1; dx++) {
            final xx = (x + dx).clamp(0, width - 1).toInt();
            sum += raw[yy * width + xx];
            samples++;
          }
        }
        blurred[y * width + x] = sum / samples;
      }
    }
    return blurred;
  }

  static Future<Uint8List> _normalizeRgb(String inputPath) {
    return _normalizeRgbAtSize(inputPath, width, height);
  }

  static Future<Uint8List> _normalizeRgbAtSize(
    String inputPath,
    int targetWidth,
    int targetHeight,
  ) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      throw ArgumentError('Photo not found: $inputPath');
    }

    final temp = await getTemporaryDirectory();
    final output = File(
      p.join(
        temp.path,
        'hcv_photo_detail_${targetWidth}x$targetHeight'
        '_${DateTime.now().microsecondsSinceEpoch}.raw',
      ),
    );

    final safeInput = _escapePath(inputPath);
    final safeOutput = _escapePath(output.path);
    final command = "-y -i '$safeInput' -vf "
        "\"scale=$targetWidth:$targetHeight,format=rgb24\" "
        "-frames:v 1 -f rawvideo '$safeOutput'";

    try {
      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();
      if (code == null || !ReturnCode.isSuccess(code)) {
        throw StateError('PHOTO_DETAIL_NORMALIZATION_FAILED');
      }

      final bytes = await output.readAsBytes();
      final expectedBytes = targetWidth * targetHeight * _rgbChannels;
      if (bytes.length != expectedBytes) {
        throw StateError('PHOTO_DETAIL_RAW_SIZE_INVALID');
      }
      return Uint8List.fromList(bytes);
    } finally {
      try {
        if (await output.exists()) await output.delete();
      } catch (_) {}
    }
  }

  static _FineLocalizedEvidence _fineLocalizedEvidence(
    Uint8List expected,
    Uint8List current,
  ) {
    if (expected.length != _fineFrameBytes ||
        current.length != _fineFrameBytes) {
      return const _FineLocalizedEvidence();
    }

    final expectedLuma =
        _rawLuma(expected, highDetailWidth, highDetailHeight);
    final currentLuma =
        _rawLuma(current, highDetailWidth, highDetailHeight);

    final suspicious = <int>{};
    var maxTileMeanDifference = 0.0;
    var maxTileHighDifferenceRatio = 0.0;

    for (var ty = 0; ty < _fineGridRows; ty++) {
      for (var tx = 0; tx < _fineGridColumns; tx++) {
        var tileDifference = 0.0;
        var highDifferencePixels = 0;
        for (var y = ty * _fineTileHeight;
            y < (ty + 1) * _fineTileHeight;
            y++) {
          for (var x = tx * _fineTileWidth;
              x < (tx + 1) * _fineTileWidth;
              x++) {
            final index = y * highDetailWidth + x;
            final difference =
                (expectedLuma[index] - currentLuma[index]).abs();
            tileDifference += difference;
            if (difference >= _fineHighDifferencePixel) {
              highDifferencePixels++;
            }
          }
        }

        const tilePixels = _fineTileWidth * _fineTileHeight;
        final tileMeanDifference = tileDifference / tilePixels;
        final highDifferenceRatio = highDifferencePixels / tilePixels;
        maxTileMeanDifference =
            max(maxTileMeanDifference, tileMeanDifference);
        maxTileHighDifferenceRatio =
            max(maxTileHighDifferenceRatio, highDifferenceRatio);

        if (tileMeanDifference >= _fineTileMeanThreshold &&
            highDifferenceRatio >= _fineHighRatioThreshold) {
          suspicious.add(ty * _fineGridColumns + tx);
        }
      }
    }

    if (suspicious.length < _fineMinimumClusterTiles ||
        suspicious.length > _fineMaximumSuspiciousTiles) {
      return _FineLocalizedEvidence(
        maxTileMeanDifference: maxTileMeanDifference,
        maxTileHighDifferenceRatio: maxTileHighDifferenceRatio,
      );
    }

    final remaining = <int>{...suspicious};
    var largestCluster = 0;
    while (remaining.isNotEmpty) {
      final seed = remaining.first;
      final queue = <int>[seed];
      remaining.remove(seed);
      var cluster = 0;

      while (queue.isNotEmpty) {
        final cell = queue.removeLast();
        cluster++;
        final cy = cell ~/ _fineGridColumns;
        final cx = cell % _fineGridColumns;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final ny = cy + dy;
            final nx = cx + dx;
            if (ny < 0 ||
                ny >= _fineGridRows ||
                nx < 0 ||
                nx >= _fineGridColumns) {
              continue;
            }
            final neighbor = ny * _fineGridColumns + nx;
            if (remaining.remove(neighbor)) queue.add(neighbor);
          }
        }
      }
      largestCluster = max(largestCluster, cluster);
    }

    return _FineLocalizedEvidence(
      tampered: largestCluster >= _fineMinimumClusterTiles,
      largestClusterTiles: largestCluster,
      maxTileMeanDifference: maxTileMeanDifference,
      maxTileHighDifferenceRatio: maxTileHighDifferenceRatio,
    );
  }

  static Float64List _rawLuma(
    Uint8List rgb,
    int frameWidth,
    int frameHeight,
  ) {
    final raw = Float64List(frameWidth * frameHeight);
    for (var y = 0; y < frameHeight; y++) {
      for (var x = 0; x < frameWidth; x++) {
        final offset = (y * frameWidth + x) * _rgbChannels;
        raw[y * frameWidth + x] = 0.2126 * rgb[offset] +
            0.7152 * rgb[offset + 1] +
            0.0722 * rgb[offset + 2];
      }
    }
    return raw;
  }

  static String _escapePath(String value) {
    return value.replaceAll("'", r"'\\''");
  }
}

class _FineLocalizedEvidence {
  const _FineLocalizedEvidence({
    this.tampered = false,
    this.largestClusterTiles = 0,
    this.maxTileMeanDifference = 0,
    this.maxTileHighDifferenceRatio = 0,
  });

  final bool tampered;
  final int largestClusterTiles;
  final double maxTileMeanDifference;
  final double maxTileHighDifferenceRatio;
}
