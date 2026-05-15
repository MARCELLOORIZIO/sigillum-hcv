import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'hcv_identity.dart';
import 'hcv_keystore_signer.dart';

class HCVEngine {
  final List<Map<String, dynamic>> chain = [];

  final String sessionId = const Uuid().v4();
  final String createdAt = DateTime.now().toIso8601String();
  final String hcvId =
      "HCV-${const Uuid().v4().split('-').first.toUpperCase()}";

  Map<String, dynamic> meta = {
    "app": "hcv_app",
    "format": "HCV",
    "version": "2.0.0",
    "device": "android",
  };

  Map<String, dynamic> claims = {};
  Map<String, dynamic>? liveSignals;
  Map<String, dynamic>? content;

  void setClaims(Map<String, dynamic> value) {
    claims = value;
  }

  void setLiveSignals(Map<String, dynamic> value) {
    liveSignals = value;
  }

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

  Future<void> _attachIdentity() async {
    final identity = await HCVIdentity().loadIdentity();

    meta = {
      ...meta,
      "identity": identity,
    };
  }

  void _attachPublishData() {
    meta = {
      ...meta,
      "hcvId": hcvId,
      "verificationUrl": "hcv://verify/$hcvId",
      "publishMode": "MEDIA_PLUS_ONLINE_REGISTRY",
    };
  }

  Map<String, dynamic> _buildSignedPayload({
    required String rootHash,
  }) {
    return {
      "format": "HCV_CERTIFICATE",
      "version": 2,
      "sessionId": sessionId,
      "createdAt": createdAt,
      "meta": meta,
      "content": content,
      "claims": claims,
      if (liveSignals != null) "liveSignals": liveSignals,
      "rootHash": rootHash,
      "chain": chain,
    };
  }

  String _canonicalJson(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  Future<String> exportToFile() async {
    if (content == null) {
      throw Exception("Content non impostato");
    }

    await _attachIdentity();
    _attachPublishData();

    print("===== HCV ENGINE IDENTITY =====");
    print(meta["identity"]);
    print("================================");

    final dir = Platform.isAndroid
        ? Directory("/storage/emulated/0/Download")
        : await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final rootHash = _computeRootHash();

    final signedPayload = _buildSignedPayload(
      rootHash: rootHash,
    );

    final canonical = _canonicalJson(signedPayload);

    final signature = await HCVKeystoreSigner.sign(canonical);
    final publicKey = await HCVKeystoreSigner.getPublicKey();

    final payload = {
      ...signedPayload,
      "signatureAlgorithm": "RSA-SHA256-HCV-V2",
      "signature": signature,
      "publicKey": publicKey,
    };

    final file = File(
      p.join(dir.path, "hcv_${DateTime.now().millisecondsSinceEpoch}.hcv"),
    );

    await file.writeAsString(
      const JsonEncoder.withIndent("  ").convert(payload),
    );

    return file.path;
  }
}
