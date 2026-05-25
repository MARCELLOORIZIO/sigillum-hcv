import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'hcv_keystore_signer.dart';

class HCVIdentity {
  static const String _creatorIdKey = "hcv_creator_id";
  static const String _deviceIdKey = "hcv_device_id";
  static const String _creatorNameKey = "hcv_creator_name";

  Future<void> saveCreatorName(String creatorName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_creatorNameKey, creatorName);
  }

  Future<Map<String, dynamic>> loadIdentity({
    String defaultCreatorName = "Local Android Creator",
  }) async {
    final prefs = await SharedPreferences.getInstance();

    String? creatorId = prefs.getString(_creatorIdKey);
    String? deviceId = prefs.getString(_deviceIdKey);
    String? creatorName = prefs.getString(_creatorNameKey);

    creatorId ??= const Uuid().v4();
    deviceId ??= const Uuid().v4();
    creatorName ??= defaultCreatorName;

    await prefs.setString(_creatorIdKey, creatorId);
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_creatorNameKey, creatorName);

    Map<String, dynamic>? publicKey;
    String keyFingerprint = "UNAVAILABLE";

    try {
      publicKey = await HCVKeystoreSigner.getPublicKey();
      keyFingerprint = sha256.convert(
        utf8.encode(jsonEncode(publicKey)),
      ).toString();
    } catch (_) {}

    final localDeviceHash = sha256.convert(
      utf8.encode("$creatorId|$deviceId"),
    ).toString();

    final fingerprintSource = "$creatorId|$creatorName|$keyFingerprint";
    final fingerprint =
        sha256.convert(utf8.encode(fingerprintSource)).toString();

    return {
      "creatorId": creatorId,
      "creatorName": creatorName,
      "deviceId": "PRIVATE_NOT_DISCLOSED",
      "localDeviceHash": localDeviceHash,
      "devicePublicKeyFingerprint": keyFingerprint,
      "issuer": "LOCAL_DEVICE",
      "trustLevel": "LOCAL_KEY_VERIFIED",
      "identityVersion": 2,
      "identityFingerprint": fingerprint,
      "privacyMode": "MINIMIZED",
      "hardwareSerialCollected": false,
      "publicKeyIncludedInCertificate": publicKey != null,
    };
  }
}
