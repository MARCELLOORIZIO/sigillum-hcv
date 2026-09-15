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

Map<String, dynamic> _forgeCertificate({required bool includeBoundAttestation}) {
  final attacker = _generateAttackerKey();
  final start = _chainEvent('START', '2026-09-15T12:00:00.000Z', 'GENESIS');
  final stop = _chainEvent('STOP', '2026-09-15T12:00:01.000Z', start['hash'] as String);
  final chain = <Map<String, dynamic>>[start, stop];
  final rootHash = _sha(jsonEncode(chain));
  final fingerprint = _sha(jsonEncode(attacker.publicKey));
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

  final signed = <String, dynamic>{
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
    'rootHash': rootHash,
    'chain': chain,
  };

  return <String, dynamic>{
    ...signed,
    'signatureAlgorithm': 'RSA-SHA256-HCV-V2',
    'signature': _sign(jsonEncode(signed), attacker.privateKey),
    'publicKey': attacker.publicKey,
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
  test('offline verifier accepts attacker-generated RSA key with no attestation/provenance', () async {
    expect(await _verify(_forgeCertificate(includeBoundAttestation: false)), isTrue);
  });

  test('offline verifier accepts attacker-generated RSA key with syntactically BOUND fake build attestation', () async {
    expect(await _verify(_forgeCertificate(includeBoundAttestation: true)), isTrue);
  });
}
