import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HCVEngine {
  final List<Map<String, dynamic>> chain = [];

  final String sessionId = const Uuid().v4();
  final String createdAt = DateTime.now().toIso8601String();

  final Map<String, dynamic> meta = {
    "app": "hcv_app",
    "format": "HCV",
    "version": "1.0.0",
    "device": "unknown",
  };

  Map<String, dynamic>? content;

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? _keyPair;

  void start() {
    _addEvent("START");
  }

  void stop() {
    _addEvent("STOP");
  }

  void setContent({
    required String type,
    required String hash,
    int? size,
    String? name,
  }) {
    content = {
      "type": type,
      "hash": hash,
      if (size != null) "size": size,
      if (name != null) "name": name,
    };

    _addEvent("CONTENT_BOUND");
  }

  void _addEvent(String type) {
    final timestamp = DateTime.now().toIso8601String();
    final prevHash = chain.isEmpty ? "GENESIS" : chain.last["hash"];

    final event = {
      "type": type,
      "timestamp": timestamp,
      "prev": prevHash,
    };

    event["hash"] = _computeHash(event);
    chain.add(event);
  }

  String _computeHash(Map<String, dynamic> data) {
    return sha256.convert(utf8.encode(jsonEncode(data))).toString();
  }

  String _computeRootHash() {
    return sha256.convert(utf8.encode(jsonEncode(chain))).toString();
  }

  Future<void> _loadOrGenerateKeys() async {
    final prefs = await SharedPreferences.getInstance();

    final storedPrivate = prefs.getString("hcv_private");
    final storedPublic = prefs.getString("hcv_public");

    if (storedPrivate != null && storedPublic != null) {
      try {
        _keyPair = _decodeKeyPair(storedPrivate, storedPublic);
        return;
      } catch (_) {
        await prefs.remove("hcv_private");
        await prefs.remove("hcv_public");
      }
    }

    await _generateKeys();

    final encoded = _encodeKeyPair();

    await prefs.setString("hcv_private", encoded["private"]!);
    await prefs.setString("hcv_public", encoded["public"]!);
  }

  Future<void> _generateKeys() async {
    final keyGen = RSAKeyGenerator();

    keyGen.init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(
          BigInt.parse('65537'),
          2048,
          64,
        ),
        _secureRandom(),
      ),
    );

    final pair = keyGen.generateKeyPair();

    _keyPair = AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();

    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );

    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  Map<String, String> _encodeKeyPair() {
    final pub = _keyPair!.publicKey;
    final priv = _keyPair!.privateKey;

    final publicModulus = pub.modulus;
    final publicExponent = pub.exponent;
    final privateModulus = priv.modulus;
    final privateExponent = priv.privateExponent;

    if (publicModulus == null ||
        publicExponent == null ||
        privateModulus == null ||
        privateExponent == null) {
      throw Exception("RSA key not valid");
    }

    return {
      "public": jsonEncode({
        "modulus": base64Encode(_bigIntToBytes(publicModulus)),
        "exponent": base64Encode(_bigIntToBytes(publicExponent)),
      }),
      "private": jsonEncode({
        "modulus": base64Encode(_bigIntToBytes(privateModulus)),
        "privateExponent": base64Encode(_bigIntToBytes(privateExponent)),
      }),
    };
  }

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _decodeKeyPair(
    String privStr,
    String pubStr,
  ) {
    final pubJson = jsonDecode(pubStr);
    final privJson = jsonDecode(privStr);

    final pub = RSAPublicKey(
      _bytesToBigInt(base64Decode(pubJson["modulus"])),
      _bytesToBigInt(base64Decode(pubJson["exponent"])),
    );

    final priv = RSAPrivateKey(
      _bytesToBigInt(base64Decode(privJson["modulus"])),
      _bytesToBigInt(base64Decode(privJson["privateExponent"])),
      null,
      null,
    );

    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pub, priv);
  }

  Uint8List _bigIntToBytes(BigInt value) {
    var hex = value.toRadixString(16);

    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }

    final result = Uint8List(hex.length ~/ 2);

    for (int i = 0; i < result.length; i++) {
      final byteHex = hex.substring(i * 2, i * 2 + 2);
      result[i] = int.parse(byteHex, radix: 16);
    }

    return result;
  }

  BigInt _bytesToBigInt(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    if (hex.isEmpty) {
      throw Exception("Invalid BigInt bytes");
    }

    return BigInt.parse(hex, radix: 16);
  }

  String _sign(String data) {
    final signer = RSASigner(
      SHA256Digest(),
      '0609608648016503040201',
    );

    signer.init(
      true,
      PrivateKeyParameter<RSAPrivateKey>(_keyPair!.privateKey),
    );

    final RSASignature signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(data)),
    );

    return base64Encode(signature.bytes);
  }

  Map<String, String> _exportPublicKey() {
    final pub = _keyPair!.publicKey;

    final modulus = pub.modulus;
    final exponent = pub.exponent;

    if (modulus == null || exponent == null) {
      throw Exception("Invalid public key");
    }

    return {
      "modulus": base64Encode(_bigIntToBytes(modulus)),
      "exponent": base64Encode(_bigIntToBytes(exponent)),
    };
  }

  Future<String> exportToFile() async {
    if (_keyPair == null) {
      await _loadOrGenerateKeys();
    }

    final dir = await getApplicationDocumentsDirectory();

    final rootHash = _computeRootHash();
    final signature = _sign(rootHash);

    final file = File(
      p.join(dir.path, "hcv_${DateTime.now().millisecondsSinceEpoch}.hcv"),
    );

    final payload = {
      "sessionId": sessionId,
      "createdAt": createdAt,
      "meta": meta,
      "content": content,
      "rootHash": rootHash,
      "signature": signature,
      "publicKey": _exportPublicKey(),
      "chain": chain,
    };

    await file.writeAsString(jsonEncode(payload));

    return file.path;
  }
}