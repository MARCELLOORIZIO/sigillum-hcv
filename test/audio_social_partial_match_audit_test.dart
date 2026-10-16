import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_audio_fingerprint.dart';
import 'package:sigillum_iphone/registry_verify_page.dart';

Map<String, dynamic> _fp(List<String> frameHashes) => {
  'type': HCVAudioFingerprint.type,
  'version': HCVAudioFingerprint.version,
  'algorithm': HCVAudioFingerprint.algorithm,
  'sampleRate': HCVAudioFingerprint.sampleRate,
  'windowMs': HCVAudioFingerprint.windowMs,
  'hopMs': HCVAudioFingerprint.hopMs,
  'featureBytes': HCVAudioFingerprint.featureBytes,
  'frameCount': frameHashes.length,
  'frameHashes': frameHashes,
};

void main() {
  final equal = List<String>.filled(29, '00' * 24);
  final different = 'ff' * 24;

  test('baseline identical audio fingerprint matches', () {
    expect(HCVAudioFingerprint.matches(_fp(equal), _fp(equal)), isTrue);
  });

  test('15 of 29 matching windows pass even when remaining 14 are replaced', () {
    final altered = [...equal.take(15), ...List<String>.filled(14, different)];
    expect(HCVAudioFingerprint.matches(_fp(equal), _fp(altered)), isTrue);
  });

  test('14 matching windows and 15 replaced windows do not pass', () {
    final altered = [...equal.take(14), ...List<String>.filled(15, different)];
    expect(HCVAudioFingerprint.matches(_fp(equal), _fp(altered)), isFalse);
  });

  test('legacy audio absence is unknown, never a confirmed match', () {
    expect(resolveHCVAudioFingerprintAvailability({
      'socialFingerprint': {'algorithm': 'SIGILLUM_SOCIAL_AHASH_V1'},
    }), isNull);
  });

  test('modern declared audio absence is invalid', () {
    expect(resolveHCVAudioFingerprintAvailability({
      'socialFingerprint': {'audioFingerprintPolicy': HCVAudioFingerprint.policy},
    }), isFalse);
  });

  test('verifier currently permits visually conforming legacy audio', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains('audioFingerprintMatches != false'));
    expect(source, contains("result = 'OFFICIAL COPY VERIFIED'"));
  });

  test('legacy extraction currently covers only the initial 15 seconds', () {
    final source = File('lib/hcv_audio_fingerprint.dart').readAsStringSync();
    expect(source, contains('_maxAnalyzedSeconds = 15.0'));
    expect(source, contains('-t $_maxAnalyzedSeconds'));
  });
}
