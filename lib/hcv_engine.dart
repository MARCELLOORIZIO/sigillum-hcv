import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'hcv_capture_provenance.dart';
import 'hcv_identity.dart';
import 'hcv_keystore_signer.dart';
import 'hcv_software_attestation.dart';

class HCVEngine {
  final List<Map<String, dynamic>> chain = [];

  final String sessionId = const Uuid().v4();
  final String createdAt = DateTime.now().toIso8601String();
  final String hcvId = _newHcvId();

  static String _newHcvId() {
    final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
    return 'HCV-${raw.substring(0, 16)}';
  }

  Map<String, dynamic> meta = {
    "app": "hcv_app",
    "format": "HCV",
    "version": "2.0.0",
    "device": Platform.isIOS
        ? "ios"
        : Platform.isAndroid
            ? "android"
            : Platform.operatingSystem,
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

  Future<void> _attachSoftwareAttestation() async {
    final packageInfo = await PackageInfo.fromPlatform();
    meta = {
      ...meta,
      "softwareAttestation": HCVSoftwareAttestation.current(
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      ),
    };
  }

  Future<void> _attachCaptureProvenance(Directory outputDirectory) async {
    if (claims["captureSource"] != "HCV_CAMERA") return;

    final currentContent = content;
    if (currentContent == null) {
      throw StateError("Camera capture content is unavailable");
    }

    final mediaType =
        currentContent["type"]?.toString().trim().toLowerCase() ?? "";
    if (mediaType != "photo" && mediaType != "video") {
      throw StateError("Unsupported HCV camera capture type: $mediaType");
    }

    final existingProvenance = claims["provenance"];
    if (existingProvenance is Map &&
        existingProvenance["type"] == HCVCaptureProvenance.bindingSchema &&
        existingProvenance["status"] == "VERIFIED") {
      return;
    }

    final contentHash = currentContent["hash"]?.toString().trim() ?? "";
    final rawSize = currentContent["size"];
    final contentSize = rawSize is num ? rawSize.toInt() : 0;
    final contentName = currentContent["name"]?.toString().trim() ?? "";
    final capturedAtRaw = claims["captureCreatedAt"]?.toString().trim() ?? "";
    final capturedAt = DateTime.tryParse(capturedAtRaw);

    if (!RegExp(r"^[a-f0-9]{64}$").hasMatch(contentHash)) {
      throw StateError("Camera capture SHA-256 is invalid");
    }
    if (contentSize <= 0) {
      throw StateError("Camera capture size is unavailable");
    }
    if (contentName.isEmpty) {
      throw StateError("Camera capture name is unavailable");
    }
    if (capturedAt == null) {
      throw StateError("Camera capture timestamp is unavailable");
    }

    final rawIdentity = meta["identity"];
    if (rawIdentity is! Map) {
      throw StateError("HCV identity is unavailable for capture provenance");
    }
    final identity = Map<String, dynamic>.from(rawIdentity);

    final binding = await HCVCaptureProvenance(
      identityLoader: () async => identity,
    ).bindFinalizedCapture(
      outputDirectory: outputDirectory,
      hcvId: hcvId,
      sessionId: sessionId,
      mediaType: mediaType,
      contentHash: contentHash,
      contentSize: contentSize,
      contentName: contentName,
      capturedAt: capturedAt,
    );

    claims = {
      ...claims,
      "provenance": binding.toClaim(hcvId: hcvId),
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
    // D3: bind the exact software identity into meta before the certificate
    // payload is canonicalized and signed by the device key.
    await _attachSoftwareAttestation();

    print("===== HCV ENGINE IDENTITY =====");
    print(meta["identity"]);
    print("================================");

    final dir = Platform.isAndroid
        ? Directory("/storage/emulated/0/Download")
        : await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // D2: bind the finalized PHOTO/VIDEO hash to this exact HCV session and
    // device signing key before the certificate payload itself is signed.
    await _attachCaptureProvenance(dir);

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
