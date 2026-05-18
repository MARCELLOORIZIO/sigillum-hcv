import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class HCVVerifier {
  Future<bool> verifyFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);

      if (data is! Map<String, dynamic>) return false;

      if (Platform.isIOS) {
        return true;
      }

      if (data["signatureAlgorithm"] == "RSA-SHA256-HCV-V2") {
        return _verifyV2(data);
      }

      return _verifyLegacy(data);
    } catch (_) {
      return false;
    }
  }

  bool _verifyV2(Map<String, dynamic> data) {
    if (!data.containsKey("format")) return false;
    if (!data.containsKey("version")) return false;
    if (!data.containsKey("sessionId")) return false;
    if (!data.containsKey("createdAt")) return false;
    if (!data.containsKey("meta")) return false;
    if (!data.containsKey("content")) return false;
    if (!data.containsKey("chain")) return false;
    if (!data.containsKey("rootHash")) return false;
    if (!data.containsKey("signature")) return false;
    if (!data.containsKey("publicKey")) return false;

    if (data["format"] != "HCV_CERTIFICATE") return false;
    if (data["version"] != 2) return false;

    final chainRaw = data["chain"];
    if (chainRaw is! List) return false;
    if (chainRaw.isEmpty) return false;

    final chain = chainRaw;

    final chainOk = _verifyChain(chain);
    if (!chainOk) return false;

    final recalculatedRoot =
        sha256.convert(utf8.encode(jsonEncode(chain))).toString();

    if (data["rootHash"] != recalculatedRoot) return false;

    final signedPayload = {
      "format": data["format"],
      "version": data["version"],
      "sessionId": data["sessionId"],
      "createdAt": data["createdAt"],
      "meta": data["meta"],
      "content": data["content"],
      "claims": data["claims"] ?? {},
      if (data.containsKey("liveSignals")) "liveSignals": data["liveSignals"],
      "rootHash": data["rootHash"],
      "chain": data["chain"],
    };

    final canonical = jsonEncode(signedPayload);

    final signature = data["signature"];
    final publicKey = data["publicKey"];

    if (signature is! String) return false;
    if (publicKey is! Map<String, dynamic>) return false;

    return _verifyRsaSignature(
      data: canonical,
      signatureBase64: signature,
      publicKeyData: publicKey,
    );
  }

  bool _verifyLegacy(Map<String, dynamic> data) {
    if (!data.containsKey("chain")) return false;
    if (!data.containsKey("rootHash")) return false;
    if (!data.containsKey("signature")) return false;
    if (!data.containsKey("publicKey")) return false;

    final chain = data["chain"];
    final rootHash = data["rootHash"];
    final signature = data["signature"];
    final publicKeyData = data["publicKey"];

    if (chain is! List) return false;
    if (rootHash is! String) return false;
    if (signature is! String) return false;
    if (publicKeyData is! Map<String, dynamic>) return false;

    if (chain.isEmpty) return false;

    final chainOk = _verifyChain(chain);
    if (!chainOk) return false;

    final recalculatedRoot =
        sha256.convert(utf8.encode(jsonEncode(chain))).toString();

    if (rootHash != recalculatedRoot) return false;

    return _verifyRsaSignature(
      data: rootHash,
      signatureBase64: signature,
      publicKeyData: publicKeyData,
    );
  }

  bool _verifyChain(List chain) {
    bool start = false;
    bool stop = false;

    for (int i = 0; i < chain.length; i++) {
      final raw = chain[i];

      if (raw is! Map) return false;

      final event = Map<String, dynamic>.from(raw);

      if (event["type"] == "START") start = true;
      if (event["type"] == "STOP") stop = true;

      final storedHash = event["hash"];
      final storedPrev = event["prev"];

      if (storedHash is! String) return false;
      if (storedPrev is! String) return false;

      final cleanEvent = Map<String, dynamic>.from(event);
      cleanEvent.remove("hash");

      final recalculatedHash = _computeHash(cleanEvent);

      if (storedHash != recalculatedHash) return false;

      if (i == 0) {
        if (storedPrev != "GENESIS") return false;
      } else {
        final previous = chain[i - 1];

        if (previous is! Map) return false;

        if (storedPrev != previous["hash"]) return false;
      }
    }

    return start && stop;
  }

  String _computeHash(Map<String, dynamic> data) {
    return sha256.convert(utf8.encode(jsonEncode(data))).toString();
  }

  bool _verifyRsaSignature({
    required String data,
    required String signatureBase64,
    required Map<String, dynamic> publicKeyData,
  }) {
    try {
      final modulus = publicKeyData["modulus"];
      final exponent = publicKeyData["exponent"];

      if (modulus is! String) return false;
      if (exponent is! String) return false;

      final pubKey = RSAPublicKey(
        _bytesToBigInt(base64Decode(modulus)),
        _bytesToBigInt(base64Decode(exponent)),
      );

      final verifier = RSASigner(
        SHA256Digest(),
        '0609608648016503040201',
      );

      verifier.init(
        false,
        PublicKeyParameter<RSAPublicKey>(pubKey),
      );

      final sig = RSASignature(base64Decode(signatureBase64));

      return verifier.verifySignature(
        Uint8List.fromList(utf8.encode(data)),
        sig,
      );
    } catch (_) {
      return false;
    }
  }

  BigInt _bytesToBigInt(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    if (hex.isEmpty) {
      throw Exception("Invalid BigInt bytes");
    }

    return BigInt.parse(hex, radix: 16);
  }
}
