import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hcv_auth_service.dart';
import 'hcv_identity.dart';
import 'hcv_keystore_signer.dart';
import 'hcv_secure_store.dart';

class CommercialAccountException implements Exception {
  const CommercialAccountException(
    this.message, {
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class CommercialAccountService {
  const CommercialAccountService({
    this.baseUrl = const String.fromEnvironment(
      'SIGILLUM_API_BASE_URL',
      defaultValue: 'https://hcv-registry-server.onrender.com',
    ),
  });

  static const _sessionTokenKey = 'sigillum.auth.session.v1';
  static const _timeout = Duration(seconds: 20);
  static const termsVersion = '2026-08-11';
  static const privacyVersion = '2026-08-11';

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
  }) async {
    final proof = await _deviceProof();
    await _request(
      'POST',
      '/api/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'creatorName': creatorName.trim(),
        'creatorId': proof.remove('creatorId'),
        'acceptTerms': acceptTerms,
        'acknowledgePrivacy': acknowledgePrivacy,
        'adultConfirmed': adultConfirmed,
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

  Future<void> resendEmailCode(String email) async {
    await _request(
      'POST',
      '/api/auth/resend-email-code',
      body: {'email': email.trim()},
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _auth.login(email: email, password: password);
  }

  Future<void> forgotPassword(String email) async {
    await _request(
      'POST',
      '/api/auth/password/forgot',
      body: {'email': email.trim()},
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
    return _authorizedRequest('GET', '/api/billing/status');
  }

  Future<Map<String, dynamic>> verifyApplePurchase({
    required String productId,
    String? transactionId,
    required String receiptData,
  }) async {
    if (productId.isEmpty) {
      throw const CommercialAccountException(
        'Prodotto App Store non valido.',
      );
    }
    if ((transactionId == null || transactionId.trim().isEmpty) &&
        receiptData.trim().isEmpty) {
      throw const CommercialAccountException(
        'Dati App Store insufficienti per verificare l’acquisto.',
      );
    }
    return _authorizedRequest(
      'POST',
      '/api/billing/apple/verify',
      body: {
        'productId': productId,
        if (transactionId != null && transactionId.trim().isNotEmpty)
          'transactionId': transactionId.trim(),
        if (receiptData.trim().isNotEmpty) 'receiptData': receiptData,
      },
    );
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
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final uri = Uri.parse('$baseUrl$path');
      late HttpClientRequest request;
      if (method == 'GET') {
        request = await client.getUrl(uri).timeout(_timeout);
      } else {
        request = await client.postUrl(uri).timeout(_timeout);
      }
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $token',
        );
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(_timeout);
      final raw = await utf8.decoder.bind(response).join().timeout(_timeout);
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
