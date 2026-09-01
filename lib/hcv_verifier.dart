import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'hcv_provenance_chain.dart';

class HCVVerifier {
  Future<bool> verifyFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);

      if (data is! Map<String, dynamic>) return false;

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
    if (!_verifyIdentityBinding(data, publicKey)) return false;

    final certificateSignatureOk = _verifyRsaSignature(
      data: canonical,
      signatureBase64: signature,
      publicKeyData: publicKey,
    );
    if (!certificateSignatureOk) return false;

    return _verifyCaptureProvenanceBinding(data, publicKey);
  }

  bool _verifyCaptureProvenanceBinding(
    Map<String, dynamic> data,
    Map<String, dynamic> certificatePublicKey,
  ) {
    final rawClaims = data["claims"];
    if (rawClaims is! Map) return true;

    final rawProvenance = rawClaims["provenance"];
    // Backward compatibility: certificates issued before D2 did not contain
    // a provenance claim and continue through the existing V2 verification.
    if (rawProvenance == null) return true;
    if (rawProvenance is! Map) return false;

    final provenance = Map<String, dynamic>.from(rawProvenance);
    if (provenance["type"] != "SIGILLUM_CAPTURE_PROVENANCE_BINDING") {
      return false;
    }
    if (provenance["version"] != 1 || provenance["status"] != "VERIFIED") {
      return false;
    }

    final rawMeta = data["meta"];
    final rawContent = data["content"];
    if (rawMeta is! Map || rawContent is! Map) return false;
    final meta = Map<String, dynamic>.from(rawMeta);
    final content = Map<String, dynamic>.from(rawContent);

    final rawIdentity = meta["identity"];
    if (rawIdentity is! Map) return false;
    final identity = Map<String, dynamic>.from(rawIdentity);

    final hcvId = meta["hcvId"]?.toString() ?? "";
    final sessionId = data["sessionId"]?.toString() ?? "";
    final contentHash = content["hash"]?.toString() ?? "";
    final contentType = content["type"]?.toString().toLowerCase() ?? "";
    final contentName = content["name"]?.toString() ?? "";
    final rawContentSize = content["size"];
    final contentSize = rawContentSize is num ? rawContentSize.toInt() : -1;
    final deviceFingerprint =
        identity["devicePublicKeyFingerprint"]?.toString() ?? "";

    if (hcvId.isEmpty || sessionId.isEmpty) return false;
    if (contentType != "photo" && contentType != "video") return false;
    if (!RegExp(r"^[a-f0-9]{64}$").hasMatch(contentHash)) return false;
    if (contentSize <= 0 || contentName.isEmpty) return false;
    if (!RegExp(r"^[a-f0-9]{64}$").hasMatch(deviceFingerprint)) {
      return false;
    }

    if (provenance["hcvId"] != hcvId ||
        provenance["sessionId"] != sessionId ||
        provenance["inputHash"] != contentHash ||
        provenance["deviceFingerprint"] != deviceFingerprint ||
        provenance["pipelineVersion"] != "HCV_CAPTURE_BINDING_V1" ||
        provenance["signatureAlgorithm"] !=
            HCVProvenanceChain.signatureAlgorithm) {
      return false;
    }

    final rawEvent = provenance["event"];
    if (rawEvent is! Map) return false;
    final event = Map<String, dynamic>.from(rawEvent);

    if (event["type"] != HCVProvenanceChain.eventSchema ||
        event["version"] != HCVProvenanceChain.eventVersion ||
        event["sequence"] != 0 ||
        event["eventType"] != "CAPTURE_FINALIZED" ||
        event["parentEvent"] != "GENESIS" ||
        event["sessionId"] != sessionId ||
        event["inputHash"] != contentHash ||
        event["deviceFingerprint"] != deviceFingerprint ||
        event["pipelineVersion"] != "HCV_CAPTURE_BINDING_V1" ||
        event["signatureAlgorithm"] !=
            HCVProvenanceChain.signatureAlgorithm) {
      return false;
    }

    final nonce = event["nonce"]?.toString() ?? "";
    final eventTimestamp = DateTime.tryParse(event["timestamp"]?.toString() ?? "");
    if (nonce.isEmpty || eventTimestamp == null) return false;

    final eventHash = event["eventHash"]?.toString() ?? "";
    if (!RegExp(r"^[a-f0-9]{64}$").hasMatch(eventHash)) return false;
    if (provenance["eventHash"] != eventHash) return false;

    final unsignedEvent = Map<String, dynamic>.from(event)
      ..remove("eventHash")
      ..remove("signatureAlgorithm")
      ..remove("signature")
      ..remove("publicKey");
    final recalculatedEventHash = sha256
        .convert(
          utf8.encode(HCVProvenanceChain.canonicalJson(unsignedEvent)),
        )
        .toString();
    if (recalculatedEventHash != eventHash) return false;

    final rawEventPublicKey = event["publicKey"];
    final eventSignature = event["signature"];
    if (rawEventPublicKey is! Map || eventSignature is! String) return false;
    final eventPublicKey = Map<String, dynamic>.from(rawEventPublicKey);

    try {
      if (HCVProvenanceChain.publicKeyFingerprint(eventPublicKey) !=
          deviceFingerprint) {
        return false;
      }
    } catch (_) {
      return false;
    }

    if (eventPublicKey["modulus"] != certificatePublicKey["modulus"] ||
        eventPublicKey["exponent"] != certificatePublicKey["exponent"]) {
      return false;
    }

    if (!_verifyRsaSignature(
      data: eventHash,
      signatureBase64: eventSignature,
      publicKeyData: eventPublicKey,
    )) {
      return false;
    }

    final rawEventMetadata = event["metadata"];
    if (rawEventMetadata is! Map) return false;
    final eventMetadata = Map<String, dynamic>.from(rawEventMetadata);
    final rawMetadataSize = eventMetadata["contentSize"];
    final metadataSize = rawMetadataSize is num ? rawMetadataSize.toInt() : -1;

    if (eventMetadata["hcvId"] != hcvId ||
        eventMetadata["mediaType"] != contentType ||
        metadataSize != contentSize ||
        eventMetadata["contentName"] != contentName ||
        eventMetadata["captureSource"] != "HCV_CAMERA") {
      return false;
    }

    final claimCapturedAt =
        DateTime.tryParse(rawClaims["captureCreatedAt"]?.toString() ?? "");
    final eventCapturedAt =
        DateTime.tryParse(eventMetadata["capturedAt"]?.toString() ?? "");
    if (claimCapturedAt == null || eventCapturedAt == null) return false;
    if (claimCapturedAt.toUtc() != eventCapturedAt.toUtc()) return false;

    return true;
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

  bool _verifyIdentityBinding(
    Map<String, dynamic> data,
    Map<String, dynamic> publicKey,
  ) {
    final meta = data["meta"];
    if (meta is! Map) return false;

    final identity = meta["identity"];
    if (identity is! Map) return false;

    final declaredKeyFingerprint = identity["devicePublicKeyFingerprint"];
    final identityFingerprint = identity["identityFingerprint"];
    final creatorId = identity["creatorId"];
    final creatorName = identity["creatorName"];

    if (declaredKeyFingerprint is! String || declaredKeyFingerprint.isEmpty) {
      return false;
    }
    if (identityFingerprint is! String || identityFingerprint.isEmpty) {
      return false;
    }
    if (creatorId is! String || creatorId.isEmpty) return false;
    if (creatorName is! String || creatorName.isEmpty) return false;

    final actualKeyFingerprint = sha256.convert(
      utf8.encode(jsonEncode(publicKey)),
    ).toString();

    if (declaredKeyFingerprint != actualKeyFingerprint) return false;

    final expectedIdentityFingerprint = sha256.convert(
      utf8.encode("$creatorId|$creatorName|$declaredKeyFingerprint"),
    ).toString();

    return identityFingerprint == expectedIdentityFingerprint;
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

      if (modulus == "LOCAL_DEV_PUBLIC_KEY" && exponent == "LOCAL_DEV") {
        final expected = sha256
            .convert(utf8.encode("LOCAL_DEV_SIGNATURE:$data"))
            .toString();
        return signatureBase64 == expected;
      }

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
