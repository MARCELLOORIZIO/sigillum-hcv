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
  static const String _kycLegalNameKey = "hcv_kyc_legal_name";
  static const String _kycCountryKey = "hcv_kyc_country";

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

  Future<void> saveKycStatus(
    String status, {
    Map<String, dynamic>? verifiedOutputs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kycStatusKey, status);

    final legalName = verifiedOutputs?["legalName"]?.toString().trim() ?? "";
    final country = verifiedOutputs?["country"]?.toString().trim() ?? "";

    if (legalName.isNotEmpty) {
      await prefs.setString(_kycLegalNameKey, legalName);
      await prefs.setString(_creatorNameKey, legalName);
    }
    if (country.isNotEmpty) {
      await prefs.setString(_kycCountryKey, country);
    }
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
    final verifiedLegalName = prefs.getString(_kycLegalNameKey) ?? "";
    final verifiedLegalCountry = prefs.getString(_kycCountryKey) ?? "";

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

    final isKycVerified = kycStatus == "verified";
    if (isKycVerified && verifiedLegalName.isNotEmpty) {
      creatorName = verifiedLegalName;
      await prefs.setString(_creatorNameKey, creatorName);
    }

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
      "verifiedLegalName": verifiedLegalName,
      "verifiedLegalCountry": verifiedLegalCountry,
      "publicKey": publicKey,
      "hardwareSerialCollected": false,
      "phoneSerialCollected": false,
      "publicKeyIncludedInCertificate": publicKey != null,
    };
  }
}
