import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'hcv_auth_service.dart';
import 'hcv_identity.dart';
import 'hcv_keystore_signer.dart';
import 'hcv_secure_store.dart';

class CommercialAccountException implements Exception {
  const CommercialAccountException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class _CommercialCurrentAppleEntitlement {
  const _CommercialCurrentAppleEntitlement({
    required this.productId,
    required this.transactionId,
    required this.receiptData,
  });

  final String productId;
  final String transactionId;
  final String receiptData;
}

class CommercialAccountService {
  const CommercialAccountService({
    this.baseUrl = const String.fromEnvironment(
      'SIGILLUM_API_BASE_URL',
      defaultValue: 'https://sigillum-registry-production.onrender.com',
    ),
  });

  static const _sessionTokenKey = 'sigillum.auth.session.v1';
  static const _timeout = Duration(seconds: 20);
  // Render Free can take about a minute to wake after idling. Registration is
  // a non-idempotent POST, so do not retry it after a client timeout: allow the
  // original request enough time to finish instead.
  static const _registrationTimeout = Duration(seconds: 90);
  static const _nativeStoreKit2 = MethodChannel('hcv.storekit2');
  static const _appleCreatorProductIds = <String>{
    'com.sigillum.hcv.creator.weekly',
    'com.sigillum.hcv.creator.monthly',
    'com.sigillum.hcv.creator.annual',
  };
  static const _appleVerificationRetryDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 600),
    Duration(milliseconds: 1200),
    Duration(milliseconds: 2400),
    Duration(milliseconds: 4000),
    Duration(milliseconds: 8000),
  ];
  static const termsVersion = '2026-08-18';
  static const privacyVersion = '2026-08-18';

  final String baseUrl;

  HCVAuthService get _auth => HCVAuthService(baseUrl: baseUrl);

  Future<Map<String, dynamic>?> restoreAccount() async {
    return _auth.restoreSession();
  }

  Future<void> register({
    required String email,
    required String password,
    required String creatorName,
    required bool acceptTerms,
    required bool acknowledgePrivacy,
    required bool adultConfirmed,
    required String languageCode,
  }) async {
    final proof = await _deviceProof();
    await _request(
      'POST',
      '/api/auth/register',
      timeout: _registrationTimeout,
      body: {
        'email': email.trim(),
        'password': password,
        'creatorName': creatorName.trim(),
        'creatorId': proof.remove('creatorId'),
        'acceptTerms': acceptTerms,
        'acknowledgePrivacy': acknowledgePrivacy,
        'adultConfirmed': adultConfirmed,
        'languageCode': languageCode,
        'termsVersion': termsVersion,
        'privacyVersion': privacyVersion,
        ...proof,
      },
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _request(
      'POST',
      '/api/auth/verify-email',
      body: {'email': email.trim(), 'code': code.trim()},
    );
  }

  Future<void> resendEmailCode(
    String email, {
    required String languageCode,
  }) async {
    await _request(
      'POST',
      '/api/auth/resend-email-code',
      body: {'email': email.trim(), 'languageCode': languageCode},
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.login(email: email, password: password);
    } on HCVAuthException catch (error) {
      throw CommercialAccountException(
        error.message,
        statusCode: error.statusCode,
        code: error.code,
      );
    }
  }

  Future<void> forgotPassword(
    String email, {
    required String languageCode,
  }) async {
    await _request(
      'POST',
      '/api/auth/password/forgot',
      body: {'email': email.trim(), 'languageCode': languageCode},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _request(
      'POST',
      '/api/auth/password/reset',
      body: {
        'email': email.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> startIdentityVerification() async {
    return _authorizedRequest('POST', '/api/identity/kyc/start');
  }

  Future<Map<String, dynamic>> refreshIdentityVerification() async {
    return _authorizedRequest('GET', '/api/identity/kyc/status');
  }

  Future<Map<String, dynamic>> billingStatus() async {
    final serverBilling = await _authorizedRequest('GET', '/api/billing/status');
    final normalizedServerBilling = _normalizeServerBilling(serverBilling);

    if (!Platform.isIOS) return normalizedServerBilling;

    // A recent server status is not a generic cached entitlement: the backend
    // marks verificationFresh=true only after an Apple server verification
    // completed within its bounded freshness window. Accept that proof before
    // invoking StoreKit again, because TestFlight can expose an empty or
    // transient currentEntitlements view immediately after successful server
    // verification. Stale or non-active server states still continue through
    // StoreKit/reconcile and remain fail-closed.
    final freshServerStatus =
        normalizedServerBilling['status']?.toString() ?? '';
    final freshServerVerified =
        normalizedServerBilling['verificationFresh'] == true;
    if (freshServerVerified &&
        (freshServerStatus == 'active' || freshServerStatus == 'grace')) {
      return <String, dynamic>{
        ...normalizedServerBilling,
        'verified': true,
        'appleEntitlement': 'server_fresh',
      };
    }

    // A cached backend row alone is not enough to grant iOS Creator access.
    // Prefer a verified StoreKit 2 current entitlement when one is available.
    // If StoreKit exposes no usable active transaction (a condition observed in
    // TestFlight even while the server-owned subscription is active), fall back
    // to a fresh server-to-server reconciliation with Apple. The fallback is
    // still fail-closed: access is granted only after Apple's server confirms
    // active/grace for the originalTransactionId already owned by this account.
    final currentEntitlements = await _currentAppleEntitlements();

    Map<String, dynamic>? lastVerification;
    for (final entitlement in currentEntitlements) {
      try {
        final verified = await verifyApplePurchase(
          productId: entitlement.productId,
          transactionId: entitlement.transactionId,
          receiptData: entitlement.receiptData,
        );
        lastVerification = verified;
        final status = verified['status']?.toString() ?? '';
        if (verified['verified'] == true &&
            (status == 'active' || status == 'grace')) {
          return <String, dynamic>{
            ...normalizedServerBilling,
            ...verified,
            'status': status,
            'appleEntitlement': 'current',
          };
        }
      } on CommercialAccountException catch (error) {
        // StoreKit can expose transactions that are not owned by the currently
        // authenticated SIGILLUM account. Never grant from those transactions;
        // continue to the account-bound live Apple server reconciliation.
        if (error.code != 'APPLE_SUBSCRIPTION_ALREADY_LINKED') {
          lastVerification = <String, dynamic>{
            'verified': false,
            'status': 'inactive',
            'verificationError': error.code ?? 'APPLE_VERIFY_FAILED',
          };
        }
      }
    }

    try {
      final reconciled = await _authorizedRequest(
        'POST',
        '/api/billing/apple/reconcile',
      );
      final normalizedReconciled = _normalizeServerBilling(reconciled);
      final reconciledStatus = normalizedReconciled['status']?.toString() ?? '';
      if (reconciled['verified'] == true &&
          (reconciledStatus == 'active' || reconciledStatus == 'grace')) {
        return <String, dynamic>{
          ...normalizedServerBilling,
          ...normalizedReconciled,
          'status': reconciledStatus,
          'appleEntitlement': 'server_reconciled',
        };
      }

      return <String, dynamic>{
        ...normalizedServerBilling,
        if (lastVerification != null) ...lastVerification,
        ...normalizedReconciled,
        'status': 'inactive',
        'appleEntitlement': currentEntitlements.isEmpty
            ? 'missing_server_inactive'
            : 'not_verified_server_inactive',
      };
    } on CommercialAccountException catch (error) {
      return <String, dynamic>{
        ...normalizedServerBilling,
        if (lastVerification != null) ...lastVerification,
        'status': 'inactive',
        'appleEntitlement': currentEntitlements.isEmpty
            ? 'missing_reconcile_failed'
            : 'not_verified_reconcile_failed',
        'reconcileError': error.code ?? 'APPLE_RECONCILE_FAILED',
      };
    }
  }

  Map<String, dynamic> _normalizeServerBilling(Map<String, dynamic> billing) {
    final status = billing['status']?.toString() ?? '';
    if (status != 'active') return billing;

    final rawExpiresAt = billing['expiresAt']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(rawExpiresAt)?.toUtc();
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      return <String, dynamic>{...billing, 'status': 'expired'};
    }
    return billing;
  }

  Future<List<_CommercialCurrentAppleEntitlement>>
  _currentAppleEntitlements() async {
    try {
      final raw = await _nativeStoreKit2.invokeMethod<List<Object?>>(
        'currentEntitlements',
      );
      if (raw == null) return const [];

      final resolved = <_CommercialCurrentAppleEntitlement>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final productId = item['productId']?.toString() ?? '';
        final transactionId = item['transactionId']?.toString() ?? '';
        final receiptData = item['receiptData']?.toString() ?? '';
        if (!_appleCreatorProductIds.contains(productId) ||
            transactionId.isEmpty ||
            receiptData.isEmpty) {
          continue;
        }
        resolved.add(
          _CommercialCurrentAppleEntitlement(
            productId: productId,
            transactionId: transactionId,
            receiptData: receiptData,
          ),
        );
      }
      return resolved;
    } on PlatformException catch (error) {
      throw CommercialAccountException(
        'Impossibile verificare l’abbonamento corrente con App Store: ${error.message ?? error.code}',
        code: error.code,
      );
    }
  }

  Future<Map<String, dynamic>> verifyApplePurchase({
    required String productId,
    String? transactionId,
    required String receiptData,
  }) async {
    if (productId.isEmpty) {
      throw const CommercialAccountException('Prodotto App Store non valido.');
    }
    if ((transactionId == null || transactionId.trim().isEmpty) &&
        receiptData.trim().isEmpty) {
      throw const CommercialAccountException(
        'Dati App Store insufficienti per verificare l’acquisto.',
      );
    }

    Map<String, dynamic>? lastResult;
    for (var attempt = 0;
        attempt < _appleVerificationRetryDelays.length;
        attempt++) {
      final delay = _appleVerificationRetryDelays[attempt];
      if (delay != Duration.zero) {
        await Future<void>.delayed(delay);
      }

      try {
        final result = await _authorizedRequest(
          'POST',
          '/api/billing/apple/verify',
          body: {
            'productId': productId,
            if (transactionId != null && transactionId.trim().isNotEmpty)
              'transactionId': transactionId.trim(),
            if (receiptData.trim().isNotEmpty) 'receiptData': receiptData,
          },
        );
        lastResult = result;

        // Apple authenticity and SIGILLUM entitlement activation can settle at
        // slightly different times in TestFlight/Sandbox. Do not stop at the
        // first verified=true response if the backend still reports inactive.
        // Re-submit the same server verification for a bounded window and only
        // return early when the server confirms an active/grace entitlement.
        // This never grants access locally and preserves fail-closed billing.
        final status = result['status']?.toString() ?? '';
        if (result['verified'] == true &&
            (status == 'active' || status == 'grace')) {
          return result;
        }
      } on CommercialAccountException catch (error) {
        final hasMoreAttempts =
            attempt + 1 < _appleVerificationRetryDelays.length;
        if (!hasMoreAttempts || !_isTransientAppleVerificationError(error)) {
          rethrow;
        }
      }
    }

    // A response that is authentic but never becomes active/grace in the
    // bounded propagation window stays inactive. The gate will not grant
    // Creator access; this also exposes a genuine backend product-mapping error
    // instead of hiding it with a local entitlement.
    return lastResult ??
        const <String, dynamic>{
          'verified': false,
          'status': 'inactive',
        };
  }

  static bool _isTransientAppleVerificationError(
    CommercialAccountException error,
  ) {
    // Ownership conflicts are deliberate and terminal. Retrying them only
    // delays StoreKit queue cleanup and can make a fresh purchase look stuck.
    if (error.code == 'APPLE_SUBSCRIPTION_ALREADY_LINKED') return false;

    final status = error.statusCode;
    if (status == null) return false;
    return status == 408 ||
        status == 409 ||
        status == 425 ||
        status == 429 ||
        status >= 500;
  }

  Future<void> logout() => _auth.logout();

  Future<String> _token() async {
    final token = await HCVSecureStore.read(_sessionTokenKey);
    if (token == null || token.isEmpty) {
      throw const CommercialAccountException(
        'Accedi per continuare.',
        statusCode: 401,
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _request(method, path, token: await _token(), body: body);
  }

  Future<Map<String, dynamic>> _deviceProof() async {
    final identity = await HCVIdentity().loadIdentity();
    final fingerprint =
        identity['devicePublicKeyFingerprint']?.toString() ?? '';
    final rawPublicKey = identity['publicKey'];
    if (fingerprint.isEmpty ||
        fingerprint == 'UNAVAILABLE' ||
        rawPublicKey is! Map) {
      throw const CommercialAccountException(
        'Chiave sicura del dispositivo non disponibile.',
      );
    }
    final publicKey = Map<String, dynamic>.from(rawPublicKey);
    final signedAt = DateTime.now().toUtc().toIso8601String();
    final statement = jsonEncode({
      'purpose': 'SIGILLUM_AUTH_DEVICE_BINDING_V1',
      'deviceKeyFingerprint': fingerprint,
      'signedAt': signedAt,
    });
    return {
      'creatorId': identity['creatorId']?.toString() ?? '',
      'deviceKeyFingerprint': fingerprint,
      'publicKey': publicKey,
      'signedAt': signedAt,
      'signature': await HCVKeystoreSigner.sign(statement),
    };
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    final client = HttpClient()..connectionTimeout = effectiveTimeout;
    try {
      final uri = Uri.parse('$baseUrl$path');
      late HttpClientRequest request;
      if (method == 'GET') {
        request = await client.getUrl(uri).timeout(effectiveTimeout);
      } else {
        request = await client.postUrl(uri).timeout(effectiveTimeout);
      }
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(effectiveTimeout);
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(effectiveTimeout);
      Map<String, dynamic> decoded = const {};
      try {
        final parsed = jsonDecode(raw.isEmpty ? '{}' : raw);
        if (parsed is Map) decoded = Map<String, dynamic>.from(parsed);
      } catch (_) {}
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CommercialAccountException(
          decoded['message']?.toString().isNotEmpty == true
              ? decoded['message'].toString()
              : decoded['error']?.toString().isNotEmpty == true
              ? decoded['error'].toString()
              : 'Operazione non disponibile.',
          statusCode: response.statusCode,
          code: decoded['error']?.toString(),
        );
      }
      return decoded;
    } on CommercialAccountException {
      rethrow;
    } on TimeoutException {
      throw const CommercialAccountException(
        'Tempo di risposta del server scaduto.',
      );
    } on SocketException catch (error) {
      throw CommercialAccountException(
        'Registry non raggiungibile: ${error.message}',
      );
    } on HandshakeException {
      throw const CommercialAccountException(
        'Connessione sicura non disponibile.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
