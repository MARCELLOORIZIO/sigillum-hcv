import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_reference_visual_fingerprint_v3.dart';

Uint8List _baseFrame({int seed = 0}) {
  final frame = Uint8List(
    HCVReferenceVisualFingerprintV3.width *
        HCVReferenceVisualFingerprintV3.height,
  );
  for (var y = 0; y < HCVReferenceVisualFingerprintV3.height; y++) {
    for (var x = 0; x < HCVReferenceVisualFingerprintV3.width; x++) {
      final index = y * HCVReferenceVisualFingerprintV3.width + x;
      frame[index] = (168 + (x ~/ 24) + (y ~/ 18) + seed).clamp(0, 255);
    }
  }
  return frame;
}

Uint8List _recompressedLike(Uint8List source) {
  final result = Uint8List(source.length);
  for (var i = 0; i < source.length; i++) {
    final noise = ((i * 29 + 7) % 5) - 2;
    result[i] = (source[i] + noise).clamp(0, 255);
  }
  return result;
}

Uint8List _addSmallUfo(Uint8List source) {
  final result = Uint8List.fromList(source);
  for (var y = 27; y < 30; y++) {
    for (var x = 60; x < 68; x++) {
      result[y * HCVReferenceVisualFingerprintV3.width + x] = 45;
    }
  }
  return result;
}

Uint8List _baseRgbFrame() {
  final frame = Uint8List(
    HCVReferenceVisualFingerprintV3.width *
        HCVReferenceVisualFingerprintV3.height *
        3,
  );
  for (var y = 0; y < HCVReferenceVisualFingerprintV3.height; y++) {
    for (var x = 0; x < HCVReferenceVisualFingerprintV3.width; x++) {
      final offset = (y * HCVReferenceVisualFingerprintV3.width + x) * 3;
      var red = 68;
      var green = 136;
      var blue = 204;
      if (x >= 12 && x < 36 && y >= 12 && y < 30) {
        red = 220;
        green = 35;
        blue = 35;
      } else if (x >= 86 && x < 108 && y >= 48 && y < 62) {
        red = 35;
        green = 170;
        blue = 60;
      }
      frame[offset] = red;
      frame[offset + 1] = green;
      frame[offset + 2] = blue;
    }
  }
  return frame;
}

Uint8List _rgbRecompressedLike(Uint8List source) {
  final result = Uint8List(source.length);
  for (var i = 0; i < source.length; i++) {
    final noise = ((i * 31 + 11) % 3) - 1;
    result[i] = (source[i] + noise).clamp(0, 255);
  }
  return result;
}

Uint8List _rgbHueShift(Uint8List source) {
  final result = Uint8List(source.length);
  for (var i = 0; i < source.length; i += 3) {
    result[i] = source[i + 1];
    result[i + 1] = source[i + 2];
    result[i + 2] = source[i];
  }
  return result;
}

Uint8List _rgbBrighten(Uint8List source) {
  final result = Uint8List(source.length);
  for (var i = 0; i < source.length; i++) {
    result[i] = (source[i] + 24).clamp(0, 255);
  }
  return result;
}

Uint8List _rgbTranslate(Uint8List source) {
  final width = HCVReferenceVisualFingerprintV3.width;
  final height = HCVReferenceVisualFingerprintV3.height;
  final result = Uint8List(source.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final sourceX = (x + 3).clamp(0, width - 1);
      final sourceY = (y + 2).clamp(0, height - 1);
      final sourceOffset = (sourceY * width + sourceX) * 3;
      final targetOffset = (y * width + x) * 3;
      result[targetOffset] = source[sourceOffset];
      result[targetOffset + 1] = source[sourceOffset + 1];
      result[targetOffset + 2] = source[sourceOffset + 2];
    }
  }
  return result;
}

void main() {
  group('reference visual fingerprint V3 local tamper detection', () {
    test('Dart fingerprint matches the backend golden representation', () {
      final fingerprint = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        <Uint8List>[_baseFrame()],
        mediaType: 'photo',
      );
      final frame = (fingerprint['frames'] as List).single as Map;

      expect(frame['globalHash'], '03030f0f1f1f7f7f');
      expect(
        sha256
            .convert(base64Decode(frame['localFeatures'].toString()))
            .toString(),
        'f5df80936c5d9050b35e5a606c92b55a7eb2bec873f5805f9c81d37f14a4afbc',
      );
    });

    test('social-like recompression remains conforming', () {
      final expected = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        <Uint8List>[_baseFrame()],
        mediaType: 'photo',
      );
      final social = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        <Uint8List>[_recompressedLike(_baseFrame())],
        mediaType: 'photo',
      );

      final comparison =
          HCVReferenceVisualFingerprintV3.compare(expected, social);

      expect(
        comparison.verdict,
        HCVReferenceVisualVerdict.conforming,
      );
      expect(comparison.modifiedFrames, 0);
    });

    test('small inserted UFO is detected as a local modification', () {
      final expected = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        <Uint8List>[_baseFrame()],
        mediaType: 'photo',
      );
      final socialModified =
          HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        <Uint8List>[
          _addSmallUfo(_recompressedLike(_baseFrame())),
        ],
        mediaType: 'photo',
      );

      final comparison =
          HCVReferenceVisualFingerprintV3.compare(expected, socialModified);

      expect(
        comparison.verdict,
        HCVReferenceVisualVerdict.modified,
      );
      expect(comparison.modifiedFrames, 1);
    });

    test('video detects a small UFO present only in a subset of frames', () {
      final expectedFrames = List<Uint8List>.generate(
        8,
        (index) => _baseFrame(seed: index % 2),
      );
      final currentFrames = <Uint8List>[
        for (var i = 0; i < 8; i++)
          i == 3 || i == 4
              ? _addSmallUfo(_recompressedLike(expectedFrames[i]))
              : _recompressedLike(expectedFrames[i]),
      ];

      final expected = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        expectedFrames,
        mediaType: 'video',
      );
      final social = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        currentFrames,
        mediaType: 'video',
      );

      final comparison =
          HCVReferenceVisualFingerprintV3.compare(expected, social);

      expect(
        comparison.verdict,
        HCVReferenceVisualVerdict.modified,
      );
      expect(comparison.modifiedFrames, greaterThanOrEqualTo(1));
    });

    test(
      'video alignment prefers the expected-time comparable frame over a misleading hash neighbour',
      () {
        Map<String, dynamic> frame(int featureValue, String hash) => {
              'globalHash': hash,
              'localFeatures': base64Encode(
                Uint8List(16 * 9 * 6)..fillRange(0, 16 * 9 * 6, featureValue),
              ),
            };

        Map<String, dynamic> fingerprint(List<Map<String, dynamic>> frames) => {
              'type': HCVReferenceVisualFingerprintV3.type,
              'version': HCVReferenceVisualFingerprintV3.version,
              'algorithm': HCVReferenceVisualFingerprintV3.algorithm,
              'mediaType': 'video',
              'width': HCVReferenceVisualFingerprintV3.width,
              'height': HCVReferenceVisualFingerprintV3.height,
              'gridColumns': HCVReferenceVisualFingerprintV3.gridColumns,
              'gridRows': HCVReferenceVisualFingerprintV3.gridRows,
              'featureBytesPerTile': 6,
              'samplingFps': HCVReferenceVisualFingerprintV3.videoFps,
              'maxFrames': HCVReferenceVisualFingerprintV3.maxVideoFrames,
              'frameCount': frames.length,
              'frames': frames,
            };

        final expected = fingerprint([
          frame(20, 'ffffffffffffffff'),
          frame(80, '0000000000000000'),
          frame(140, '0000000000000000'),
        ]);
        final current = fingerprint([
          frame(20, 'ffffffffffffffff'),
          // Same local frame as expected[1], but one global-hash bit differs.
          frame(80, '0000000000000001'),
          // A different temporal frame has the deceptively better global hash.
          frame(140, '0000000000000000'),
        ]);

        final comparison =
            HCVReferenceVisualFingerprintV3.compare(expected, current);

        expect(comparison.verdict, HCVReferenceVisualVerdict.conforming);
        expect(comparison.alignedFrames, 3);
        expect(comparison.modifiedFrames, 0);
        expect(comparison.inconclusiveFrames, 0);
      },
    );

    test('video with a trimmed opening is never conforming', () {
      Map<String, dynamic> frame(String hash, int value) => {
            'globalHash': hash,
            'localFeatures': base64Encode(
              Uint8List(16 * 9 * 6)..fillRange(0, 16 * 9 * 6, value),
            ),
          };

      Map<String, dynamic> fingerprint(List<Map<String, dynamic>> frames) => {
            'type': HCVReferenceVisualFingerprintV3.type,
            'version': HCVReferenceVisualFingerprintV3.version,
            'algorithm': HCVReferenceVisualFingerprintV3.algorithm,
            'mediaType': 'video',
            'width': HCVReferenceVisualFingerprintV3.width,
            'height': HCVReferenceVisualFingerprintV3.height,
            'gridColumns': HCVReferenceVisualFingerprintV3.gridColumns,
            'gridRows': HCVReferenceVisualFingerprintV3.gridRows,
            'featureBytesPerTile': 6,
            'samplingFps': HCVReferenceVisualFingerprintV3.videoFps,
            'maxFrames': HCVReferenceVisualFingerprintV3.maxVideoFrames,
            'frameCount': frames.length,
            'frames': frames,
          };

      final expected = fingerprint(<Map<String, dynamic>>[
        frame('0000000000000000', 10),
        frame('1111111111111111', 25),
        frame('2222222222222222', 40),
        frame('3333333333333333', 55),
        frame('4444444444444444', 70),
        frame('5555555555555555', 85),
        frame('6666666666666666', 100),
        frame('7777777777777777', 115),
      ]);
      final trimmed = fingerprint(<Map<String, dynamic>>[
        frame('2222222222222222', 40),
        frame('3333333333333333', 55),
        frame('4444444444444444', 70),
        frame('5555555555555555', 85),
        frame('6666666666666666', 100),
        frame('7777777777777777', 115),
      ]);

      final comparison =
          HCVReferenceVisualFingerprintV3.compare(expected, trimmed);

      expect(comparison.verdict, HCVReferenceVisualVerdict.modified);
    });

    test('sub-second opening drift remains eligible for comparison', () {
      final expectedFrames = List<Uint8List>.generate(
        8,
        (index) => _baseFrame(seed: index),
      );
      final candidateFrames = <Uint8List>[
        _recompressedLike(expectedFrames.first),
        for (final frame in expectedFrames.skip(1)) _recompressedLike(frame),
      ];

      final expected = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        expectedFrames,
        mediaType: 'video',
      );
      final candidate = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        candidateFrames,
        mediaType: 'video',
      );

      expect(
        HCVReferenceVisualFingerprintV3.compare(expected, candidate).verdict,
        HCVReferenceVisualVerdict.conforming,
      );
    });

    test('RGB social-like recompression remains conforming', () {
      final expected = HCVReferenceVisualFingerprintV3.buildFromRgbFrames(
        <Uint8List>[_baseRgbFrame()],
        mediaType: 'photo',
      );
      final social = HCVReferenceVisualFingerprintV3.buildFromRgbFrames(
        <Uint8List>[_rgbRecompressedLike(_baseRgbFrame())],
        mediaType: 'photo',
      );

      expect(
        HCVReferenceVisualFingerprintV3.compare(expected, social).verdict,
        HCVReferenceVisualVerdict.conforming,
      );
    });

    test('colour-only edit is detected as modified', () {
      final expected = HCVReferenceVisualFingerprintV3.buildFromRgbFrames(
        <Uint8List>[_baseRgbFrame()],
        mediaType: 'photo',
      );
      final edited = HCVReferenceVisualFingerprintV3.buildFromRgbFrames(
        <Uint8List>[_rgbHueShift(_rgbRecompressedLike(_baseRgbFrame()))],
        mediaType: 'photo',
      );

      expect(
        HCVReferenceVisualFingerprintV3.compare(expected, edited).verdict,
        HCVReferenceVisualVerdict.modified,
      );
    });

    test('brightness edit is detected as modified', () {
      final expected = HCVReferenceVisualFingerprintV3.buildFromRgbFrames(
        <Uint8List>[_baseRgbFrame()],
        mediaType: 'photo',
      );
      final edited = HCVReferenceVisualFingerprintV3.buildFromRgbFrames(
        <Uint8List>[_rgbBrighten(_rgbRecompressedLike(_baseRgbFrame()))],
        mediaType: 'photo',
      );

      expect(
        HCVReferenceVisualFingerprintV3.compare(expected, edited).verdict,
        HCVReferenceVisualVerdict.modified,
      );
    });

    test('small geometric translation is detected as modified', () {
      final expected = HCVReferenceVisualFingerprintV3.buildFromRgbFrames(
        <Uint8List>[_baseRgbFrame()],
        mediaType: 'photo',
      );
      final edited = HCVReferenceVisualFingerprintV3.buildFromRgbFrames(
        <Uint8List>[_rgbTranslate(_rgbRecompressedLike(_baseRgbFrame()))],
        mediaType: 'photo',
      );

      expect(
        HCVReferenceVisualFingerprintV3.compare(expected, edited).verdict,
        HCVReferenceVisualVerdict.modified,
      );
    });

    test('malformed fingerprint is inconclusive, never conforming', () {
      final expected = HCVReferenceVisualFingerprintV3.buildFromGrayFrames(
        <Uint8List>[_baseFrame()],
        mediaType: 'photo',
      );
      final malformed = <String, dynamic>{...expected, 'frames': <Object>[]};

      final comparison =
          HCVReferenceVisualFingerprintV3.compare(expected, malformed);

      expect(
        comparison.verdict,
        HCVReferenceVisualVerdict.inconclusive,
      );
    });
  });
}
