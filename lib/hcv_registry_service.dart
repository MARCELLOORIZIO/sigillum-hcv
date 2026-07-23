import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hcv_keystore_signer.dart';
import 'hcv_local_certificate_store.dart';

enum HCVRegistryFailureKind {
  notFound,
  unavailable,
  server,
  conflict,
  invalidCertificate,
  invalidResponse,
}

class HCVRegistryException implements Exception {
  const HCVRegistryException(this.kind, this.message, {this.statusCode});
  final HCVRegistryFailureKind kind;
  final String message;
  final int? statusCode;
  bool get isRetryable =>
      kind == HCVRegistryFailureKind.unavailable ||
      kind == HCVRegistryFailureKind.server;
  @override
  String toString() => message;
}

class HCVRegistryRetryReport {
  const HCVRegistryRetryReport({
    required this.attempted,
    required this.uploaded,
    required this.pending,
    required this.discarded,
    required this.uploadedPaths,
  });
  final int attempted;
  final int uploaded;
  final int pending;
  final int discarded;
  final Set<String> uploadedPaths;
}

class HCVRegistryService {
  static const _pendingUploadsKey = 'hcv_registry_pending_uploads_v2';
  static const _requestTimeout = Duration(seconds: 20);

  final String baseUrl;
  final HCVLocalCertificateStore localStore;

  const HCVRegistryService({
    this.baseUrl = 'https://hcv-registry-server.onrender.com',
    this.localStore = const HCVLocalCertificateStore(),
  });

  Future<Map<String, dynamic>> uploadCertificateFile(String hcvPath) async {
    final localRecord = await localStore.saveCertificateFile(hcvPath);
    final file = File(localRecord.path);
    final rawCertificate = await file.readAsString();
    final parsed = jsonDecode(rawCertificate);
    if (parsed is! Map<String, dynamic>) {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidCertificate,
        'Certificato HCV non valido',
      );
    }
    final hcvId = localStore.extractHcvId(parsed);
    if (hcvId == null || hcvId.isEmpty) {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidCertificate,
        'HCV-ID mancante nel certificato',
      );
    }
    final response = await _requestJson(
      method: 'POST',
      path: '/api/certificate',
      body: {'hcvId': hcvId, 'certificateRaw': rawCertificate},
    );
    final remoteDigest = response['certificateSha256']?.toString() ?? '';
    final localDigest = sha256.convert(utf8.encode(rawCertificate)).toString();
    if (remoteDigest.isEmpty || remoteDigest != localDigest) {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidResponse,
        'Il Registry non ha confermato il digest del certificato',
      );
    }
    await localStore.markRegistryConfirmed(hcvId, confirmed: true);
    return response;
  }

  Future<Map<String, dynamic>> fetchCertificate(String hcvId) async {
    final cleaned = hcvId.trim().toUpperCase();
    if (cleaned.isEmpty) throw Exception('Inserisci HCV-ID');
    try {
      final decoded = await _requestJson(
        method: 'GET',
        path: '/api/certificate/$cleaned',
      );
      final certificateRaw = decoded['certificateRaw'];
      if (certificateRaw is String && certificateRaw.isNotEmpty) {
        final cert = jsonDecode(certificateRaw);
        if (cert is Map<String, dynamic>) {
          cert['_hcvVerificationSource'] = 'REGISTRY';
          return cert;
        }
      }
      final certificate = decoded['certificate'];
      if (certificate is Map) {
        final cert = Map<String, dynamic>.from(certificate);
        cert['_hcvVerificationSource'] = 'REGISTRY';
        return cert;
      }
      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidResponse,
        'Certificato assente nella risposta Registry',
      );
    } on HCVRegistryException catch (error) {
      if (error.kind != HCVRegistryFailureKind.notFound &&
          error.kind != HCVRegistryFailureKind.unavailable &&
          error.kind != HCVRegistryFailureKind.server) {
        rethrow;
      }
      final local = await localStore.loadCertificate(cleaned);
      if (local != null) {
        local['_hcvVerificationSource'] = 'LOCAL_CERTIFICATE';
        return local;
      }
      rethrow;
    }
  }

  Future<void> enqueueCertificateFile(String hcvPath) async {
    final localRecord = await localStore.saveCertificateFile(hcvPath);
    final pending = await _readPendingUploads();
    final existing = pending.indexWhere(
      (item) => item['hcvId']?.toString() == localRecord.hcvId,
    );
    final entry = <String, dynamic>{
      'hcvId': localRecord.hcvId,
      'path': localRecord.path,
      'sha256': localRecord.sha256,
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
      'attempts': existing >= 0
          ? ((pending[existing]['attempts'] as num?)?.toInt() ?? 0)
          : 0,
    };
    if (existing >= 0) {
      pending[existing] = {...pending[existing], ...entry};
    } else {
      pending.add(entry);
    }
    await _writePendingUploads(pending);
  }

  Future<HCVRegistryRetryReport> retryPendingUploads() async {
    final pending = await _readPendingUploads();
    final remaining = <Map<String, dynamic>>[];
    final uploadedPaths = <String>{};
    var attempted = 0;
    var discarded = 0;

    for (final entry in pending) {
      final path = entry['path']?.toString();
      if (path == null || path.isEmpty || !await File(path).exists()) {
        discarded++;
        continue;
      }
      attempted++;
      try {
        await uploadCertificateFile(path);
        uploadedPaths.add(File(path).absolute.path);
      } on HCVRegistryException catch (error) {
        if (error.kind == HCVRegistryFailureKind.invalidCertificate ||
            error.kind == HCVRegistryFailureKind.conflict) {
          discarded++;
          continue;
        }
        remaining.add({
          ...entry,
          'attempts': ((entry['attempts'] as num?)?.toInt() ?? 0) + 1,
          'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
          'lastError': error.message,
        });
      } catch (error) {
        remaining.add({
          ...entry,
          'attempts': ((entry['attempts'] as num?)?.toInt() ?? 0) + 1,
          'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
          'lastError': error.toString(),
        });
      }
    }
    await _writePendingUploads(remaining);
    return HCVRegistryRetryReport(
      attempted: attempted,
      uploaded: uploadedPaths.length,
      pending: remaining.length,
      discarded: discarded,
      uploadedPaths: uploadedPaths,
    );
  }

  Future<Map<String, dynamic>> startKycSession({
    required String creatorId,
    required String creatorName,
    required String deviceKeyFingerprint,
    required Map<String, dynamic> publicKey,
  }) async {
    final proof = await _createDeviceKeyProof(
      deviceKeyFingerprint: deviceKeyFingerprint,
      publicKey: publicKey,
    );
    return _requestJson(
      method: 'POST',
      path: '/api/identity/kyc/start',
      body: {
        'accountId': creatorId,
        'creatorId': creatorId,
        'creatorName': creatorName,
        ...proof,
      },
    );
  }

  Future<Map<String, dynamic>> recoverKycSession({
    required String creatorId,
    required String creatorName,
    required String deviceKeyFingerprint,
    required Map<String, dynamic> publicKey,
  }) async {
    final proof = await _createDeviceKeyProof(
      deviceKeyFingerprint: deviceKeyFingerprint,
      publicKey: publicKey,
    );
    return _requestJson(
      method: 'POST',
      path: '/api/identity/kyc/recover',
      body: {
        'accountId': creatorId,
        'creatorId': creatorId,
        'creatorName': creatorName,
        ...proof,
      },
    );
  }

  Future<Map<String, dynamic>> bindExistingKycSession({
    required String sessionId,
    required String creatorId,
    required String creatorName,
    required String deviceKeyFingerprint,
    required Map<String, dynamic> publicKey,
  }) async {
    final proof = await _createDeviceKeyProof(
      deviceKeyFingerprint: deviceKeyFingerprint,
      publicKey: publicKey,
    );
    return _requestJson(
      method: 'POST',
      path: '/api/identity/kyc/bind',
      body: {
        'sessionId': sessionId.trim(),
        'accountId': creatorId,
        'creatorId': creatorId,
        'creatorName': creatorName,
        ...proof,
      },
    );
  }

  Future<Map<String, dynamic>> fetchKycSessionStatus({
    required String sessionId,
  }) {
    final cleaned = sessionId.trim();
    if (cleaned.isEmpty) throw Exception('Sessione KYC mancante');
    return _requestJson(
      method: 'GET',
      path: '/api/identity/kyc/status',
      query: {'sessionId': cleaned},
    );
  }

  Future<Map<String, dynamic>> _createDeviceKeyProof({
    required String deviceKeyFingerprint,
    required Map<String, dynamic> publicKey,
  }) async {
    final signedAt = DateTime.now().toUtc().toIso8601String();
    final statement = jsonEncode({
      'purpose': 'SIGILLUM_KYC_DEVICE_BINDING_V1',
      'deviceKeyFingerprint': deviceKeyFingerprint,
      'signedAt': signedAt,
    });
    return {
      'deviceKeyFingerprint': deviceKeyFingerprint,
      'publicKey': publicKey,
      'signedAt': signedAt,
      'signature': await HCVKeystoreSigner.sign(statement),
    };
  }

  Future<Map<String, dynamic>> _requestJson({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      var uri = Uri.parse('$baseUrl$path');
      if (query != null) uri = uri.replace(queryParameters: query);
      final request = method == 'POST'
          ? await client.postUrl(uri).timeout(_requestTimeout)
          : await client.getUrl(uri).timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(_requestTimeout);
      final raw = await utf8.decoder.bind(response).join().timeout(_requestTimeout);
      dynamic decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = <String, dynamic>{'error': raw};
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final kind = response.statusCode == 404
            ? HCVRegistryFailureKind.notFound
            : response.statusCode == 409
                ? HCVRegistryFailureKind.conflict
                : response.statusCode >= 500
                    ? HCVRegistryFailureKind.server
                    : HCVRegistryFailureKind.invalidResponse;
        throw HCVRegistryException(
          kind,
          decoded is Map
              ? (decoded['message'] ?? decoded['error'] ?? 'Registry error')
                  .toString()
              : 'Registry error ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      if (decoded is! Map) {
        throw const HCVRegistryException(
          HCVRegistryFailureKind.invalidResponse,
          'Risposta Registry non valida',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on HCVRegistryException {
      rethrow;
    } on TimeoutException {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Tempo di risposta del Registry scaduto',
      );
    } on SocketException catch (error) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Registry non raggiungibile: ${error.message}',
      );
    } on HandshakeException catch (error) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Connessione sicura al Registry non disponibile: $error',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> _readPendingUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingUploadsKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writePendingUploads(List<Map<String, dynamic>> pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingUploadsKey, jsonEncode(pending));
  }
}
