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
        '493f334a1c1ab61483db584cda762a2e9750cd8bb91df39c26226c73b84e7f08',
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
