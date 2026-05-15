import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class HCVSignatureResult {
  final String signatureBase64;
  final String publicKeyBase64;

  HCVSignatureResult({
    required this.signatureBase64,
    required this.publicKeyBase64,
  });
}

class HCVCrypto {
  static final _algorithm = Ed25519();

  Future<SimpleKeyPair> generateKeyPair() async {
    return await _algorithm.newKeyPair();
  }

  Future<HCVSignatureResult> signData({
    required String jsonData,
  }) async {
    final keyPair = await generateKeyPair();

    final dataBytes = utf8.encode(jsonData);

    final signature = await _algorithm.sign(
      dataBytes,
      keyPair: keyPair,
    );

    final publicKey = await keyPair.extractPublicKey();

    return HCVSignatureResult(
      signatureBase64: base64Encode(signature.bytes),
      publicKeyBase64: base64Encode(publicKey.bytes),
    );
  }

  Future<bool> verifyData({
    required String jsonData,
    required String signatureBase64,
    required String publicKeyBase64,
  }) async {
    try {
      final dataBytes = utf8.encode(jsonData);

      final signatureBytes = base64Decode(signatureBase64);

      final publicKeyBytes = base64Decode(publicKeyBase64);

      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );

      final signature = Signature(
        signatureBytes,
        publicKey: publicKey,
      );

      return await _algorithm.verify(
        dataBytes,
        signature: signature,
      );
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> signCertificate({
    required Map<String, dynamic> certificateContent,
  }) async {
    final canonicalJson = jsonEncode(certificateContent);

    final signed = await signData(
      jsonData: canonicalJson,
    );

    return {
      "signatureAlgorithm": "ED25519",
      "publicKey": signed.publicKeyBase64,
      "signature": signed.signatureBase64,
    };
  }

  Future<bool> verifyCertificate({
    required Map<String, dynamic> certificateContent,
    required Map<String, dynamic> signatureBlock,
  }) async {
    try {
      final canonicalJson = jsonEncode(certificateContent);

      final signature = signatureBlock["signature"];
      final publicKey = signatureBlock["publicKey"];

      if (signature == null || publicKey == null) {
        return false;
      }

      return await verifyData(
        jsonData: canonicalJson,
        signatureBase64: signature,
        publicKeyBase64: publicKey,
      );
    } catch (_) {
      return false;
    }
  }
}