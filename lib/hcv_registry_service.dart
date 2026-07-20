import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

enum HCVRegistryFailureKind {
  notFound,
  unavailable,
  server,
  invalidCertificate,
  invalidResponse,
}

class HCVRegistryException implements Exception {
  const HCVRegistryException(
    this.kind,
    this.message, {
    this.statusCode,
  });

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
  static const _pendingUploadsKey = 'hcv_registry_pending_uploads_v1';
  static const _requestTimeout = Duration(seconds: 15);

  final String baseUrl;

  const HCVRegistryService({
    this.baseUrl = 'https://hcv-registry-server.onrender.com',
  });

  Future<Map<String, dynamic>> uploadCertificateFile(String hcvPath) async {
    final file = File(hcvPath);
    if (!await file.exists()) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.invalidCertificate,
        'File HCV non trovato: $hcvPath',
      );
    }

    late final String rawCertificate;
    late final dynamic parsed;
    try {
      rawCertificate = await file.readAsString();
      parsed = jsonDecode(rawCertificate);
    } catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.invalidCertificate,
        'Certificato HCV illeggibile: $e',
      );
    }

    if (parsed is! Map<String, dynamic>) {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidCertificate,
        'Certificato HCV non valido',
      );
    }

    final hcvId = _extractHcvId(parsed);
    if (hcvId == null || hcvId.isEmpty) {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidCertificate,
        'HCV-ID mancante nel certificato',
      );
    }

    final client = HttpClient()..connectionTimeout = _requestTimeout;

    try {
      final uri = Uri.parse('$baseUrl/api/certificate');
      final req = await client.postUrl(uri).timeout(_requestTimeout);
      req.headers.contentType = ContentType.json;

      req.write(jsonEncode({
        'hcvId': hcvId,
        'certificateRaw': rawCertificate,
      }));

      final res = await req.close().timeout(_requestTimeout);
      final body = await utf8.decoder.bind(res).join().timeout(_requestTimeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HCVRegistryException(
          res.statusCode >= 500
              ? HCVRegistryFailureKind.server
              : HCVRegistryFailureKind.invalidResponse,
          'Registry upload error ${res.statusCode}: $body',
          statusCode: res.statusCode,
        );
      }

      late final dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } catch (e) {
        throw HCVRegistryException(
          HCVRegistryFailureKind.invalidResponse,
          'Risposta registry non valida: $e',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const HCVRegistryException(
          HCVRegistryFailureKind.invalidResponse,
          'Risposta registry non valida',
        );
      }

      return decoded;
    } on HCVRegistryException {
      rethrow;
    } on SocketException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Registry non raggiungibile: ${e.message}',
      );
    } on HandshakeException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Connessione sicura al Registry non disponibile: $e',
      );
    } on TimeoutException {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Tempo di risposta del Registry scaduto',
      );
    } on HttpException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Errore di connessione al Registry: ${e.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> fetchCertificate(String hcvId) async {
    final cleaned = hcvId.trim().toUpperCase();

    if (cleaned.isEmpty) {
      throw Exception('Inserisci HCV-ID');
    }

    final client = HttpClient()..connectionTimeout = _requestTimeout;

    try {
      final uri = Uri.parse('$baseUrl/api/certificate/$cleaned');
      final req = await client.getUrl(uri).timeout(_requestTimeout);
      final res = await req.close().timeout(_requestTimeout);
      final body = await utf8.decoder.bind(res).join().timeout(_requestTimeout);

      if (res.statusCode == 404) {
        throw const HCVRegistryException(
          HCVRegistryFailureKind.notFound,
          'Certificato non trovato nel Registry',
          statusCode: 404,
        );
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HCVRegistryException(
          res.statusCode >= 500
              ? HCVRegistryFailureKind.server
              : HCVRegistryFailureKind.invalidResponse,
          'Registry fetch error ${res.statusCode}: $body',
          statusCode: res.statusCode,
        );
      }

      late final dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } catch (e) {
        throw HCVRegistryException(
          HCVRegistryFailureKind.invalidResponse,
          'Risposta registry non valida: $e',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const HCVRegistryException(
          HCVRegistryFailureKind.invalidResponse,
          'Risposta registry non valida',
        );
      }

      final certificateRaw = decoded['certificateRaw'];
      if (certificateRaw is String && certificateRaw.isNotEmpty) {
        final cert = jsonDecode(certificateRaw);
        if (cert is Map<String, dynamic>) {
          return cert;
        }
      }

      final certificate = decoded['certificate'];
      if (certificate is Map<String, dynamic>) {
        return certificate;
      }

      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidResponse,
        'Certificato assente nella risposta registry',
      );
    } on HCVRegistryException {
      rethrow;
    } on SocketException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Registry non raggiungibile: ${e.message}',
      );
    } on HandshakeException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Connessione sicura al Registry non disponibile: $e',
      );
    } on TimeoutException {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Tempo di risposta del Registry scaduto',
      );
    } on HttpException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Errore di connessione al Registry: ${e.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> enqueueCertificateFile(String hcvPath) async {
    final normalizedPath = File(hcvPath).absolute.path;
    final pending = await _readPendingUploads();
    final existing = pending.indexWhere(
      (item) => item['path']?.toString() == normalizedPath,
    );
    final entry = <String, dynamic>{
      'path': normalizedPath,
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
        uploadedPaths.add(path);
      } on HCVRegistryException catch (e) {
        if (e.kind == HCVRegistryFailureKind.invalidCertificate) {
          discarded++;
          continue;
        }
        remaining.add({
          ...entry,
          'attempts': ((entry['attempts'] as num?)?.toInt() ?? 0) + 1,
          'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
          'lastError': e.message,
        });
      } catch (e) {
        remaining.add({
          ...entry,
          'attempts': ((entry['attempts'] as num?)?.toInt() ?? 0) + 1,
          'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
          'lastError': e.toString(),
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

  Future<void> _writePendingUploads(
    List<Map<String, dynamic>> pending,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingUploadsKey, jsonEncode(pending));
  }

  Future<Map<String, dynamic>> startKycSession({
    required String creatorId,
    required String creatorName,
  }) async {
    final client = HttpClient();

    try {
      final uri = Uri.parse('$baseUrl/api/identity/kyc/start');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'creatorId': creatorId,
        'creatorName': creatorName,
      }));

      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Risposta KYC non valida');
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
            decoded['message'] ?? decoded['error'] ?? 'KYC non disponibile');
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> fetchKycSessionStatus({
    required String sessionId,
  }) async {
    final cleaned = sessionId.trim();
    if (cleaned.isEmpty) {
      throw Exception('Sessione KYC mancante');
    }

    final client = HttpClient();

    try {
      final uri = Uri.parse('$baseUrl/api/identity/kyc/status').replace(
        queryParameters: {'sessionId': cleaned},
      );
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Risposta stato KYC non valida');
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(decoded['message'] ??
            decoded['error'] ??
            'Stato KYC non disponibile');
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  String? extractHcvIdFromCertificate(Map<String, dynamic> cert) {
    return _extractHcvId(cert);
  }

  String? _extractHcvId(Map<String, dynamic> cert) {
    final meta = cert['meta'];

    if (meta is Map && meta['hcvId'] != null) {
      return meta['hcvId'].toString();
    }

    if (cert['hcvId'] != null) {
      return cert['hcvId'].toString();
    }

    return null;
  }
}
