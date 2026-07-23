import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hcv_keystore_signer.dart';
import 'hcv_registry_service.dart';

class HCVIdentity {
  static const String _creatorIdKey = 'hcv_creator_id';
  static const String _deviceIdKey = 'hcv_device_id';
  static const String _creatorNameKey = 'hcv_creator_name';
  static const String _kycSessionIdKey = 'hcv_kyc_session_id';
  static const String _kycProviderKey = 'hcv_kyc_provider';
  static const String _kycStatusKey = 'hcv_kyc_status';
  static const String _kycLegalNameKey = 'hcv_kyc_legal_name';
  static const String _kycCountryKey = 'hcv_kyc_country';
  static const String _kycRecoveryAttemptKey = 'hcv_kyc_recovery_attempt_at';
  static const String _kycRecoveryErrorKey = 'hcv_kyc_recovery_error';

  Future<void> saveCreatorName(String creatorName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_creatorNameKey, creatorName.trim());
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
    final legalName = verifiedOutputs?['legalName']?.toString().trim() ?? '';
    final country = verifiedOutputs?['country']?.toString().trim() ?? '';
    if (legalName.isNotEmpty) {
      await prefs.setString(_kycLegalNameKey, legalName);
      await prefs.setString(_creatorNameKey, legalName);
    }
    if (country.isNotEmpty) {
      await prefs.setString(_kycCountryKey, country);
    }
  }

  Future<Map<String, dynamic>> loadIdentity({
    String defaultCreatorName = 'Local Android Creator',
    bool attemptKycRecovery = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic>? publicKey;
    var keyFingerprint = 'UNAVAILABLE';
    try {
      publicKey = await HCVKeystoreSigner.getPublicKey();
      keyFingerprint = sha256
          .convert(utf8.encode(jsonEncode(publicKey)))
          .toString();
    } catch (_) {}

    var creatorId = prefs.getString(_creatorIdKey);
    var deviceId = prefs.getString(_deviceIdKey);
    var creatorName = prefs.getString(_creatorNameKey);

    if (creatorId == null || creatorId.isEmpty) {
      creatorId = keyFingerprint == 'UNAVAILABLE'
          ? 'ACC-${sha256.convert(utf8.encode(DateTime.now().toUtc().toIso8601String())).toString().substring(0, 24).toUpperCase()}'
          : 'ACC-${keyFingerprint.substring(0, 24).toUpperCase()}';
    }
    deviceId ??= keyFingerprint == 'UNAVAILABLE'
        ? creatorId
        : 'DEV-${keyFingerprint.substring(24, 48).toUpperCase()}';

    final platformDefaultCreatorName =
        Platform.isIOS ? 'Local iPhone Creator' : defaultCreatorName;
    if (creatorName == null ||
        creatorName.isEmpty ||
        creatorName == 'Local Android Creator') {
      creatorName = platformDefaultCreatorName;
    }

    await prefs.setString(_creatorIdKey, creatorId);
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_creatorNameKey, creatorName);

    if (attemptKycRecovery &&
        publicKey != null &&
        keyFingerprint != 'UNAVAILABLE' &&
        prefs.getString(_kycStatusKey) != 'verified') {
      await _recoverKycIfDue(
        prefs: prefs,
        creatorId: creatorId,
        creatorName: creatorName,
        keyFingerprint: keyFingerprint,
        publicKey: publicKey,
      );
    }

    final kycSessionId = prefs.getString(_kycSessionIdKey) ?? '';
    final kycProvider = prefs.getString(_kycProviderKey) ?? '';
    final kycStatus = prefs.getString(_kycStatusKey) ?? 'not_started';
    final verifiedLegalName = prefs.getString(_kycLegalNameKey) ?? '';
    final verifiedLegalCountry = prefs.getString(_kycCountryKey) ?? '';
    final recoveryError = prefs.getString(_kycRecoveryErrorKey) ?? '';

    if (kycStatus == 'verified' && verifiedLegalName.isNotEmpty) {
      creatorName = verifiedLegalName;
      await prefs.setString(_creatorNameKey, creatorName);
    }

    final localDeviceHash = sha256
        .convert(utf8.encode('$creatorId|$deviceId'))
        .toString();
    final identityFingerprint = sha256
        .convert(utf8.encode('$creatorId|$creatorName|$keyFingerprint'))
        .toString();
    final isKycVerified = kycStatus == 'verified';

    return {
      'creatorId': creatorId,
      'accountId': creatorId,
      'creatorName': creatorName,
      'deviceId': 'PRIVATE_NOT_DISCLOSED',
      'localDeviceHash': localDeviceHash,
      'devicePublicKeyFingerprint': keyFingerprint,
      'issuer': 'LOCAL_DEVICE',
      'trustLevel':
          isKycVerified ? 'LEGAL_IDENTITY_VERIFIED' : 'LOCAL_KEY_VERIFIED',
      'identityAssuranceLevel':
          isKycVerified ? 'KYC_DOCUMENT_VERIFIED' : 'DEVICE_KEY_BOUND',
      'legalIdentityStatus': isKycVerified ? 'VERIFIED' : 'NOT_VERIFIED',
      'creatorKeyBinding': 'PUBLIC_KEY_FINGERPRINT_REQUIRED',
      'identityVersion': 4,
      'identityFingerprint': identityFingerprint,
      'privacyMode': 'MINIMIZED',
      'kycProvider': kycProvider,
      'kycSessionId': kycSessionId,
      'kycStatus': kycStatus,
      'verifiedLegalName': verifiedLegalName,
      'verifiedLegalCountry': verifiedLegalCountry,
      'kycRecoveryError': recoveryError,
      'publicKey': publicKey,
      'hardwareSerialCollected': false,
      'phoneSerialCollected': false,
      'publicKeyIncludedInCertificate': publicKey != null,
    };
  }

  Future<void> _recoverKycIfDue({
    required SharedPreferences prefs,
    required String creatorId,
    required String creatorName,
    required String keyFingerprint,
    required Map<String, dynamic> publicKey,
  }) async {
    final previous = DateTime.tryParse(
      prefs.getString(_kycRecoveryAttemptKey) ?? '',
    );
    if (previous != null &&
        DateTime.now().toUtc().difference(previous).inMinutes < 2) {
      return;
    }
    await prefs.setString(
      _kycRecoveryAttemptKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    try {
      final remote = await const HCVRegistryService().recoverKycSession(
        creatorId: creatorId,
        creatorName: creatorName,
        deviceKeyFingerprint: keyFingerprint,
        publicKey: publicKey,
      );
      if (remote['found'] == true) {
        final sessionId = remote['sessionId']?.toString() ?? '';
        final provider = remote['provider']?.toString() ?? 'stripe_identity';
        final status = remote['status']?.toString() ?? 'unknown';
        if (sessionId.isNotEmpty) {
          await saveKycSession(
            sessionId: sessionId,
            provider: provider,
            status: status,
          );
        }
        await saveKycStatus(
          status,
          verifiedOutputs: remote['verifiedOutputs'] is Map
              ? Map<String, dynamic>.from(remote['verifiedOutputs'] as Map)
              : null,
        );
      }
      await prefs.remove(_kycRecoveryErrorKey);
    } catch (error) {
      await prefs.setString(_kycRecoveryErrorKey, error.toString());
    }
  }
}
