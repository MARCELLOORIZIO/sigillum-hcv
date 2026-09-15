import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:sigillum_iphone/hcv_software_attestation.dart';
import 'package:sigillum_iphone/hcv_verifier.dart';

String _sha(String value) => sha256.convert(utf8.encode(value)).toString();

Uint8List _bigIntBytes(BigInt value) {
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

BigInt _bytesBigInt(List<int> bytes) {
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return BigInt.parse(hex, radix: 16);
}

Map<String, dynamic> _chainEvent(String type, String timestamp, String prev) {
  final event = <String, dynamic>{
    'type': type,
    'timestamp': timestamp,
    'prev': prev,
  };
  event['hash'] = _sha(jsonEncode(event));
  return event;
}

class _AttackerKey {
  _AttackerKey(this.privateKey, this.publicKey);
  final RSAPrivateKey privateKey;
  final Map<String, dynamic> publicKey;
}

_AttackerKey _generateAttackerKey() {
  final random = FortunaRandom();
  random.seed(KeyParameter(Uint8List.fromList(List<int>.generate(32, (i) => i + 1))));
  final generator = RSAKeyGenerator()
    ..init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
      random,
    ));
  final pair = generator.generateKeyPair();
  final privateKey = pair.privateKey as RSAPrivateKey;
  final publicKey = pair.publicKey as RSAPublicKey;
  return _AttackerKey(
    privateKey,
    <String, dynamic>{
      'modulus': base64Encode(_bigIntBytes(publicKey.modulus!)),
      'exponent': base64Encode(_bigIntBytes(publicKey.exponent!)),
    },
  );
}

String _rsaSign(String value, RSAPrivateKey privateKey) {
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
    ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
  final signature = signer.generateSignature(Uint8List.fromList(utf8.encode(value))) as RSASignature;
  return base64Encode(signature.bytes);
}

Map<String, dynamic> _buildExactShape({
  required Map<String, dynamic> publicKey,
  required String Function(String payload) sign,
  Object? softwareAttestation = _absent,
}) {
  const hcvId = 'HCV-0123456789ABCDEF';
  const sessionId = 'session-d1-test';
  const contentName = 'hcv_photo_HCV-0123456789ABCDEF.jpg';
  const captureCreatedAt = '2026-09-13T20:00:00.000Z';
  final contentHash = _sha('final-photo-bytes');

  final start = _chainEvent('START', '2026-09-13T19:59:58.000Z', 'GENESIS');
  final bound = _chainEvent(
    'CONTENT_BOUND',
    '2026-09-13T20:00:01.000Z',
    start['hash'] as String,
  );
  final stop = _chainEvent(
    'STOP',
    '2026-09-13T20:00:02.000Z',
    bound['hash'] as String,
  );
  final chain = <Map<String, dynamic>>[start, bound, stop];
  final rootHash = _sha(jsonEncode(chain));

  final deviceFingerprint = _sha(jsonEncode(publicKey));
  const creatorId = 'creator-d1-test';
  const creatorName = 'D1 Test Creator';
  final identityFingerprint = _sha('$creatorId|$creatorName|$deviceFingerprint');

  final meta = <String, dynamic>{
    'hcvId': hcvId,
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
    'sessionId': sessionId,
    'createdAt': '2026-09-13T19:59:57.000Z',
    'meta': meta,
    'content': <String, dynamic>{
      'type': 'photo',
      'hash': contentHash,
      'size': 4321,
      'name': contentName,
    },
    'claims': <String, dynamic>{
      'captureSource': 'HCV_CAMERA',
      'captureCreatedAt': captureCreatedAt,
    },
    'rootHash': rootHash,
    'chain': chain,
  };

  return <String, dynamic>{
    ...signedPayload,
    'signatureAlgorithm': 'RSA-SHA256-HCV-V2',
    'signature': sign(jsonEncode(signedPayload)),
    'publicKey': publicKey,
  };
}

const Object _absent = Object();

Future<bool> _verify(Map<String, dynamic> cert) async {
  final dir = await Directory.systemTemp.createTemp('sigillum_redteam_');
  try {
    final file = File('${dir.path}/forged.hcv');
    await file.writeAsString(jsonEncode(cert));
    return HCVVerifier().verifyFile(file.path);
  } finally {
    await dir.delete(recursive: true);
  }
}

bool _directVerify(Map<String, dynamic> cert) {
  final pub = cert['publicKey'] as Map<String, dynamic>;
  final key = RSAPublicKey(
    _bytesBigInt(base64Decode(pub['modulus'] as String)),
    _bytesBigInt(base64Decode(pub['exponent'] as String)),
  );
  final signed = <String, dynamic>{
    'format': cert['format'],
    'version': cert['version'],
    'sessionId': cert['sessionId'],
    'createdAt': cert['createdAt'],
    'meta': cert['meta'],
    'content': cert['content'],
    'claims': cert['claims'] ?? <String, dynamic>{},
    if (cert.containsKey('liveSignals')) 'liveSignals': cert['liveSignals'],
    'rootHash': cert['rootHash'],
    'chain': cert['chain'],
  };
  final verifier = RSASigner(SHA256Digest(), '0609608648016503040201')
    ..init(false, PublicKeyParameter<RSAPublicKey>(key));
  return verifier.verifySignature(
    Uint8List.fromList(utf8.encode(jsonEncode(signed))),
    RSASignature(base64Decode(cert['signature'] as String)),
  );
}

void main() {
  const localDevPublicKey = <String, dynamic>{
    'modulus': 'LOCAL_DEV_PUBLIC_KEY',
    'exponent': 'LOCAL_DEV',
  };

  test('control: exact official-test shape passes LOCAL_DEV without attestation/provenance', () async {
    final cert = _buildExactShape(
      publicKey: localDevPublicKey,
      sign: (payload) => _sha('LOCAL_DEV_SIGNATURE:$payload'),
    );
    expect(await _verify(cert), isTrue);
  });

  test('control: exact official-test shape passes LOCAL_DEV with syntactically BOUND attestation', () async {
    final cert = _buildExactShape(
      publicKey: localDevPublicKey,
      sign: (payload) => _sha('LOCAL_DEV_SIGNATURE:$payload'),
      softwareAttestation: HCVSoftwareAttestation.fromValues(
        sourceCommit: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        edition: 'user',
        appVersion: '1.0.0',
        buildNumber: '111',
      ),
    );
    expect(await _verify(cert), isTrue);
  });

  test('same exact shape with attacker RSA has a valid embedded-key signature', () {
    final attacker = _generateAttackerKey();
    final cert = _buildExactShape(
      publicKey: attacker.publicKey,
      sign: (payload) => _rsaSign(payload, attacker.privateKey),
    );
    expect(_directVerify(cert), isTrue);
  });

  test('same exact shape with attacker RSA is evaluated by HCVVerifier', () async {
    final attacker = _generateAttackerKey();
    final cert = _buildExactShape(
      publicKey: attacker.publicKey,
      sign: (payload) => _rsaSign(payload, attacker.privateKey),
    );
    final accepted = await _verify(cert);
    // Red-team observation: this assertion records the current behavior.
    expect(accepted, isTrue);
  });
}
