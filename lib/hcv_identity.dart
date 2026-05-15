import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class HCVIdentity {
  static const String _creatorIdKey = "hcv_creator_id";
  static const String _deviceIdKey = "hcv_device_id";
  static const String _creatorNameKey = "hcv_creator_name";

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

    final fingerprintSource = "$creatorId|$deviceId|$creatorName";
    final fingerprint = sha256.convert(utf8.encode(fingerprintSource)).toString();

    return {
      "creatorId": creatorId,
      "creatorName": creatorName,
      "deviceId": deviceId,
      "issuer": "LOCAL_DEVICE",
      "trustLevel": "LOCAL_VERIFIED",
      "identityVersion": 1,
      "identityFingerprint": fingerprint,
    };
  }
}