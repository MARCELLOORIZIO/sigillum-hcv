from pathlib import Path

source_path = Path('lib/registry_verify_page.dart')
source = source_path.read_text(encoding='utf-8')

helper_marker = 'HCVSocialFingerprintClaimState'
if helper_marker not in source:
    anchor = """  return HCVDisplayRiskClaimValues(
    risk: claims['screenReplayRisk']?.toString(),
    score: claims['screenReplayRiskScore']?.toString(),
    decision: claims['displayRiskDecision']?.toString(),
    requiresLegacyNormalization: true,
  );
}

class RegistryVerifyPage extends StatefulWidget {
"""
    replacement = """  return HCVDisplayRiskClaimValues(
    risk: claims['screenReplayRisk']?.toString(),
    score: claims['screenReplayRiskScore']?.toString(),
    decision: claims['displayRiskDecision']?.toString(),
    requiresLegacyNormalization: true,
  );
}

enum HCVSocialFingerprintClaimState {
  usable,
  legacyMissing,
  modernInvalid,
}

HCVSocialFingerprintClaimState resolveHCVSocialFingerprintClaimState(
  Map<dynamic, dynamic> claims, {
  required String mediaType,
}) {
  final requiresModernFingerprint = claims['socialVerification'] == true;
  final rawFingerprint = claims['socialFingerprint'];
  if (rawFingerprint is! Map) {
    return requiresModernFingerprint
        ? HCVSocialFingerprintClaimState.modernInvalid
        : HCVSocialFingerprintClaimState.legacyMissing;
  }

  final algorithm = rawFingerprint['algorithm']?.toString() ?? '';
  final shaLikeFingerprint = RegExp(r'^[a-fA-F0-9]{64}$');

  bool valid = false;
  if (mediaType == 'photo') {
    final imageHash = rawFingerprint['imageHash']?.toString() ?? '';
    valid = algorithm == 'SIGILLUM_SOCIAL_IMAGE_AHASH_V1' &&
        shaLikeFingerprint.hasMatch(imageHash);
  } else if (mediaType == 'video') {
    final frameHashes = rawFingerprint['frameHashes'];
    valid = algorithm == 'SIGILLUM_SOCIAL_AHASH_V1' &&
        frameHashes is List &&
        frameHashes.isNotEmpty &&
        frameHashes.every(
          (value) => shaLikeFingerprint.hasMatch(value.toString()),
        );
  }

  if (valid) return HCVSocialFingerprintClaimState.usable;
  return requiresModernFingerprint
      ? HCVSocialFingerprintClaimState.modernInvalid
      : HCVSocialFingerprintClaimState.legacyMissing;
}

bool? resolveHCVSocialFingerprintAvailability(
  Map<dynamic, dynamic> claims, {
  required String mediaType,
}) {
  switch (resolveHCVSocialFingerprintClaimState(
    claims,
    mediaType: mediaType,
  )) {
    case HCVSocialFingerprintClaimState.usable:
      return true;
    case HCVSocialFingerprintClaimState.legacyMissing:
      return null;
    case HCVSocialFingerprintClaimState.modernInvalid:
      return false;
  }
}

class RegistryVerifyPage extends StatefulWidget {
"""
    if anchor not in source:
        raise RuntimeError('social fingerprint helper anchor not found')
    source = source.replace(anchor, replacement, 1)

video_old = """    final stored = claims['socialFingerprint'];
    if (stored is! Map) {
      return null;
    }

    final storedHashes = stored['frameHashes'];
    if (storedHashes is! List || storedHashes.isEmpty) {
      return null;
    }

    try {
"""
video_new = """    final fingerprintAvailable = resolveHCVSocialFingerprintAvailability(
      claims,
      mediaType: 'video',
    );
    if (fingerprintAvailable != true) return fingerprintAvailable;

    final stored = claims['socialFingerprint'] as Map;
    final storedHashes = stored['frameHashes'] as List;

    try {
"""
if video_old in source:
    source = source.replace(video_old, video_new, 1)
elif "mediaType: 'video'" not in source:
    raise RuntimeError('video social fingerprint anchor not found')

image_old = """    final stored = claims['socialFingerprint'];
    if (stored is! Map) {
      return null;
    }

    final expected = stored['imageHash']?.toString();
    if (expected == null || expected.isEmpty) {
      return null;
    }

    try {
"""
image_new = """    final fingerprintAvailable = resolveHCVSocialFingerprintAvailability(
      claims,
      mediaType: 'photo',
    );
    if (fingerprintAvailable != true) return fingerprintAvailable;

    final stored = claims['socialFingerprint'] as Map;
    final expected = stored['imageHash']!.toString();

    try {
"""
if image_old in source:
    source = source.replace(image_old, image_new, 1)
elif "mediaType: 'photo'" not in source:
    raise RuntimeError('photo social fingerprint anchor not found')

required = [
    'enum HCVSocialFingerprintClaimState',
    'resolveHCVSocialFingerprintAvailability(',
    "mediaType: 'video'",
    "mediaType: 'photo'",
    'HCVSocialFingerprintClaimState.modernInvalid',
    'HCVSocialFingerprintClaimState.legacyMissing',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'missing fail-closed token: {token}')

source_path.write_text(source, encoding='utf-8')


test_path = Path('test/build112_social_fingerprint_failclosed_test.dart')
test_path.write_text(r'''import 'package:flutter_test/flutter_test.dart';
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
''', encoding='utf-8')

print('BUILD112 social fingerprint fail-closed patch materialized')
