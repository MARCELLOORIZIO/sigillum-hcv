import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/registry_verify_page.dart';

String _hex(String char) => List<String>.filled(64, char).join();

Map<String, dynamic> _photoFingerprint({
  String algorithm = 'SIGILLUM_SOCIAL_IMAGE_AHASH_V1',
  String? imageHash,
}) =>
    <String, dynamic>{
      'algorithm': algorithm,
      'imageHash': imageHash ?? _hex('a'),
      'combinedHash': _hex('b'),
    };

Map<String, dynamic> _videoFingerprint({
  String algorithm = 'SIGILLUM_SOCIAL_AHASH_V1',
  List<String>? frameHashes,
}) =>
    <String, dynamic>{
      'algorithm': algorithm,
      'frameCount': (frameHashes ?? <String>[_hex('a'), _hex('b')]).length,
      'frameHashes': frameHashes ?? <String>[_hex('a'), _hex('b')],
      'combinedHash': _hex('c'),
    };

void main() {
  group('BUILD112 social fingerprint fail-closed', () {
    test('modern photo without fingerprint is invalid for social verification', () {
      final claims = <String, dynamic>{'socialVerification': true};

      expect(
        resolveHCVSocialFingerprintAvailability(claims, mediaType: 'photo'),
        isFalse,
      );
      expect(
        resolveHCVSocialFingerprintClaimState(claims, mediaType: 'photo'),
        HCVSocialFingerprintClaimState.modernInvalid,
      );
    });

    test('modern video without fingerprint is invalid for social verification', () {
      final claims = <String, dynamic>{'socialVerification': true};

      expect(
        resolveHCVSocialFingerprintAvailability(claims, mediaType: 'video'),
        isFalse,
      );
    });

    test('modern photo rejects wrong algorithm or malformed perceptual hash', () {
      expect(
        resolveHCVSocialFingerprintAvailability(
          <String, dynamic>{
            'socialVerification': true,
            'socialFingerprint': _photoFingerprint(algorithm: 'WRONG'),
          },
          mediaType: 'photo',
        ),
        isFalse,
      );
      expect(
        resolveHCVSocialFingerprintAvailability(
          <String, dynamic>{
            'socialVerification': true,
            'socialFingerprint': _photoFingerprint(imageHash: 'abcd'),
          },
          mediaType: 'photo',
        ),
        isFalse,
      );
    });

    test('modern video rejects malformed frame fingerprint', () {
      final claims = <String, dynamic>{
        'socialVerification': true,
        'socialFingerprint': _videoFingerprint(
          frameHashes: <String>[_hex('a'), 'not-a-64-hex-hash'],
        ),
      };

      expect(
        resolveHCVSocialFingerprintAvailability(claims, mediaType: 'video'),
        isFalse,
      );
    });

    test('valid modern photo fingerprint remains usable', () {
      final claims = <String, dynamic>{
        'socialVerification': true,
        'socialFingerprint': _photoFingerprint(),
      };

      expect(
        resolveHCVSocialFingerprintAvailability(claims, mediaType: 'photo'),
        isTrue,
      );
    });

    test('valid modern video fingerprint remains usable', () {
      final claims = <String, dynamic>{
        'socialVerification': true,
        'socialFingerprint': _videoFingerprint(),
      };

      expect(
        resolveHCVSocialFingerprintAvailability(claims, mediaType: 'video'),
        isTrue,
      );
    });

    test('true legacy photo without socialVerification stays compatible', () {
      final claims = <String, dynamic>{};

      expect(
        resolveHCVSocialFingerprintAvailability(claims, mediaType: 'photo'),
        isNull,
      );
      expect(
        resolveHCVSocialFingerprintClaimState(claims, mediaType: 'photo'),
        HCVSocialFingerprintClaimState.legacyMissing,
      );
    });

    test('true legacy video without socialVerification stays compatible', () {
      final claims = <String, dynamic>{};

      expect(
        resolveHCVSocialFingerprintAvailability(claims, mediaType: 'video'),
        isNull,
      );
    });

    test('legacy certificate with a valid fingerprint can still use it', () {
      final claims = <String, dynamic>{
        'socialFingerprint': _photoFingerprint(),
      };

      expect(
        resolveHCVSocialFingerprintAvailability(claims, mediaType: 'photo'),
        isTrue,
      );
    });
  });
}
