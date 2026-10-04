import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_service.dart';
import 'hcv_keystore_signer.dart';
import 'hcv_secure_media_vault.dart';
import 'hcv_secure_store.dart';
import 'verified_originals_reference.dart';

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

class VerifiedSubtitlePublishResult {
  const VerifiedSubtitlePublishResult({
    required this.hcvId,
    required this.alreadyAvailable,
    required this.publicationId,
    required this.publicUrl,
    required this.referenceSha256,
    required this.captionedMediaSha256,
    required this.subtitleSha256,
  });

  final String hcvId;
  final bool alreadyAvailable;
  final String publicationId;
  final String? publicUrl;
  final String referenceSha256;
  final String captionedMediaSha256;
  final String subtitleSha256;
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

  Future<Map<String, dynamic>> verificationReference(String hcvId) {
    return _json(
      'GET',
      '/api/verified-originals/$hcvId/verification-reference',
    );
  }

  bool _isLiveReference(Map<String, dynamic> live) {
    return live['availability'] == 'REFERENCE_AVAILABLE' &&
        (live['referenceLive'] == true || live['youtubeLive'] == true);
  }

  bool _providerLocatorValid(
    Map<String, dynamic> response, {
    required String publicUrl,
  }) {
    final platform = response['platform']?.toString() ?? '';
    if (platform == 'youtube') return publicUrl.isNotEmpty;
    if (platform == 'r2') {
      return response['referenceAccess'] == 'SHORT_LIVED_AUTHORIZATION' &&
          publicUrl.isEmpty;
    }
    return false;
  }

  Future<Map<String, dynamic>> entitledLiveReference(String hcvId) async {
    // Ask the authenticated endpoint first so subscription errors take
    // precedence over reference availability. This prevents an expired
    // subscription from being misreported as a provider/publication problem.
    final entitled = await _json(
      'GET',
      '/api/verified-originals/$hcvId/view',
      authenticated: true,
    );

    final live = await verificationReference(hcvId);
    if (!_isLiveReference(live)) {
      throw StateError('REFERENCE_PLATFORM_UNAVAILABLE');
    }

    return entitled;
  }

  Future<String> _ensureConsent(
    HCVSecureOriginalRecord record,
  ) async {
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
        'monetizationConsent': false,
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
        !_providerLocatorValid(reference, publicUrl: publicUrl) ||
        originalContentSha256 != record.mediaSha256 ||
        serverHcvpackSha256 != record.hcvpackSha256 ||
        derivedFrom != record.mediaSha256 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(referenceSha256)) {
      throw StateError('REFERENCE_EXISTING_RECORD_INVALID');
    }

    await vault.markReference(
      hcvId: record.hcvId,
      publicationId: publicationId,
      referenceUrl: publicUrl.isEmpty ? null : publicUrl,
      referenceSha256: referenceSha256,
    );

    return VerifiedOriginalPublishResult(
      hcvId: record.hcvId,
      alreadyAvailable: true,
      publicationId: publicationId,
      publicUrl: publicUrl.isEmpty ? null : publicUrl,
      referenceSha256: referenceSha256,
    );
  }

  Future<VerifiedOriginalPublishResult> ensureReference(
    HCVSecureOriginalRecord record,
  ) async {
    final availability = await publicAvailability(record.hcvId);
    if (availability['availability'] == 'REFERENCE_AVAILABLE') {
      final live = await verificationReference(record.hcvId);
      final liveAvailable = _isLiveReference(live);
      if (!liveAvailable) {
        throw StateError('REFERENCE_PLATFORM_UNAVAILABLE');
      }
      return _existingReference(record);
    }

    final consentId = await _ensureConsent(record);

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
          'monetizationEnabled': 'false',
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
            !_providerLocatorValid(decoded, publicUrl: publicUrl) ||
            originalContentSha256 != record.mediaSha256 ||
            serverHcvpackSha256 != record.hcvpackSha256 ||
            derivedFrom != record.mediaSha256 ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(referenceSha256)) {
          throw StateError('REFERENCE_PUBLICATION_RESPONSE_INVALID');
        }

        await vault.markReference(
          hcvId: record.hcvId,
          publicationId: publicationId,
          referenceUrl: publicUrl.isEmpty ? null : publicUrl,
          referenceSha256: referenceSha256,
        );

        return VerifiedOriginalPublishResult(
          hcvId: record.hcvId,
          alreadyAvailable: false,
          publicationId: publicationId,
          publicUrl: publicUrl.isEmpty ? null : publicUrl,
          referenceSha256: referenceSha256,
        );
      } finally {
        client.close(force: true);
      }
    } finally {
      await vault.deleteMaterialized(materialized);
    }
  }

  Future<VerifiedSubtitlePublishResult> ensureSubtitleReference(
    HCVSecureOriginalRecord record,
  ) async {
    if (record.mediaType != 'video' ||
        !record.hasSubtitleDerivative ||
        record.captionedMediaSha256 == null ||
        record.captionedMediaSize == null ||
        record.subtitleSha256 == null) {
      throw StateError('SUBTITLE_DERIVATION_NOT_READY');
    }

    await ensureReference(record);

    final refreshed = await vault.find(record.hcvId) ?? record;
    final consentId = await _ensureConsent(refreshed);
    final captioned = await vault.materializeCaptionedVideo(
      refreshed,
      purpose: 'subtitle-publish',
    );

    try {
      if (await captioned.length() != refreshed.captionedMediaSize) {
        throw StateError('SUBTITLE_DERIVATION_SIZE_MISMATCH');
      }

      final captionedSha256 = refreshed.captionedMediaSha256!;
      final subtitleSha256 = refreshed.subtitleSha256!;
      final binding = [
        'SIGILLUM_SUBTITLE_DERIVATION_BINDING_V1',
        refreshed.hcvId,
        refreshed.mediaSha256,
        captionedSha256,
        subtitleSha256,
        refreshed.hcvpackSha256,
      ].join('|');

      final token = await _sessionToken();
      final uri = Uri.parse(
        '$_base/api/verified-originals/publish-subtitle/${refreshed.hcvId}',
      ).replace(
        queryParameters: {
          'consentRecordId': consentId,
          'monetizationEnabled': 'false',
          'hcvpackSha256': refreshed.hcvpackSha256,
          'subtitleSha256': subtitleSha256,
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
        request.headers.contentType = ContentType('video', 'mp4');
        request.headers.set(
          'X-Sigillum-Captioned-Sha256',
          captionedSha256,
        );
        request.headers.set(
          'X-Sigillum-Subtitle-Binding-Version',
          '1',
        );
        request.headers.set(
          'X-Sigillum-Subtitle-Derivation-Signature',
          await HCVKeystoreSigner.sign(binding),
        );
        request.contentLength = refreshed.captionedMediaSize!;
        await request.addStream(captioned.openRead());

        final response =
            await request.close().timeout(const Duration(minutes: 15));
        final raw = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(minutes: 2));
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

        final publicationId = decoded['publicationId']?.toString() ?? '';
        final publicUrl = decoded['publicUrl']?.toString() ?? '';
        final referenceSha256 =
            decoded['referenceSha256']?.toString().toLowerCase() ?? '';
        final sourceSha256 =
            decoded['sourceDerivationSha256']?.toString().toLowerCase() ?? '';
        final serverSubtitleSha256 =
            decoded['subtitleSha256']?.toString().toLowerCase() ?? '';
        final originalContentSha256 =
            decoded['originalContentSha256']?.toString().toLowerCase() ?? '';
        final serverHcvpackSha256 =
            decoded['hcvpackSha256']?.toString().toLowerCase() ?? '';
        final role = decoded['referenceRole']?.toString() ?? '';
        final derivationType = decoded['derivationType']?.toString() ?? '';

        if (publicationId.isEmpty ||
            !_providerLocatorValid(decoded, publicUrl: publicUrl) ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(referenceSha256) ||
            sourceSha256 != captionedSha256 ||
            serverSubtitleSha256 != subtitleSha256 ||
            originalContentSha256 != refreshed.mediaSha256 ||
            serverHcvpackSha256 != refreshed.hcvpackSha256 ||
            role != 'DERIVED_REFERENCE' ||
            derivationType != 'subtitle_burn_in_reference_v1') {
          throw StateError('SUBTITLE_REFERENCE_RESPONSE_INVALID');
        }

        await vault.markSubtitleReference(
          hcvId: refreshed.hcvId,
          publicationId: publicationId,
          referenceUrl: publicUrl.isEmpty ? null : publicUrl,
          referenceSha256: referenceSha256,
          captionedMediaSha256: captionedSha256,
          subtitleSha256: subtitleSha256,
        );

        return VerifiedSubtitlePublishResult(
          hcvId: refreshed.hcvId,
          alreadyAvailable: decoded['alreadyAvailable'] == true,
          publicationId: publicationId,
          publicUrl: publicUrl.isEmpty ? null : publicUrl,
          referenceSha256: referenceSha256,
          captionedMediaSha256: captionedSha256,
          subtitleSha256: subtitleSha256,
        );
      } finally {
        client.close(force: true);
      }
    } finally {
      await vault.deleteMaterialized(captioned);
    }
  }

  Future<File> materializeEntitledReference(String hcvId) async {
    final view = await entitledLiveReference(hcvId);
    final reference = VerifiedOriginalsReference.fromRegistry(
      view,
      requestedHcvId: hcvId,
    );
    if (reference == null) {
      throw StateError('REFERENCE_RESPONSE_INVALID');
    }
    if (!reference.isPrivateR2) {
      throw StateError('REFERENCE_EXTERNAL_URL_ONLY');
    }

    final authorization = await _json(
      'POST',
      '/api/verified-originals/$hcvId/read-authorization',
      authenticated: true,
    );
    final readPath = authorization['readPath']?.toString() ?? '';
    if (!readPath.startsWith('/api/verified-originals/reference-read/') ||
        readPath.contains('..') ||
        readPath.contains('://')) {
      throw StateError('REFERENCE_READ_AUTH_INVALID');
    }

    final token = await _sessionToken();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    File? target;
    try {
      final request = await client
          .getUrl(Uri.parse('$_base$readPath'))
          .timeout(const Duration(seconds: 20));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $token',
      );
      final response = await request.close().timeout(
            const Duration(minutes: 2),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final raw = await utf8.decoder.bind(response).join();
        String code = 'HTTP_${response.statusCode}';
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            code = decoded['error']?.toString() ?? code;
          }
        } catch (_) {}
        throw StateError(code);
      }

      final mime = response.headers.contentType?.mimeType ?? '';
      final extension = mime == 'video/mp4'
          ? '.mp4'
          : mime == 'image/png'
              ? '.png'
              : mime == 'image/jpeg'
                  ? '.jpg'
                  : '';
      if (extension.isEmpty) {
        throw StateError('REFERENCE_MEDIA_TYPE_UNSUPPORTED');
      }

      final root = await getTemporaryDirectory();
      final directory = Directory(
        p.join(root.path, 'sigillum_reference_reads'),
      );
      await directory.create(recursive: true);
      target = File(
        p.join(
          directory.path,
          '${hcvId}_${DateTime.now().microsecondsSinceEpoch}$extension',
        ),
      );
      final sink = target.openWrite(mode: FileMode.writeOnly);
      try {
        await response.pipe(sink);
      } finally {
        await sink.close();
      }

      final digest = await sha256.bind(target.openRead()).first;
      if (digest.toString().toLowerCase() !=
          reference.referenceSha256.toLowerCase()) {
        throw StateError('REFERENCE_DOWNLOADED_SHA256_MISMATCH');
      }
      return target;
    } catch (_) {
      if (target != null) {
        try {
          if (await target.exists()) await target.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close(force: true);
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
