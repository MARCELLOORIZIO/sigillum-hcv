import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hcv_identity.dart';
import 'hcv_keystore_signer.dart';
import 'hcv_secure_store.dart';

class HCVAuthException implements Exception {
  const HCVAuthException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class HCVAuthService {
  const HCVAuthService({
    this.baseUrl = const String.fromEnvironment(
      'SIGILLUM_API_BASE_URL',
      defaultValue: 'https://hcv-registry-server.onrender.com',
    ),
  });

  static const String _sessionTokenKey = 'sigillum.auth.session.v1';
  static const String _authProofPurpose =
      'SIGILLUM_AUTH_DEVICE_BINDING_V1';
  static const Duration _timeout = Duration(seconds: 20);

  final String baseUrl;

  Future<bool> hasStoredSession() async {
    final token = await HCVSecureStore.read(_sessionTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>?> restoreSession() async {
    final token = await HCVSecureStore.read(_sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _request(
        'GET',
        '/api/auth/session',
        token: token,
      );
      return _accountEnvelope(response);
    } on HCVAuthException catch (error) {
      if (error.statusCode == 401) {
        await HCVSecureStore.delete(_sessionTokenKey);
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String creatorName,
  }) async {
    final proof = await _createDeviceProof();
    final response = await _request(
      'POST',
      '/api/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'creatorName': creatorName.trim(),
        'creatorId': proof.remove('creatorId'),
        ...proof,
      },
    );
    await _storeReturnedToken(response);
    return _accountEnvelope(response);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final proof = await _createDeviceProof();
    final response = await _request(
      'POST',
      '/api/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
        ...proof,
      },
    );
    await _storeReturnedToken(response);
    return _accountEnvelope(response);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String creatorName,
  }) async {
    final token = await _requiredToken();
    final response = await _request(
      'POST',
      '/api/auth/profile',
      token: token,
      body: {'creatorName': creatorName.trim()},
    );
    return _accountEnvelope(response);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await _requiredToken();
    await _request(
      'POST',
      '/api/auth/password',
      token: token,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final token = await _requiredToken();
    final response = await _request(
      'GET',
      '/api/auth/devices',
      token: token,
    );
    final raw = response['devices'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> logout() async {
    final token = await HCVSecureStore.read(_sessionTokenKey);
    try {
      if (token != null && token.isNotEmpty) {
        await _request('POST', '/api/auth/logout', token: token);
      }
    } finally {
      await HCVSecureStore.delete(_sessionTokenKey);
    }
  }

  Future<void> logoutAll() async {
    final token = await _requiredToken();
    try {
      await _request('POST', '/api/auth/logout-all', token: token);
    } finally {
      await HCVSecureStore.delete(_sessionTokenKey);
    }
  }

  Future<void> deleteAccount({
    required String password,
  }) async {
    final token = await _requiredToken();
    await _request(
      'POST',
      '/api/auth/delete',
      token: token,
      body: {
        'password': password,
        'confirmation': 'DELETE',
      },
    );
    await HCVSecureStore.delete(_sessionTokenKey);
  }

  Future<String> _requiredToken() async {
    final token = await HCVSecureStore.read(_sessionTokenKey);
    if (token == null || token.isEmpty) {
      throw const HCVAuthException(
        'Nessuna sessione attiva',
        statusCode: 401,
        code: 'SESSIONE_MANCANTE',
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> _createDeviceProof() async {
    final identity = await HCVIdentity().loadIdentity();
    final fingerprint =
        identity['devicePublicKeyFingerprint']?.toString() ?? '';
    final rawPublicKey = identity['publicKey'];

    if (fingerprint.isEmpty ||
        fingerprint == 'UNAVAILABLE' ||
        rawPublicKey is! Map) {
      throw const HCVAuthException('Chiave dispositivo non disponibile');
    }

    final publicKey = Map<String, dynamic>.from(rawPublicKey);
    final signedAt = DateTime.now().toUtc().toIso8601String();
    final statement = jsonEncode({
      'purpose': _authProofPurpose,
      'deviceKeyFingerprint': fingerprint,
      'signedAt': signedAt,
    });
    final signature = await HCVKeystoreSigner.sign(statement);

    return {
      'creatorId': identity['creatorId']?.toString() ?? '',
      'deviceKeyFingerprint': fingerprint,
      'publicKey': publicKey,
      'signedAt': signedAt,
      'signature': signature,
    };
  }

  Future<void> _storeReturnedToken(Map<String, dynamic> response) async {
    final token = response['token']?.toString() ?? '';
    if (token.isEmpty) return;
    await HCVSecureStore.write(_sessionTokenKey, token);
  }

  Map<String, dynamic> _accountEnvelope(Map<String, dynamic> response) {
    final raw = response['account'];
    final account = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return {
      'ok': response['ok'] == true,
      'expiresAt': response['expiresAt'],
      'account': account,
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
        throw HCVAuthException(
          decoded['message']?.toString().isNotEmpty == true
              ? decoded['message'].toString()
              : decoded['error']?.toString().isNotEmpty == true
                  ? decoded['error'].toString()
                  : 'Operazione account non riuscita',
          statusCode: response.statusCode,
          code: decoded['error']?.toString(),
        );
      }
      return decoded;
    } on HCVAuthException {
      rethrow;
    } on TimeoutException {
      throw const HCVAuthException('Tempo di risposta del server scaduto');
    } on SocketException catch (error) {
      throw HCVAuthException('Server non raggiungibile: ${error.message}');
    } on HandshakeException {
      throw const HCVAuthException('Connessione sicura non disponibile');
    } finally {
      client.close(force: true);
    }
  }
}
