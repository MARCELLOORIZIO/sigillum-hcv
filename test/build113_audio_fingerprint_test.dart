import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_audio_fingerprint.dart';
import 'package:sigillum_iphone/registry_verify_page.dart';

List<int> _baseSignal({bool different = false}) {
  const sampleRate = HCVAudioFingerprint.sampleRate;
  final samples = <int>[];
  for (var i = 0; i < sampleRate * 4; i++) {
    final t = i / sampleRate;
    final envelope = 0.65 +
        0.20 * sin(2 * pi * 1.7 * t) +
        0.10 * sin(2 * pi * 0.37 * t);
    final value = different
        ? envelope *
            (0.75 * sin(2 * pi * 440 * t) +
                0.35 * sin(2 * pi * 1200 * t) +
                0.20 * sin(2 * pi * 2800 * t))
        : envelope *
            (0.75 * sin(2 * pi * 220 * t) +
                0.45 * sin(2 * pi * 730 * t) +
                0.25 * sin(2 * pi * 1450 * t));
    samples.add((value * 12000).round().clamp(-32768, 32767).toInt());
  }
  return samples;
}

List<int> _recompressedLike(List<int> source) {
  const shift = 160; // 20 ms encoder delay-like offset at 8 kHz.
  final result = List<int>.filled(source.length, 0);
  for (var i = shift; i < result.length; i++) {
    final deterministicNoise = ((i * 31) % 47) - 23;
    result[i] = ((source[i - shift] * 0.62).round() + deterministicNoise)
        .clamp(-32768, 32767);
  }
  return result;
}

void main() {
  group('BUILD113 audio fingerprint', () {
    test('gain, quantization noise and small encoder delay remain compatible', () {
      final original = HCVAudioFingerprint.buildFromPcm16Samples(_baseSignal());
      final derived = HCVAudioFingerprint.buildFromPcm16Samples(
        _recompressedLike(_baseSignal()),
      );

      expect(HCVAudioFingerprint.isValidFingerprint(original), isTrue);
      expect(HCVAudioFingerprint.isValidFingerprint(derived), isTrue);
      expect(HCVAudioFingerprint.matches(original, derived), isTrue);
    });

    test('substantially different audio does not match', () {
      final original = HCVAudioFingerprint.buildFromPcm16Samples(_baseSignal());
      final other = HCVAudioFingerprint.buildFromPcm16Samples(
        _baseSignal(different: true),
      );

      expect(HCVAudioFingerprint.matches(original, other), isFalse);
    });

    test('malformed audio fingerprint fails closed', () {
      final valid = HCVAudioFingerprint.buildFromPcm16Samples(_baseSignal());
      final malformed = Map<String, dynamic>.from(valid)
        ..['frameHashes'] = <String>['abcd'];

      expect(HCVAudioFingerprint.isValidFingerprint(malformed), isFalse);
    });

    test('new audio policy requires a valid signed audio fingerprint', () {
      final fingerprint = HCVAudioFingerprint.buildFromPcm16Samples(
        _baseSignal(),
      );
      final claims = <String, dynamic>{
        'socialFingerprint': <String, dynamic>{
          'audioFingerprintPolicy': HCVAudioFingerprint.policy,
          'audioFingerprint': fingerprint,
        },
      };

      expect(resolveHCVAudioFingerprintAvailability(claims), isTrue);
      expect(
        resolveHCVAudioFingerprintClaimState(claims),
        HCVAudioFingerprintClaimState.usable,
      );
    });

    test('declared modern audio policy with missing fingerprint fails closed', () {
      final claims = <String, dynamic>{
        'socialFingerprint': <String, dynamic>{
          'audioFingerprintPolicy': HCVAudioFingerprint.policy,
        },
      };

      expect(resolveHCVAudioFingerprintAvailability(claims), isFalse);
      expect(
        resolveHCVAudioFingerprintClaimState(claims),
        HCVAudioFingerprintClaimState.modernInvalid,
      );
    });

    test('pre-audio-fingerprint certificate remains legacy compatible', () {
      final claims = <String, dynamic>{
        'socialFingerprint': <String, dynamic>{
          'algorithm': 'SIGILLUM_SOCIAL_AHASH_V1',
          'frameHashes': <String>[],
        },
      };

      expect(resolveHCVAudioFingerprintAvailability(claims), isNull);
      expect(
        resolveHCVAudioFingerprintClaimState(claims),
        HCVAudioFingerprintClaimState.legacyMissing,
      );
    });

    test('video social fingerprint signs audio policy and verifier separates axes', () {
      final socialSource =
          File('lib/hcv_social_fingerprint.dart').readAsStringSync();
      final registrySource =
          File('lib/registry_verify_page.dart').readAsStringSync();
      final registryCopySource =
          File('lib/registry_verify_copy.dart').readAsStringSync();

      expect(
        socialSource,
        contains("'audioFingerprintPolicy': HCVAudioFingerprint.policy"),
      );
      expect(
        socialSource,
        contains('HCVAudioFingerprint.buildFromVideo(videoPath)'),
      );
      expect(socialSource, contains('buildVisualFromVideo'));
      expect(registrySource, contains('audioFingerprintMatches == false'));
      expect(registrySource, contains("_r('audioMismatchDetected')"));
      expect(registrySource, contains("_r('audioMismatchProvided')"));
      expect(
        registryCopySource,
        contains('fingerprint audio non corrisponde'),
      );
      expect(registrySource, contains('buildVisualFromVideo(mediaPath!)'));
    });
  });
}
