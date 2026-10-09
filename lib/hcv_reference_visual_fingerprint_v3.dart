import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum HCVReferenceVisualVerdict {
  conforming,
  modified,
  inconclusive,
}

class HCVReferenceVisualComparison {
  const HCVReferenceVisualComparison({
    required this.verdict,
    required this.alignedFrames,
    required this.modifiedFrames,
    required this.inconclusiveFrames,
    required this.expectedFrames,
  });

  final HCVReferenceVisualVerdict verdict;
  final int alignedFrames;
  final int modifiedFrames;
  final int inconclusiveFrames;
  final int expectedFrames;
}

class HCVReferenceVisualFingerprintV3 {
  const HCVReferenceVisualFingerprintV3._();

  static const String type = 'SIGILLUM_REFERENCE_VISUAL_FINGERPRINT';
  static const int version = 3;
  static const String algorithm = 'SIGILLUM_LOCAL_RGB_GRID_V3';
  static const int width = 128;
  static const int height = 72;
  static const int gridColumns = 16;
  static const int gridRows = 9;
  static const int videoFps = 2;
  static const int maxVideoFrames = 120;
  static const int initialAnchorFrames = 4;
  static const int _maxConformingFrameCountDelta = 1;
  static const int _featureBytesPerTile = 6;
  static const int _rgbChannels = 3;
  static const int _frameBytes = width * height * _rgbChannels;
  static const int _grayFrameBytes = width * height;
  static const int _tileWidth = width ~/ gridColumns;
  static const int _tileHeight = height ~/ gridRows;

  static const double _maxMeanLumaDifference = 6.0;
  static const double _maxSingleTileLumaDifference = 18.0;
  static const double _maxMeanChromaDifference = 8.0;
  static const double _maxMeanRgbDifference = 8.0;

  static Future<Map<String, dynamic>> buildFromPhoto(String path) async {
    final frames = await _normalizedRgbFrames(path, video: false);
    return buildFromRgbFrames(frames, mediaType: 'photo');
  }

  static Future<Map<String, dynamic>> buildFromVideo(String path) async {
    final frames = await _normalizedRgbFrames(path, video: true);
    return buildFromRgbFrames(frames, mediaType: 'video');
  }

  /// Retained for deterministic grayscale fixtures. Production media uses
  /// RGB24 normalization so tonal and colour edits remain observable.
  static Map<String, dynamic> buildFromGrayFrames(
    List<Uint8List> frames, {
    required String mediaType,
  }) {
    final rgb = <Uint8List>[];
    for (final frame in frames) {
      if (frame.length != _grayFrameBytes) {
        throw ArgumentError(
          'Normalized grayscale frame must contain exactly $_grayFrameBytes bytes',
        );
      }
      final expanded = Uint8List(_frameBytes);
      for (var i = 0; i < frame.length; i++) {
        final value = frame[i];
        final offset = i * _rgbChannels;
        expanded[offset] = value;
        expanded[offset + 1] = value;
        expanded[offset + 2] = value;
      }
      rgb.add(expanded);
    }
    return buildFromRgbFrames(rgb, mediaType: mediaType);
  }

  static Map<String, dynamic> buildFromRgbFrames(
    List<Uint8List> frames, {
    required String mediaType,
  }) {
    if (mediaType != 'photo' && mediaType != 'video') {
      throw ArgumentError.value(mediaType, 'mediaType');
    }
    if (frames.isEmpty) {
      throw ArgumentError('At least one normalized RGB frame is required');
    }
    if (mediaType == 'photo' && frames.length != 1) {
      throw ArgumentError('Photo fingerprint requires exactly one frame');
    }

    final fingerprints = <Map<String, dynamic>>[];
    for (final frame in frames.take(maxVideoFrames)) {
      if (frame.length != _frameBytes) {
        throw ArgumentError(
          'Normalized RGB frame must contain exactly $_frameBytes bytes',
        );
      }
      fingerprints.add(_buildFrame(frame));
    }

    return <String, dynamic>{
      'type': type,
      'version': version,
      'algorithm': algorithm,
      'mediaType': mediaType,
      'width': width,
      'height': height,
      'gridColumns': gridColumns,
      'gridRows': gridRows,
      'featureBytesPerTile': _featureBytesPerTile,
      'samplingFps': mediaType == 'video' ? videoFps : 0,
      'maxFrames': mediaType == 'video' ? maxVideoFrames : 1,
      'frameCount': fingerprints.length,
      'frames': fingerprints,
    };
  }

  static bool isValid(Object? raw) {
    if (raw is! Map ||
        raw['type'] != type ||
        raw['version'] != version ||
        raw['algorithm'] != algorithm ||
        raw['width'] != width ||
        raw['height'] != height ||
        raw['gridColumns'] != gridColumns ||
        raw['gridRows'] != gridRows ||
        raw['featureBytesPerTile'] != _featureBytesPerTile) {
      return false;
    }

    final mediaType = raw['mediaType'];
    if (mediaType != 'photo' && mediaType != 'video') return false;

    final frames = raw['frames'];
    final frameCount = (raw['frameCount'] as num?)?.toInt();
    if (frames is! List ||
        frames.isEmpty ||
        frameCount != frames.length ||
        frames.length > maxVideoFrames) {
      return false;
    }
    if (mediaType == 'photo' && frames.length != 1) return false;

    final hashPattern = RegExp(r'^[a-f0-9]{16}$');
    final expectedFeatureLength =
        gridColumns * gridRows * _featureBytesPerTile;

    for (final entry in frames) {
      if (entry is! Map ||
          !hashPattern.hasMatch(entry['globalHash']?.toString() ?? '')) {
        return false;
      }
      try {
        if (base64Decode(entry['localFeatures']?.toString() ?? '').length !=
            expectedFeatureLength) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  static HCVReferenceVisualComparison compare(
    Map<dynamic, dynamic> expected,
    Map<dynamic, dynamic> current,
  ) {
    if (!isValid(expected) ||
        !isValid(current) ||
        expected['mediaType'] != current['mediaType']) {
      return const HCVReferenceVisualComparison(
        verdict: HCVReferenceVisualVerdict.inconclusive,
        alignedFrames: 0,
        modifiedFrames: 0,
        inconclusiveFrames: 0,
        expectedFrames: 0,
      );
    }

    final expectedFrames = expected['frames'] as List;
    final currentFrames = current['frames'] as List;

    if (expected['mediaType'] == 'photo') {
      final residual = _compareFrame(
        expectedFrames.single as Map,
        currentFrames.single as Map,
      );
      final verdict = residual.tampered
          ? HCVReferenceVisualVerdict.modified
          : residual.comparable
              ? HCVReferenceVisualVerdict.conforming
              : HCVReferenceVisualVerdict.inconclusive;
      return HCVReferenceVisualComparison(
        verdict: verdict,
        alignedFrames: residual.comparable ? 1 : 0,
        modifiedFrames: residual.tampered ? 1 : 0,
        inconclusiveFrames: residual.comparable ? 0 : 1,
        expectedFrames: 1,
      );
    }

    // VIDEO provenance is anchored to the beginning of the certified
    // recording. Social transcoding may change encoding, but a copy that
    // removes the opening segment must never become CONFORMING. For uncapped
    // videos, a material frame-count loss is an immediate modification.
    if (expectedFrames.length < maxVideoFrames &&
        currentFrames.length + _maxConformingFrameCountDelta <
            expectedFrames.length) {
      return HCVReferenceVisualComparison(
        verdict: HCVReferenceVisualVerdict.modified,
        alignedFrames: 0,
        modifiedFrames: 1,
        inconclusiveFrames: 0,
        expectedFrames: expectedFrames.length,
      );
    }

    final anchorCount = min(
      initialAnchorFrames,
      min(expectedFrames.length, currentFrames.length),
    );
    for (var i = 0; i < anchorCount; i++) {
      final direct = _compareFrame(
        expectedFrames[i] as Map,
        currentFrames[i] as Map,
      );
      if (direct.comparable) {
        if (direct.tampered) {
          return HCVReferenceVisualComparison(
            verdict: HCVReferenceVisualVerdict.modified,
            alignedFrames: i,
            modifiedFrames: 1,
            inconclusiveFrames: 0,
            expectedFrames: expectedFrames.length,
          );
        }
        continue;
      }

      // A certified opening frame found only later in the candidate is direct
      // evidence that the candidate timeline starts after the original.
      final searchHigh = min(
        currentFrames.length - 1,
        i + initialAnchorFrames,
      );
      var shiftedOpeningFound = false;
      for (var candidateIndex = i + 1;
          candidateIndex <= searchHigh;
          candidateIndex++) {
        final shifted = _compareFrame(
          expectedFrames[i] as Map,
          currentFrames[candidateIndex] as Map,
        );
        if (shifted.comparable && !shifted.tampered) {
          shiftedOpeningFound = true;
          break;
        }
      }
      if (shiftedOpeningFound) {
        return HCVReferenceVisualComparison(
          verdict: HCVReferenceVisualVerdict.modified,
          alignedFrames: i,
          modifiedFrames: 1,
          inconclusiveFrames: 0,
          expectedFrames: expectedFrames.length,
        );
      }

      return HCVReferenceVisualComparison(
        verdict: HCVReferenceVisualVerdict.inconclusive,
        alignedFrames: i,
        modifiedFrames: 0,
        inconclusiveFrames: 1,
        expectedFrames: expectedFrames.length,
      );
    }

    var aligned = 0;
    var modified = 0;
    var inconclusive = 0;
    final used = <int>{};
    var previousMatchedIndex = -1;

    for (var e = 0; e < expectedFrames.length; e++) {
      final expectedFrame = expectedFrames[e] as Map;
      final center = expectedFrames.length <= 1 || currentFrames.length <= 1
          ? 0
          : (e * (currentFrames.length - 1) / (expectedFrames.length - 1))
              .round();
      final low = max(previousMatchedIndex + 1, max(0, center - 4));
      final high = min(currentFrames.length - 1, center + 4);
      var bestIndex = -1;

      // Preserve the expected temporal position whenever it is still a
      // plausible and comparable frame. This prevents a local edit from being
      // "explained away" by jumping to a cleaner neighbouring frame.
      if (center >= low &&
          center <= high &&
          !used.contains(center)) {
        final centerCandidate = currentFrames[center] as Map;
        final centerHamming = _hexHamming(
          expectedFrame['globalHash'].toString(),
          centerCandidate['globalHash'].toString(),
        );
        if (centerHamming <= 18) {
          final centerResidual = _compareFrame(
            expectedFrame,
            centerCandidate,
          );
          if (centerResidual.comparable) {
            bestIndex = center;
          }
        }
      }

      // Only if the expected temporal position is not comparable do we permit
      // bounded drift recovery. Among plausible neighbours, structural local
      // features choose the best match while chronology remains monotonic.
      if (bestIndex < 0) {
        var bestHamming = 9999;
        var bestLocalDistance = double.infinity;
        var bestTemporalDistance = 9999;

        for (var i = low; i <= high; i++) {
          if (used.contains(i)) continue;
          final candidate = currentFrames[i] as Map;
          final hamming = _hexHamming(
            expectedFrame['globalHash'].toString(),
            candidate['globalHash'].toString(),
          );
          if (hamming > 18) continue;

          final localDistance = _alignmentLocalFeatureDistance(
            expectedFrame,
            candidate,
          );
          if (!localDistance.isFinite) continue;

          final temporalDistance = (i - center).abs();
          final better = localDistance < bestLocalDistance - 0.0001 ||
              ((localDistance - bestLocalDistance).abs() <= 0.0001 &&
                  (hamming < bestHamming ||
                      (hamming == bestHamming &&
                          temporalDistance < bestTemporalDistance)));
          if (better) {
            bestLocalDistance = localDistance;
            bestHamming = hamming;
            bestTemporalDistance = temporalDistance;
            bestIndex = i;
          }
        }
      }

      if (bestIndex < 0) {
        inconclusive++;
        continue;
      }

      used.add(bestIndex);
      previousMatchedIndex = bestIndex;
      final residual = _compareFrame(
        expectedFrame,
        currentFrames[bestIndex] as Map,
      );
      if (!residual.comparable) {
        inconclusive++;
        continue;
      }
      aligned++;
      if (residual.tampered) modified++;
    }

    final minimumAligned = max(2, (expectedFrames.length * 0.55).ceil());
    final verdict = modified > 0
        ? HCVReferenceVisualVerdict.modified
        : aligned >= minimumAligned &&
                inconclusive <= (expectedFrames.length * 0.35).ceil()
            ? HCVReferenceVisualVerdict.conforming
            : HCVReferenceVisualVerdict.inconclusive;

    return HCVReferenceVisualComparison(
      verdict: verdict,
      alignedFrames: aligned,
      modifiedFrames: modified,
      inconclusiveFrames: inconclusive,
      expectedFrames: expectedFrames.length,
    );
  }

  static Map<String, dynamic> _buildFrame(Uint8List frame) {
    final local = Uint8List(
      gridColumns * gridRows * _featureBytesPerTile,
    );
    var out = 0;

    for (var ty = 0; ty < gridRows; ty++) {
      for (var tx = 0; tx < gridColumns; tx++) {
        var sumLuma = 0;
        var sumRed = 0;
        var sumGreen = 0;
        var sumBlue = 0;
        var minimumLuma = 255;
        var maximumLuma = 0;
        var gradient = 0;
        var gradientCount = 0;

        final x0 = tx * _tileWidth;
        final y0 = ty * _tileHeight;

        for (var y = y0; y < y0 + _tileHeight; y++) {
          for (var x = x0; x < x0 + _tileWidth; x++) {
            final offset = (y * width + x) * _rgbChannels;
            final red = frame[offset];
            final green = frame[offset + 1];
            final blue = frame[offset + 2];
            final value = _luma(red, green, blue);

            sumLuma += value;
            sumRed += red;
            sumGreen += green;
            sumBlue += blue;
            minimumLuma = min(minimumLuma, value);
            maximumLuma = max(maximumLuma, value);

            if (x + 1 < x0 + _tileWidth) {
              final right = offset + _rgbChannels;
              gradient +=
                  (value - _luma(frame[right], frame[right + 1], frame[right + 2]))
                      .abs();
              gradientCount++;
            }
            if (y + 1 < y0 + _tileHeight) {
              final below = ((y + 1) * width + x) * _rgbChannels;
              gradient +=
                  (value - _luma(frame[below], frame[below + 1], frame[below + 2]))
                      .abs();
              gradientCount++;
            }
          }
        }

        final pixels = _tileWidth * _tileHeight;
        local[out++] = (sumLuma / pixels).round();
        local[out++] = maximumLuma - minimumLuma;
        local[out++] =
            gradientCount == 0 ? 0 : (gradient / gradientCount).round();
        local[out++] = (sumRed / pixels).round();
        local[out++] = (sumGreen / pixels).round();
        local[out++] = (sumBlue / pixels).round();
      }
    }

    final macroMeans = <int>[];
    for (var my = 0; my < 8; my++) {
      for (var mx = 0; mx < 8; mx++) {
        var sum = 0;
        for (var y = my * 9; y < (my + 1) * 9; y++) {
          for (var x = mx * 16; x < (mx + 1) * 16; x++) {
            final offset = (y * width + x) * _rgbChannels;
            sum += _luma(
              frame[offset],
              frame[offset + 1],
              frame[offset + 2],
            );
          }
        }
        macroMeans.add((sum / (16 * 9)).round());
      }
    }

    final globalMean =
        macroMeans.reduce((a, b) => a + b) / macroMeans.length;
    var bits = BigInt.zero;
    for (final value in macroMeans) {
      bits = (bits << 1) | (value >= globalMean ? BigInt.one : BigInt.zero);
    }

    return <String, dynamic>{
      'globalHash': bits.toRadixString(16).padLeft(16, '0'),
      'localFeatures': base64Encode(local),
    };
  }

  static double _alignmentLocalFeatureDistance(
    Map<dynamic, dynamic> expected,
    Map<dynamic, dynamic> current,
  ) {
    Uint8List left;
    Uint8List right;
    try {
      left = base64Decode(expected['localFeatures'].toString());
      right = base64Decode(current['localFeatures'].toString());
    } catch (_) {
      return double.infinity;
    }

    final expectedLength =
        gridColumns * gridRows * _featureBytesPerTile;
    if (left.length != right.length || left.length != expectedLength) {
      return double.infinity;
    }

    // Alignment uses the structural channels only: local luma mean, range
    // and edge energy. RGB channels remain fully active in _compareFrame for
    // colour/brightness tamper detection, but do not steer temporal matching.
    var total = 0.0;
    var samples = 0;
    for (var tile = 0; tile < gridColumns * gridRows; tile++) {
      final offset = tile * _featureBytesPerTile;
      for (var feature = 0; feature < 3; feature++) {
        total += (left[offset + feature] - right[offset + feature]).abs();
        samples++;
      }
    }
    return samples == 0 ? double.infinity : total / samples;
  }

  static _FrameResidual _compareFrame(
    Map<dynamic, dynamic> expected,
    Map<dynamic, dynamic> current,
  ) {
    final globalDistance = _hexHamming(
      expected['globalHash'].toString(),
      current['globalHash'].toString(),
    );
    if (globalDistance > 18) {
      return const _FrameResidual(comparable: false, tampered: false);
    }

    Uint8List a;
    Uint8List b;
    try {
      a = base64Decode(expected['localFeatures'].toString());
      b = base64Decode(current['localFeatures'].toString());
    } catch (_) {
      return const _FrameResidual(comparable: false, tampered: false);
    }

    if (a.length != b.length ||
        a.length != gridColumns * gridRows * _featureBytesPerTile) {
      return const _FrameResidual(comparable: false, tampered: false);
    }

    var totalMeanDifference = 0.0;
    var totalLumaDifference = 0.0;
    var maximumLumaDifference = 0.0;
    var totalChromaDifference = 0.0;
    var totalRgbDifference = 0.0;
    final moderate = <int>{};
    var severeCount = 0;
    final tileCount = gridColumns * gridRows;

    for (var tile = 0; tile < tileCount; tile++) {
      final offset = tile * _featureBytesPerTile;
      final expectedMean = a[offset];
      final expectedRange = a[offset + 1];
      final expectedEdge = a[offset + 2];
      final currentMean = b[offset];
      final currentRange = b[offset + 1];
      final currentEdge = b[offset + 2];

      final meanDifference = (expectedMean - currentMean).abs();
      final rangeDifference = (expectedRange - currentRange).abs();
      final edgeDifference = (expectedEdge - currentEdge).abs();
      totalMeanDifference += meanDifference;

      final expectedSmooth = expectedRange <= 42 && expectedEdge <= 16;
      final currentSmooth = currentRange <= 42 && currentEdge <= 16;
      final smoothToStructured = expectedSmooth &&
          (currentRange - expectedRange >= 30 ||
              currentEdge - expectedEdge >= 14);
      final structuredToSmooth = currentSmooth &&
          (expectedRange - currentRange >= 30 ||
              expectedEdge - currentEdge >= 14);
      final severe = meanDifference >= 24 ||
          smoothToStructured ||
          structuredToSmooth ||
          (rangeDifference >= 44 && edgeDifference >= 12);
      final isModerate = meanDifference >= 11 &&
          (rangeDifference >= 14 || edgeDifference >= 8);

      if (severe) severeCount++;
      if (isModerate) moderate.add(tile);

      final expectedRed = a[offset + 3].toDouble();
      final expectedGreen = a[offset + 4].toDouble();
      final expectedBlue = a[offset + 5].toDouble();
      final currentRed = b[offset + 3].toDouble();
      final currentGreen = b[offset + 4].toDouble();
      final currentBlue = b[offset + 5].toDouble();

      final expectedLuma =
          0.2126 * expectedRed + 0.7152 * expectedGreen + 0.0722 * expectedBlue;
      final currentLuma =
          0.2126 * currentRed + 0.7152 * currentGreen + 0.0722 * currentBlue;
      final lumaDifference = (expectedLuma - currentLuma).abs();
      totalLumaDifference += lumaDifference;
      maximumLumaDifference = max(maximumLumaDifference, lumaDifference);

      final expectedChroma =
          max(expectedRed, max(expectedGreen, expectedBlue)) -
              min(expectedRed, min(expectedGreen, expectedBlue));
      final currentChroma =
          max(currentRed, max(currentGreen, currentBlue)) -
              min(currentRed, min(currentGreen, currentBlue));
      totalChromaDifference += (expectedChroma - currentChroma).abs();

      totalRgbDifference += (expectedRed - currentRed).abs() +
          (expectedGreen - currentGreen).abs() +
          (expectedBlue - currentBlue).abs();
    }

    final meanResidual = totalMeanDifference / tileCount;
    final meanLumaDifference = totalLumaDifference / tileCount;
    final meanChromaDifference = totalChromaDifference / tileCount;
    final meanRgbDifference = totalRgbDifference / (tileCount * 3);

    final tonalOrColourTamper =
        meanLumaDifference > _maxMeanLumaDifference ||
            maximumLumaDifference > _maxSingleTileLumaDifference ||
            meanChromaDifference > _maxMeanChromaDifference ||
            meanRgbDifference > _maxMeanRgbDifference;

    if (meanResidual > 12.0 && !tonalOrColourTamper) {
      return const _FrameResidual(comparable: false, tampered: false);
    }

    final tampered = severeCount > 0 ||
        _hasAdjacentTiles(moderate) ||
        tonalOrColourTamper;
    return _FrameResidual(comparable: true, tampered: tampered);
  }

  static int _luma(int red, int green, int blue) {
    return (0.2126 * red + 0.7152 * green + 0.0722 * blue).round();
  }

  static bool _hasAdjacentTiles(Set<int> tiles) {
    if (tiles.length < 2) return false;
    for (final tile in tiles) {
      final x = tile % gridColumns;
      final y = tile ~/ gridColumns;
      for (final other in tiles) {
        if (other == tile) continue;
        final ox = other % gridColumns;
        final oy = other ~/ gridColumns;
        if ((x - ox).abs() <= 1 && (y - oy).abs() <= 1) return true;
      }
    }
    return false;
  }

  static int _hexHamming(String left, String right) {
    if (left.length != right.length) return 9999;
    var distance = 0;
    for (var i = 0; i < left.length; i++) {
      final a = int.tryParse(left[i], radix: 16);
      final b = int.tryParse(right[i], radix: 16);
      if (a == null || b == null) return 9999;
      var diff = a ^ b;
      while (diff != 0) {
        distance += diff & 1;
        diff >>= 1;
      }
    }
    return distance;
  }

  static Future<List<Uint8List>> _normalizedRgbFrames(
    String inputPath, {
    required bool video,
  }) async {
    final source = File(inputPath);
    if (!await source.exists()) {
      throw ArgumentError('Media not found: $inputPath');
    }

    final temp = await getTemporaryDirectory();
    final output = File(
      p.join(
        temp.path,
        'hcv_reference_visual_v3_${DateTime.now().microsecondsSinceEpoch}.raw',
      ),
    );

    final safeInput = _escapePath(inputPath);
    final safeOutput = _escapePath(output.path);
    final filter = video
        ? 'fps=$videoFps,scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black,format=rgb24'
        : 'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black,format=rgb24';
    final command = video
        ? "-y -i '$safeInput' -vf \"$filter\" -frames:v $maxVideoFrames -f rawvideo '$safeOutput'"
        : "-y -i '$safeInput' -vf \"$filter\" -frames:v 1 -f rawvideo '$safeOutput'";

    try {
      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();
      if (code == null || !ReturnCode.isSuccess(code)) {
        final logs = await session.getAllLogsAsString();
        throw StateError(
          'REFERENCE_VISUAL_V3_NORMALIZATION_FAILED: ${logs ?? ''}',
        );
      }

      final bytes = await output.readAsBytes();
      if (bytes.isEmpty || bytes.length % _frameBytes != 0) {
        throw StateError('REFERENCE_VISUAL_V3_RAW_SIZE_INVALID');
      }

      final frames = <Uint8List>[];
      final count = min(bytes.length ~/ _frameBytes, maxVideoFrames);
      for (var i = 0; i < count; i++) {
        frames.add(
          Uint8List.fromList(
            bytes.sublist(i * _frameBytes, (i + 1) * _frameBytes),
          ),
        );
      }
      return frames;
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

class _FrameResidual {
  const _FrameResidual({
    required this.comparable,
    required this.tampered,
  });

  final bool comparable;
  final bool tampered;
}
