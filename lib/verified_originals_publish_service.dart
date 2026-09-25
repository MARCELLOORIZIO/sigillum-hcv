import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hcv_registry_service.dart';
import 'hcv_keystore_signer.dart';
import 'hcv_secure_media_vault.dart';
import 'hcv_secure_store.dart';

class VerifiedOriginalPublishResult {
  const VerifiedOriginalPublishResult({
    required this.hcvId,
    required this.alreadyAvailable,
    this.publicationId,
    this.publicUrl,
    this.referenceSha256,
  });

  final String hcvId;
  final bool alreadyAvailable;
  final String? publicationId;
  final String? publicUrl;
  final String? referenceSha256;
}

class VerifiedOriginalsPublishService {
  const VerifiedOriginalsPublishService({
    this.registry = const HCVRegistryService(),
    this.vault = const HCVSecureMediaVault(),
  });

  final HCVRegistryService registry;
  final HCVSecureMediaVault vault;

  Future<String> _sessionToken() async {
    final token = await HCVSecureStore.read('sigillum.auth.session.v1');
    if (token == null || token.isEmpty) {
      throw StateError('CREATOR_SESSION_REQUIRED');
    }
    return token;
  }

  String get _base {
    final value = registry.baseUrl;
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    bool authenticated = false,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .openUrl(method, Uri.parse('$_base$path'))
          .timeout(timeout);
      if (authenticated) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${await _sessionToken()}',
        );
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(timeout);
      final raw = await utf8.decoder.bind(response).join().timeout(timeout);
      final decoded =
          raw.trim().isEmpty ? <String, dynamic>{} : jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('REGISTRY_RESPONSE_INVALID');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          decoded['error']?.toString() ?? 'HTTP_${response.statusCode}',
        );
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> publicAvailability(String hcvId) {
    return _json('GET', '/api/verified-originals/$hcvId');
  }

  Future<String> _ensureConsent(
    HCVSecureOriginalRecord record, {
    required bool monetizationConsent,
  }) async {
    final status = await _json(
      'GET',
      '/api/verified-originals/consents/${record.hcvId}',
      authenticated: true,
    );

    if (status['consentState'] == 'ACTIVE') {
      final existing = status['recordId']?.toString() ?? '';
      if (existing.isNotEmpty) return existing;
    }

    final created = await _json(
      'POST',
      '/api/verified-originals/consents',
      authenticated: true,
      body: {
        'hcvId': record.hcvId,
        'intent': 'PUBLISH_VERIFIED_ORIGINAL',
        'publishReference': true,
        'rightsConfirmed': true,
        'monetizationConsent': monetizationConsent,
      },
    );

    final id = created['recordId']?.toString() ?? '';
    if (id.isEmpty) throw StateError('CONSENT_RECORD_MISSING');
    return id;
  }

  Future<VerifiedOriginalPublishResult> _existingReference(
    HCVSecureOriginalRecord record,
  ) async {
    final reference = await _json(
      'GET',
      '/api/verified-originals/${record.hcvId}/view',
      authenticated: true,
    );

    final publicationId = reference['publicationId']?.toString() ?? '';
    final publicUrl = reference['publicUrl']?.toString() ?? '';
    final referenceSha256 = reference['referenceSha256']?.toString() ?? '';
    final originalContentSha256 =
        reference['originalContentSha256']?.toString().toLowerCase() ?? '';
    final serverHcvpackSha256 =
        reference['hcvpackSha256']?.toString().toLowerCase() ?? '';
    final derivedFrom =
        reference['derivedFrom']?.toString().toLowerCase() ?? '';

    if (publicationId.isEmpty ||
        publicUrl.isEmpty ||
        originalContentSha256 != record.mediaSha256 ||
        serverHcvpackSha256 != record.hcvpackSha256 ||
        derivedFrom != record.mediaSha256 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(referenceSha256)) {
      throw StateError('REFERENCE_EXISTING_RECORD_INVALID');
    }

    await vault.markReference(
      hcvId: record.hcvId,
      publicationId: publicationId,
      referenceUrl: publicUrl,
      referenceSha256: referenceSha256,
    );

    return VerifiedOriginalPublishResult(
      hcvId: record.hcvId,
      alreadyAvailable: true,
      publicationId: publicationId,
      publicUrl: publicUrl,
      referenceSha256: referenceSha256,
    );
  }

  Future<VerifiedOriginalPublishResult> ensureReference(
    HCVSecureOriginalRecord record, {
    bool monetizationConsent = false,
  }) async {
    final availability = await publicAvailability(record.hcvId);
    if (availability['availability'] == 'REFERENCE_AVAILABLE') {
      return _existingReference(record);
    }

    final consentId = await _ensureConsent(
      record,
      monetizationConsent: monetizationConsent,
    );

    final materialized = await vault.materializeOriginal(
      record,
      purpose: 'reference',
    );

    try {
      if (await materialized.length() != record.mediaSize) {
        throw StateError('MATERIALIZED_ORIGINAL_SIZE_MISMATCH');
      }

      final token = await _sessionToken();
      final uri = Uri.parse(
        '$_base/api/verified-originals/publish/${record.hcvId}',
      ).replace(
        queryParameters: {
          'consentRecordId': consentId,
          'monetizationEnabled': monetizationConsent.toString(),
          'hcvpackSha256': record.hcvpackSha256,
        },
      );

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      try {
        final request =
            await client.postUrl(uri).timeout(const Duration(seconds: 20));
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $token',
        );
        request.headers.set(HttpHeaders.contentTypeHeader, _mime(record));
        final packageStatement =
            'SIGILLUM_HCVPACK_BINDING_V1|${record.hcvId}|${record.mediaSha256}|${record.hcvpackSha256}';
        request.headers.set(
          'X-Sigillum-Hcvpack-Signature',
          await HCVKeystoreSigner.sign(packageStatement),
        );
        request.headers.set('X-Sigillum-Hcvpack-Binding-Version', '1');
        request.contentLength = record.mediaSize;
        await request.addStream(materialized.openRead());

        final response =
            await request.close().timeout(const Duration(minutes: 15));
        final raw = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(minutes: 2));
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw StateError('REGISTRY_RESPONSE_INVALID');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            decoded['error']?.toString() ?? 'HTTP_${response.statusCode}',
          );
        }

        final publicationId = decoded['publicationId']?.toString() ?? '';
        final publicUrl = decoded['publicUrl']?.toString() ?? '';
        final referenceSha256 = decoded['referenceSha256']?.toString() ?? '';
        final originalContentSha256 =
            decoded['originalContentSha256']?.toString().toLowerCase() ?? '';
        final serverHcvpackSha256 =
            decoded['hcvpackSha256']?.toString().toLowerCase() ?? '';
        final derivedFrom =
            decoded['derivedFrom']?.toString().toLowerCase() ?? '';

        if (publicationId.isEmpty ||
            publicUrl.isEmpty ||
            originalContentSha256 != record.mediaSha256 ||
            serverHcvpackSha256 != record.hcvpackSha256 ||
            derivedFrom != record.mediaSha256 ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(referenceSha256)) {
          throw StateError('REFERENCE_PUBLICATION_RESPONSE_INVALID');
        }

        await vault.markReference(
          hcvId: record.hcvId,
          publicationId: publicationId,
          referenceUrl: publicUrl,
          referenceSha256: referenceSha256,
        );

        return VerifiedOriginalPublishResult(
          hcvId: record.hcvId,
          alreadyAvailable: false,
          publicationId: publicationId,
          publicUrl: publicUrl,
          referenceSha256: referenceSha256,
        );
      } finally {
        client.close(force: true);
      }
    } finally {
      await vault.deleteMaterialized(materialized);
    }
  }

  Future<void> withdrawReference(HCVSecureOriginalRecord record) async {
    final response = await _json(
      'POST',
      '/api/verified-originals/consents/${record.hcvId}/withdraw',
      authenticated: true,
    );
    if (response['referenceAvailable'] == true) {
      throw StateError('REFERENCE_WITHDRAWAL_INCOMPLETE');
    }
    final takedown = response['platformTakedown']?.toString() ?? '';
    if (takedown != 'COMPLETED') {
      throw StateError('REFERENCE_TAKEDOWN_$takedown');
    }
    await vault.clearReference(record.hcvId);
  }

  String _mime(HCVSecureOriginalRecord record) {
    if (record.mediaType == 'video') return 'video/mp4';
    final lower = record.originalName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}
