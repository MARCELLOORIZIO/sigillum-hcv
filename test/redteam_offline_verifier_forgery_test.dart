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

String _sign(String value, RSAPrivateKey privateKey) {
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
    ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
  final signature = signer.generateSignature(Uint8List.fromList(utf8.encode(value))) as RSASignature;
  return base64Encode(signature.bytes);
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

Map<String, dynamic> _baseSigned({
  required Map<String, dynamic> publicKey,
  required bool includeBoundAttestation,
}) {
  final start = _chainEvent('START', '2026-09-15T12:00:00.000Z', 'GENESIS');
  final stop = _chainEvent('STOP', '2026-09-15T12:00:01.000Z', start['hash'] as String);
  final chain = <Map<String, dynamic>>[start, stop];
  final fingerprint = _sha(jsonEncode(publicKey));
  const creatorId = 'attacker-created-id';
  const creatorName = 'Forged Creator';
  final meta = <String, dynamic>{
    'hcvId': 'HCV-DEADBEEFDEADBEEF',
    'identity': <String, dynamic>{
      'creatorId': creatorId,
      'creatorName': creatorName,
      'devicePublicKeyFingerprint': fingerprint,
      'identityFingerprint': _sha('$creatorId|$creatorName|$fingerprint'),
    },
  };
  if (includeBoundAttestation) {
    meta['softwareAttestation'] = HCVSoftwareAttestation.fromValues(
      sourceCommit: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      edition: 'user',
      appVersion: '1.0.0',
      buildNumber: '111',
    );
  }
  return <String, dynamic>{
    'format': 'HCV_CERTIFICATE',
    'version': 2,
    'sessionId': 'attacker-session',
    'createdAt': '2026-09-15T11:59:59.000Z',
    'meta': meta,
    'content': <String, dynamic>{
      'type': 'photo',
      'hash': _sha('attacker-media-bytes'),
      'size': 1234,
      'name': 'hcv_photo_HCV-DEADBEEFDEADBEEF.jpg',
    },
    'claims': <String, dynamic>{
      'captureSource': 'HCV_CAMERA',
      'captureCreatedAt': '2026-09-15T12:00:00.500Z',
    },
    'rootHash': _sha(jsonEncode(chain)),
    'chain': chain,
  };
}

Map<String, dynamic> _forgeRsa({required bool includeBoundAttestation}) {
  final attacker = _generateAttackerKey();
  final signed = _baseSigned(
    publicKey: attacker.publicKey,
    includeBoundAttestation: includeBoundAttestation,
  );
  return <String, dynamic>{
    ...signed,
    'signatureAlgorithm': 'RSA-SHA256-HCV-V2',
    'signature': _sign(jsonEncode(signed), attacker.privateKey),
    'publicKey': attacker.publicKey,
  };
}

Map<String, dynamic> _forgeLocalDev() {
  const publicKey = <String, dynamic>{
    'modulus': 'LOCAL_DEV_PUBLIC_KEY',
    'exponent': 'LOCAL_DEV',
  };
  final signed = _baseSigned(publicKey: publicKey, includeBoundAttestation: false);
  return <String, dynamic>{
    ...signed,
    'signatureAlgorithm': 'RSA-SHA256-HCV-V2',
    'signature': _sha('LOCAL_DEV_SIGNATURE:${jsonEncode(signed)}'),
    'publicKey': publicKey,
  };
}

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

void main() {
  test('attacker RSA signature is cryptographically valid under embedded public key', () {
    final cert = _forgeRsa(includeBoundAttestation: false);
    expect(_directVerify(cert), isTrue);
  });

  test('offline verifier rejects attacker-generated RSA certificate', () async {
    expect(await _verify(_forgeRsa(includeBoundAttestation: false)), isFalse);
  });

  test('offline verifier rejects attacker RSA even with syntactically BOUND fake attestation', () async {
    expect(await _verify(_forgeRsa(includeBoundAttestation: true)), isFalse);
  });

  test('same internally coherent certificate shape is accepted through LOCAL_DEV shortcut', () async {
    expect(await _verify(_forgeLocalDev()), isTrue);
  });
}
