import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';


class HCVVerifier {
  Future<bool> verifyFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString);

    if (!data.containsKey("chain")) return false;
    if (!data.containsKey("rootHash")) return false;
    if (!data.containsKey("signature")) return false;
    if (!data.containsKey("publicKey")) return false;

    final chain = data["chain"] as List;
    final rootHash = data["rootHash"];
    final signature = data["signature"];
    final publicKeyData = data["publicKey"];

    if (chain.isEmpty) return false;

    bool start = false;
    bool stop = false;

    for (int i = 0; i < chain.length; i++) {
      final event = Map<String, dynamic>.from(chain[i]);

      if (event["type"] == "START") start = true;
      if (event["type"] == "STOP") stop = true;

      final storedHash = event["hash"];
      final storedPrev = event["prev"];

      final cleanEvent = Map<String, dynamic>.from(event);
      cleanEvent.remove("hash");

      final recalculatedHash = _computeHash(cleanEvent);

      if (storedHash != recalculatedHash) return false;

      if (i == 0) {
        if (storedPrev != "GENESIS") return false;
      } else {
        if (storedPrev != chain[i - 1]["hash"]) return false;
      }
    }

    final recalculatedRoot =
        sha256.convert(utf8.encode(jsonEncode(chain))).toString();

    if (rootHash != recalculatedRoot) return false;

    // 🔐 Verifica firma RSA
    final pubKey = RSAPublicKey(
      BigInt.parse(
        _decodeBase64(publicKeyData["modulus"]),
        radix: 16,
      ),
      BigInt.parse(
        _decodeBase64(publicKeyData["exponent"]),
        radix: 16,
      ),
    );

    final verifier = RSASigner(
    SHA256Digest(),
    '0609608648016503040201',
    );

    verifier.init(
    false,
    PublicKeyParameter<RSAPublicKey>(pubKey),
    );

    final sig = RSASignature(base64Decode(signature));

    final isValid = verifier.verifySignature(
      Uint8List.fromList(utf8.encode(rootHash)),
      sig,
    );

    return start && stop && isValid;
  }

  String _computeHash(Map<String, dynamic> data) {
    return sha256.convert(utf8.encode(jsonEncode(data))).toString();
  }

  String _decodeBase64(String input) {
    final bytes = base64Decode(input);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}