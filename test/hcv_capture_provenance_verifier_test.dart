import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_provenance_chain.dart';
import 'package:sigillum_iphone/hcv_verifier.dart';

const Map<String, dynamic> _publicKey = {
  'modulus': 'LOCAL_DEV_PUBLIC_KEY',
  'exponent': 'LOCAL_DEV',
};

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

Map<String, dynamic> _buildCertificate({bool includeProvenance = true}) {
  const hcvId = 'HCV-0123456789ABCDEF';
  const sessionId = 'session-d2-test';
  const contentName = 'hcv_photo_HCV-0123456789ABCDEF.jpg';
  const captureCreatedAt = '2026-09-01T15:00:00.000Z';
  final contentHash = _sha('final-photo-bytes');

  final start = _chainEvent('START', '2026-09-01T14:59:58.000Z', 'GENESIS');
  final bound = _chainEvent(
    'CONTENT_BOUND',
    '2026-09-01T15:00:01.000Z',
    start['hash'] as String,
  );
  final stop = _chainEvent(
    'STOP',
    '2026-09-01T15:00:02.000Z',
    bound['hash'] as String,
  );
  final chain = <Map<String, dynamic>>[start, bound, stop];
  final rootHash = _sha(jsonEncode(chain));

  final deviceFingerprint = _sha(jsonEncode(_publicKey));
  const creatorId = 'creator-d2-test';
  const creatorName = 'D2 Test Creator';
  final identityFingerprint =
      _sha('$creatorId|$creatorName|$deviceFingerprint');

  final identity = <String, dynamic>{
    'creatorId': creatorId,
    'creatorName': creatorName,
    'devicePublicKeyFingerprint': deviceFingerprint,
    'identityFingerprint': identityFingerprint,
  };

  final content = <String, dynamic>{
    'type': 'photo',
    'hash': contentHash,
    'size': 4321,
    'name': contentName,
  };

  final claims = <String, dynamic>{
    'captureSource': 'HCV_CAMERA',
    'captureCreatedAt': captureCreatedAt,
  };

  if (includeProvenance) {
    final eventBody = <String, dynamic>{
      'type': HCVProvenanceChain.eventSchema,
      'version': HCVProvenanceChain.eventVersion,
      'sequence': 0,
      'eventType': 'CAPTURE_FINALIZED',
      'inputHash': contentHash,
      'timestamp': '2026-09-01T15:00:03.000Z',
      'deviceFingerprint': deviceFingerprint,
      'sessionId': sessionId,
      'pipelineVersion': 'HCV_CAPTURE_BINDING_V1',
      'nonce': 'd2-verifier-nonce',
      'parentEvent': 'GENESIS',
      'metadata': <String, dynamic>{
        'hcvId': hcvId,
        'mediaType': 'photo',
        'contentSize': 4321,
        'contentName': contentName,
        'capturedAt': captureCreatedAt,
        'captureSource': 'HCV_CAMERA',
      },
    };
    final eventHash =
        _sha(HCVProvenanceChain.canonicalJson(eventBody));
    final event = <String, dynamic>{
      ...eventBody,
      'eventHash': eventHash,
      'signatureAlgorithm': HCVProvenanceChain.signatureAlgorithm,
      'signature': _sign(eventHash),
      'publicKey': _publicKey,
    };

    claims['provenance'] = <String, dynamic>{
      'type': 'SIGILLUM_CAPTURE_PROVENANCE_BINDING',
      'version': 1,
      'status': 'VERIFIED',
      'hcvId': hcvId,
      'eventHash': eventHash,
      'inputHash': contentHash,
      'deviceFingerprint': deviceFingerprint,
      'sessionId': sessionId,
      'pipelineVersion': 'HCV_CAPTURE_BINDING_V1',
      'signatureAlgorithm': HCVProvenanceChain.signatureAlgorithm,
      'logFileName': 'hcv_provenance_$hcvId.jsonl',
      'event': event,
    };
  }

  final signedPayload = <String, dynamic>{
    'format': 'HCV_CERTIFICATE',
    'version': 2,
    'sessionId': sessionId,
    'createdAt': '2026-09-01T14:59:57.000Z',
    'meta': <String, dynamic>{
      'hcvId': hcvId,
      'identity': identity,
    },
    'content': content,
    'claims': claims,
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

void _resignCertificate(Map<String, dynamic> certificate) {
  final signedPayload = <String, dynamic>{
    'format': certificate['format'],
    'version': certificate['version'],
    'sessionId': certificate['sessionId'],
    'createdAt': certificate['createdAt'],
    'meta': certificate['meta'],
    'content': certificate['content'],
    'claims': certificate['claims'] ?? <String, dynamic>{},
    if (certificate.containsKey('liveSignals'))
      'liveSignals': certificate['liveSignals'],
    'rootHash': certificate['rootHash'],
    'chain': certificate['chain'],
  };
  certificate['signature'] = _sign(jsonEncode(signedPayload));
}

Future<bool> _verifyCertificate(Map<String, dynamic> certificate) async {
  final dir = await Directory.systemTemp.createTemp('hcv_d2_verifier_');
  try {
    final file = File('${dir.path}/certificate.hcv');
    await file.writeAsString(jsonEncode(certificate));
    return await HCVVerifier().verifyFile(file.path);
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  test('D2 verifier accepts a fully bound signed capture certificate', () async {
    expect(await _verifyCertificate(_buildCertificate()), isTrue);
  });

  test('D2 verifier rejects content hash changed under a re-signed certificate',
      () async {
    final certificate = _buildCertificate();
    final content = certificate['content'] as Map<String, dynamic>;
    content['hash'] = _sha('different-final-photo');
    _resignCertificate(certificate);

    expect(await _verifyCertificate(certificate), isFalse);
  });

  test('D2 verifier rejects provenance summary changed and re-signed', () async {
    final certificate = _buildCertificate();
    final claims = certificate['claims'] as Map<String, dynamic>;
    final provenance = claims['provenance'] as Map<String, dynamic>;
    provenance['sessionId'] = 'different-session';
    _resignCertificate(certificate);

    expect(await _verifyCertificate(certificate), isFalse);
  });

  test('D2 verifier rejects embedded event signature changed and re-signed',
      () async {
    final certificate = _buildCertificate();
    final claims = certificate['claims'] as Map<String, dynamic>;
    final provenance = claims['provenance'] as Map<String, dynamic>;
    final event = provenance['event'] as Map<String, dynamic>;
    event['signature'] = _sign('forged-event-hash');
    _resignCertificate(certificate);

    expect(await _verifyCertificate(certificate), isFalse);
  });

  test('pre-D2 V2 camera certificate without provenance remains compatible',
      () async {
    expect(
      await _verifyCertificate(_buildCertificate(includeProvenance: false)),
      isTrue,
    );
  });
}
