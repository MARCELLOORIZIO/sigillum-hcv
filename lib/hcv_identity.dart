import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'hcv_keystore_signer.dart';

class HCVIdentity {
  static const String _creatorIdKey = "hcv_creator_id";
  static const String _deviceIdKey = "hcv_device_id";
  static const String _creatorNameKey = "hcv_creator_name";
  static const String _kycSessionIdKey = "hcv_kyc_session_id";
  static const String _kycProviderKey = "hcv_kyc_provider";
  static const String _kycStatusKey = "hcv_kyc_status";

  Future<void> saveCreatorName(String creatorName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_creatorNameKey, creatorName);
  }

  Future<void> saveKycSession({
    required String sessionId,
    required String provider,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kycSessionIdKey, sessionId);
    await prefs.setString(_kycProviderKey, provider);
    await prefs.setString(_kycStatusKey, status);
  }

  Future<void> saveKycStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kycStatusKey, status);
  }

  Future<Map<String, dynamic>> loadIdentity({
    String defaultCreatorName = "Local Android Creator",
  }) async {
    final prefs = await SharedPreferences.getInstance();

    String? creatorId = prefs.getString(_creatorIdKey);
    String? deviceId = prefs.getString(_deviceIdKey);
    String? creatorName = prefs.getString(_creatorNameKey);
    final kycSessionId = prefs.getString(_kycSessionIdKey) ?? "";
    final kycProvider = prefs.getString(_kycProviderKey) ?? "";
    final kycStatus = prefs.getString(_kycStatusKey) ?? "not_started";

    creatorId ??= const Uuid().v4();
    deviceId ??= const Uuid().v4();
    final platformDefaultCreatorName =
        Platform.isIOS ? "Local iPhone Creator" : defaultCreatorName;
    if (creatorName == null || creatorName == "Local Android Creator") {
      creatorName = platformDefaultCreatorName;
    }

    await prefs.setString(_creatorIdKey, creatorId);
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_creatorNameKey, creatorName);

    Map<String, dynamic>? publicKey;
    String keyFingerprint = "UNAVAILABLE";

    try {
      publicKey = await HCVKeystoreSigner.getPublicKey();
      keyFingerprint = sha256
          .convert(
            utf8.encode(jsonEncode(publicKey)),
          )
          .toString();
    } catch (_) {}

    final localDeviceHash = sha256
        .convert(
          utf8.encode("$creatorId|$deviceId"),
        )
        .toString();

    final fingerprintSource = "$creatorId|$creatorName|$keyFingerprint";
    final fingerprint =
        sha256.convert(utf8.encode(fingerprintSource)).toString();
    final isKycVerified = kycStatus == "verified";

    return {
      "creatorId": creatorId,
      "creatorName": creatorName,
      "deviceId": "PRIVATE_NOT_DISCLOSED",
      "localDeviceHash": localDeviceHash,
      "devicePublicKeyFingerprint": keyFingerprint,
      "issuer": "LOCAL_DEVICE",
      "trustLevel":
          isKycVerified ? "LEGAL_IDENTITY_VERIFIED" : "LOCAL_KEY_VERIFIED",
      "identityAssuranceLevel":
          isKycVerified ? "KYC_DOCUMENT_VERIFIED" : "DEVICE_KEY_BOUND",
      "legalIdentityStatus": isKycVerified ? "VERIFIED" : "NOT_VERIFIED",
      "creatorKeyBinding": "PUBLIC_KEY_FINGERPRINT_REQUIRED",
      "identityVersion": 3,
      "identityFingerprint": fingerprint,
      "privacyMode": "MINIMIZED",
      "kycProvider": kycProvider,
      "kycSessionId": kycSessionId,
      "kycStatus": kycStatus,
      "hardwareSerialCollected": false,
      "phoneSerialCollected": false,
      "publicKeyIncludedInCertificate": publicKey != null,
    };
  }
}
