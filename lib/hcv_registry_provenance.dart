import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

enum HCVRegistryProvenanceState {
  verifiedV2,
  legacy,
  notFound,
  unavailable,
  invalid,
}

class HCVRegistryProvenanceCheck {
  const HCVRegistryProvenanceCheck({
    required this.state,
    required this.message,
    this.provenance,
  });

  final HCVRegistryProvenanceState state;
  final String message;
  final Map<String, dynamic>? provenance;

  bool get registryVerifiedV2 =>
      state == HCVRegistryProvenanceState.verifiedV2;
}

class HCVRegistryProvenanceVerifier {
  static const _requestTimeout = Duration(seconds: 15);
  static const _legacyReadBaseUrl = 'https://hcv-registry-server.onrender.com';
  static final _hcvIdPattern = RegExp(r'^HCV-[A-F0-9]{16}$');
  static final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

  const HCVRegistryProvenanceVerifier({
    this.baseUrl = const String.fromEnvironment(
      'SIGILLUM_API_BASE_URL',
      defaultValue: 'https://sigillum-registry-production.onrender.com',
    ),
  });

  final String baseUrl;

  Future<HCVRegistryProvenanceCheck> verify({
    required String hcvId,
    required String certificateRaw,
    required String contentSha256,
    required String creatorId,
    required String deviceKeyFingerprint,
  }) async {
    final cleanedId = hcvId.trim().toUpperCase();
    final cleanedContentHash = contentSha256.trim().toLowerCase();
    final cleanedCreatorId = creatorId.trim();
    final cleanedDeviceFingerprint = deviceKeyFingerprint.trim().toLowerCase();

    if (!_hcvIdPattern.hasMatch(cleanedId) ||
        !_sha256Pattern.hasMatch(cleanedContentHash) ||
        cleanedCreatorId.isEmpty ||
        !_sha256Pattern.hasMatch(cleanedDeviceFingerprint)) {
      return const HCVRegistryProvenanceCheck(
        state: HCVRegistryProvenanceState.invalid,
        message: 'Dati di provenienza locali incompleti o non validi.',
      );
    }

    final primary = await _verifyFromBase(
      registryBase: baseUrl,
      hcvId: cleanedId,
      certificateRaw: certificateRaw,
      contentSha256: cleanedContentHash,
      creatorId: cleanedCreatorId,
      deviceKeyFingerprint: cleanedDeviceFingerprint,
    );

    if (primary.state != HCVRegistryProvenanceState.notFound ||
        baseUrl == _legacyReadBaseUrl) {
      return primary;
    }

    final legacy = await _verifyFromBase(
      registryBase: _legacyReadBaseUrl,
      hcvId: cleanedId,
      certificateRaw: certificateRaw,
      contentSha256: cleanedContentHash,
      creatorId: cleanedCreatorId,
      deviceKeyFingerprint: cleanedDeviceFingerprint,
    );

    if (legacy.state == HCVRegistryProvenanceState.notFound) {
      return primary;
    }
    return legacy;
  }

  Future<HCVRegistryProvenanceCheck> _verifyFromBase({
    required String registryBase,
    required String hcvId,
    required String certificateRaw,
    required String contentSha256,
    required String creatorId,
    required String deviceKeyFingerprint,
  }) async {
    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final request = await client
          .getUrl(Uri.parse('$registryBase/api/certificate/$hcvId'))
          .timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_requestTimeout);

      if (response.statusCode == 404) {
        return const HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.notFound,
          message: 'Certificato non presente nel Registry.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return HCVRegistryProvenanceCheck(
          state: response.statusCode >= 500
              ? HCVRegistryProvenanceState.unavailable
              : HCVRegistryProvenanceState.invalid,
          message: 'Registry HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.invalid,
          message: 'Risposta Registry non valida.',
        );
      }

      final registryRaw = decoded['certificateRaw'];
      if (registryRaw is! String || registryRaw.isEmpty) {
        return const HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.invalid,
          message: 'Certificato assente dalla risposta Registry.',
        );
      }

      final localCertificateSha256 =
          sha256.convert(utf8.encode(certificateRaw)).toString();
      final registryCertificateSha256 =
          sha256.convert(utf8.encode(registryRaw)).toString();
      if (registryCertificateSha256 != localCertificateSha256) {
        return const HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.invalid,
          message:
              'Il certificato locale non coincide byte-per-byte con quello registrato.',
        );
      }

      final registryCertificate = jsonDecode(registryRaw);
      if (registryCertificate is! Map<String, dynamic>) {
        return const HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.invalid,
          message: 'Certificato Registry non leggibile.',
        );
      }

      final meta = registryCertificate['meta'];
      final identity = meta is Map ? meta['identity'] : null;
      final registeredHcvId =
          meta is Map ? meta['hcvId']?.toString().trim().toUpperCase() : null;
      final registeredContent = registryCertificate['content'];
      final registeredContentSha256 = registeredContent is Map
          ? registeredContent['hash']?.toString().trim().toLowerCase()
          : null;
      final registeredCreatorId = identity is Map
          ? identity['creatorId']?.toString().trim()
          : null;
      final registeredDeviceFingerprint = identity is Map
          ? identity['devicePublicKeyFingerprint']
              ?.toString()
              .trim()
              .toLowerCase()
          : null;

      if (registeredHcvId != hcvId ||
          registeredContentSha256 != contentSha256 ||
          registeredCreatorId != creatorId ||
          registeredDeviceFingerprint != deviceKeyFingerprint) {
        return const HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.invalid,
          message:
              'Il certificato Registry non coincide con contenuto, creator o dispositivo locali.',
        );
      }

      final provenanceRaw = decoded['provenance'];
      if (provenanceRaw is! Map) {
        return const HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.legacy,
          message:
              'Firma e certificato presenti nel Registry, ma senza attestazione di provenienza v2.',
        );
      }
      final provenance = Map<String, dynamic>.from(provenanceRaw);
      final status = provenance['status']?.toString();
      final version = (provenance['version'] as num?)?.toInt() ?? 0;
      if (status == 'LEGACY_REGISTRY_RECORD' || version < 2) {
        return HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.legacy,
          message:
              'Record Registry legacy: integrità HCV disponibile, provenance v2 assente.',
          provenance: provenance,
        );
      }

      if (status != 'SIGILLUM_REGISTRY_VERIFIED' ||
          provenance['integrityValid'] != true ||
          provenance['identityVerified'] != true) {
        return HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.invalid,
          message: 'Attestazione Registry v2 non valida.',
          provenance: provenance,
        );
      }

      final provenanceHcvId =
          provenance['hcvId']?.toString().trim().toUpperCase();
      final provenanceCertificateSha256 = provenance['certificateSha256']
          ?.toString()
          .trim()
          .toLowerCase();
      final provenanceContentSha256 =
          provenance['contentSha256']?.toString().trim().toLowerCase();
      final provenanceAccountHash =
          provenance['accountSubjectHash']?.toString().trim().toLowerCase();
      final provenanceCreatorId = provenance['creatorId']?.toString().trim();
      final provenanceDeviceFingerprint = provenance['deviceKeyFingerprint']
          ?.toString()
          .trim()
          .toLowerCase();
      final registeredAt = _normalizeIso(provenance['registeredAt']);
      final bindingVersion =
          (provenance['bindingVersion'] as num?)?.toInt() ?? 0;
      final attestationSha256 = provenance['attestationSha256']
          ?.toString()
          .trim()
          .toLowerCase();

      if (provenanceHcvId != hcvId ||
          provenanceCertificateSha256 != localCertificateSha256 ||
          provenanceContentSha256 != contentSha256 ||
          !_sha256Pattern.hasMatch(provenanceAccountHash ?? '') ||
          provenanceCreatorId != creatorId ||
          provenanceDeviceFingerprint != deviceKeyFingerprint ||
          registeredAt == null ||
          bindingVersion < 1 ||
          !_sha256Pattern.hasMatch(attestationSha256 ?? '')) {
        return HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.invalid,
          message: 'Campi dell’attestazione Registry v2 non coerenti.',
          provenance: provenance,
        );
      }

      final canonical = <String, dynamic>{
        'type': 'SIGILLUM_REGISTRY_PROVENANCE',
        'version': 2,
        'hcvId': hcvId,
        'certificateSha256': localCertificateSha256,
        'contentSha256': contentSha256,
        'accountSubjectHash': provenanceAccountHash,
        'creatorId': creatorId,
        'deviceKeyFingerprint': deviceKeyFingerprint,
        'identityVerified': true,
        'registeredAt': registeredAt,
        'bindingVersion': bindingVersion,
      };
      final expectedAttestationSha256 =
          sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
      if (expectedAttestationSha256 != attestationSha256) {
        return HCVRegistryProvenanceCheck(
          state: HCVRegistryProvenanceState.invalid,
          message: 'Digest dell’attestazione Registry v2 non valido.',
          provenance: provenance,
        );
      }

      return HCVRegistryProvenanceCheck(
        state: HCVRegistryProvenanceState.verifiedV2,
        message:
            'Integrità HCV e provenienza Registry v2 verificate sullo stesso certificato.',
        provenance: provenance,
      );
    } on SocketException catch (error) {
      return HCVRegistryProvenanceCheck(
        state: HCVRegistryProvenanceState.unavailable,
        message: 'Registry non raggiungibile: ${error.message}',
      );
    } on HandshakeException catch (error) {
      return HCVRegistryProvenanceCheck(
        state: HCVRegistryProvenanceState.unavailable,
        message: 'Connessione sicura al Registry non disponibile: $error',
      );
    } on TimeoutException {
      return const HCVRegistryProvenanceCheck(
        state: HCVRegistryProvenanceState.unavailable,
        message: 'Tempo di risposta del Registry scaduto.',
      );
    } catch (error) {
      return HCVRegistryProvenanceCheck(
        state: HCVRegistryProvenanceState.invalid,
        message: 'Errore verifica provenance: $error',
      );
    } finally {
      client.close(force: true);
    }
  }

  String? _normalizeIso(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toUtc().toIso8601String();
    } catch (_) {
      return null;
    }
  }
}
