import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_software_attestation.dart';
import 'package:sigillum_iphone/hcv_verifier.dart';

const Map<String, dynamic> _publicKey = {
  'modulus': 'LOCAL_DEV_PUBLIC_KEY',
  'exponent': 'LOCAL_DEV',
};

const Object _absent = Object();

String _sha(String value) => sha256.convert(utf8.encode(value)).toString();
String _sign(String value) => _sha('LOCAL_DEV_SIGNATURE:$value');

Map<String, dynamic> _chainEvent(
  String type,
  String timestamp,
  String prev,
) {
  final event = <String, dynamic>{
    'type': type,
    'timestamp': timestamp,
    'prev': prev,
  };
  event['hash'] = _sha(jsonEncode(event));
  return event;
}

Map<String, dynamic> _buildCertificate({
  Object? softwareAttestation = _absent,
}) {
  final start = _chainEvent(
    'START',
    '2026-09-13T20:00:00.000Z',
    'GENESIS',
  );
  final stop = _chainEvent(
    'STOP',
    '2026-09-13T20:00:01.000Z',
    start['hash'] as String,
  );
  final chain = <Map<String, dynamic>>[start, stop];
  final rootHash = _sha(jsonEncode(chain));

  final deviceFingerprint = _sha(jsonEncode(_publicKey));
  const creatorId = 'creator-d1-test';
  const creatorName = 'D1 Test Creator';
  final identityFingerprint =
      _sha('$creatorId|$creatorName|$deviceFingerprint');

  final meta = <String, dynamic>{
    'hcvId': 'HCV-0123456789ABCDEF',
    'identity': <String, dynamic>{
      'creatorId': creatorId,
      'creatorName': creatorName,
      'devicePublicKeyFingerprint': deviceFingerprint,
      'identityFingerprint': identityFingerprint,
    },
  };
  if (!identical(softwareAttestation, _absent)) {
    meta['softwareAttestation'] = softwareAttestation;
  }

  final signedPayload = <String, dynamic>{
    'format': 'HCV_CERTIFICATE',
    'version': 2,
    'sessionId': 'session-d1-test',
    'createdAt': '2026-09-13T19:59:59.000Z',
    'meta': meta,
    'content': <String, dynamic>{
      'type': 'photo',
      'hash': _sha('d1-photo-bytes'),
      'size': 1234,
      'name': 'hcv_photo_HCV-0123456789ABCDEF.jpg',
    },
    'claims': <String, dynamic>{},
    'rootHash': rootHash,
    'chain': chain,
  };

  return <String, dynamic>{
    ...signedPayload,
    'signatureAlgorithm': 'RSA-SHA256-HCV-V2',
    'signature': _sign(jsonEncode(signedPayload)),
    'publicKey': _publicKey,
  };
}

Future<bool> _verifyCertificate(Map<String, dynamic> certificate) async {
  final dir = await Directory.systemTemp.createTemp('hcv_d1_verifier_');
  try {
    final file = File('${dir.path}/certificate.hcv');
    await file.writeAsString(jsonEncode(certificate));
    return HCVVerifier().verifyFile(file.path);
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  test('D1 verifier accepts valid BOUND software attestation', () async {
    final attestation = HCVSoftwareAttestation.fromValues(
      sourceCommit: '306c6c742bcd225d02b67675881ef9894a84a4aa',
      edition: 'user',
      appVersion: '1.0.0',
      buildNumber: '108',
    );

    expect(
      await _verifyCertificate(
        _buildCertificate(softwareAttestation: attestation),
      ),
      isTrue,
    );
  });

  test('D1 verifier accepts structurally valid UNBOUND attestation', () async {
    final attestation = HCVSoftwareAttestation.fromValues(
      sourceCommit: 'local-development-build',
      edition: 'dev',
      appVersion: '1.0.0',
      buildNumber: 'local',
    );

    expect(attestation['status'], 'UNBOUND');
    expect(
      await _verifyCertificate(
        _buildCertificate(softwareAttestation: attestation),
      ),
      isTrue,
    );
  });

  test('D1 verifier rejects malformed attestation even when certificate is signed',
      () async {
    final malformed = <String, dynamic>{
      'type': HCVSoftwareAttestation.schema,
      'version': HCVSoftwareAttestation.schemaVersion,
      'status': 'BOUND',
      'bindingMethod': HCVSoftwareAttestation.bindingMethod,
      'sourceCommit': 'not-a-git-commit',
      'sourceCommitAlgorithm': 'GIT_SHA1',
      'edition': 'user',
      'appVersion': '1.0.0',
      'buildNumber': '108',
    };

    expect(
      await _verifyCertificate(
        _buildCertificate(softwareAttestation: malformed),
      ),
      isFalse,
    );
  });

  test('D1 verifier rejects non-map attestation', () async {
    expect(
      await _verifyCertificate(
        _buildCertificate(softwareAttestation: 'BOUND'),
      ),
      isFalse,
    );
  });

  test('D1 verifier rejects explicit null attestation', () async {
    expect(
      await _verifyCertificate(
        _buildCertificate(softwareAttestation: null),
      ),
      isFalse,
    );
  });

  test('pre-D3 V2 certificate without software attestation remains compatible',
      () async {
    expect(await _verifyCertificate(_buildCertificate()), isTrue);
  });
}
