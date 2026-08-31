import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_provenance.dart';
import 'hcv_verifier.dart';
import 'hcvpack_player_page.dart';
import 'sigillum_theme.dart';

class HCVPackProvenanceGatePage extends StatefulWidget {
  const HCVPackProvenanceGatePage({
    super.key,
    required this.path,
    this.languageCode = 'it',
  });

  final String path;
  final String languageCode;

  @override
  State<HCVPackProvenanceGatePage> createState() =>
      _HCVPackProvenanceGatePageState();
}

class _HCVPackProvenanceGatePageState
    extends State<HCVPackProvenanceGatePage> {
  final HCVVerifier _verifier = HCVVerifier();
  final HCVRegistryProvenanceVerifier _registry =
      const HCVRegistryProvenanceVerifier();

  bool _loading = true;
  bool _localIntegrityVerified = false;
  HCVRegistryProvenanceState? _registryState;
  String _title = '';
  String _detail = '';
  String? _hcvId;

  String _localized({
    required String it,
    required String en,
    required String es,
    required String ru,
  }) {
    switch (widget.languageCode) {
      case 'it':
        return it;
      case 'es':
        return es;
      case 'ru':
        return ru;
      default:
        return en;
    }
  }

  @override
  void initState() {
    super.initState();
    _title = _localized(
      it: 'Verifica provenienza',
      en: 'Provenance verification',
      es: 'Verificación de procedencia',
      ru: 'Проверка происхождения',
    );
    _detail = _localized(
      it: 'Controllo integrità HCV e Registry SIGILLUM…',
      en: 'Checking HCV integrity and SIGILLUM Registry…',
      es: 'Comprobando integridad HCV y Registry SIGILLUM…',
      ru: 'Проверка целостности HCV и Registry SIGILLUM…',
    );
    Future.microtask(_verifyAndRoute);
  }

  Future<void> _verifyAndRoute() async {
    try {
      final evidence = await _readAndVerifyLocalPack(widget.path);
      if (!mounted) return;

      setState(() {
        _localIntegrityVerified = true;
        _hcvId = evidence.hcvId;
      });

      final provenance = await _registry.verify(
        hcvId: evidence.hcvId,
        certificateRaw: evidence.certificateRaw,
        contentSha256: evidence.contentSha256,
        creatorId: evidence.creatorId,
        deviceKeyFingerprint: evidence.deviceKeyFingerprint,
      );
      if (!mounted) return;

      if (provenance.registryVerifiedV2) {
        setState(() {
          _loading = false;
          _registryState = provenance.state;
          _title = 'SIGILLUM REGISTRY VERIFIED';
          _detail = provenance.message;
        });

        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HCVPackPlayerPage(
              initialPath: widget.path,
              languageCode: widget.languageCode,
            ),
          ),
        );
        return;
      }

      setState(() {
        _loading = false;
        _registryState = provenance.state;
        if (provenance.state == HCVRegistryProvenanceState.invalid) {
          _title = _localized(
            it: 'PROVENIENZA NON VERIFICATA',
            en: 'PROVENANCE NOT VERIFIED',
            es: 'PROCEDENCIA NO VERIFICADA',
            ru: 'ПРОИСХОЖДЕНИЕ НЕ ПОДТВЕРЖДЕНО',
          );
          _detail = provenance.message;
        } else {
          _title = 'HCV INTEGRITY VERIFIED';
          _detail = _integrityOnlyMessage(provenance);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _localIntegrityVerified = false;
        _registryState = HCVRegistryProvenanceState.invalid;
        _title = _localized(
          it: 'HCV NON VALIDO',
          en: 'INVALID HCV',
          es: 'HCV NO VÁLIDO',
          ru: 'HCV НЕДЕЙСТВИТЕЛЕН',
        );
        _detail = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _integrityOnlyMessage(HCVRegistryProvenanceCheck provenance) {
    switch (provenance.state) {
      case HCVRegistryProvenanceState.legacy:
        return _localized(
          it: 'Firma, certificato e contenuto sono coerenti. Il record Registry è legacy e non contiene l’attestazione di provenienza v2: SIGILLUM non attribuisce questo controllo a un account/dispositivo v2.',
          en: 'Signature, certificate and content are coherent. The Registry record is legacy and has no provenance v2 attestation, so SIGILLUM does not attribute this check to a v2 account/device.',
          es: 'Firma, certificado y contenido son coherentes. El registro es legacy y no contiene la atestación de procedencia v2; SIGILLUM no atribuye esta verificación a una cuenta/dispositivo v2.',
          ru: 'Подпись, сертификат и содержимое согласованы. Запись Registry устаревшая и не содержит аттестации происхождения v2; SIGILLUM не связывает эту проверку с учетной записью/устройством v2.',
        );
      case HCVRegistryProvenanceState.unavailable:
        return _localized(
          it: 'Firma, certificato e contenuto sono coerenti, ma il Registry non è raggiungibile. È verificata solo l’integrità locale; la provenienza SIGILLUM resta da verificare online.',
          en: 'Signature, certificate and content are coherent, but the Registry is unavailable. Only local integrity is verified; SIGILLUM provenance still requires online verification.',
          es: 'Firma, certificado y contenido son coherentes, pero el Registry no está disponible. Solo se verifica la integridad local; la procedencia SIGILLUM requiere verificación online.',
          ru: 'Подпись, сертификат и содержимое согласованы, но Registry недоступен. Подтверждена только локальная целостность; происхождение SIGILLUM требует онлайн-проверки.',
        );
      case HCVRegistryProvenanceState.notFound:
        return _localized(
          it: 'Firma, certificato e contenuto sono coerenti, ma l’HCV-ID non è presente nel Registry. È verificata solo l’integrità locale.',
          en: 'Signature, certificate and content are coherent, but the HCV-ID is not in the Registry. Only local integrity is verified.',
          es: 'Firma, certificado y contenido son coherentes, pero el HCV-ID no está en el Registry. Solo se verifica la integridad local.',
          ru: 'Подпись, сертификат и содержимое согласованы, но HCV-ID отсутствует в Registry. Подтверждена только локальная целостность.',
        );
      default:
        return provenance.message;
    }
  }

  Future<_LocalPackEvidence> _readAndVerifyLocalPack(String packPath) async {
    final file = File(packPath);
    if (!await file.exists()) {
      throw Exception(_localized(
        it: 'HCVPACK non trovato.',
        en: 'HCVPACK not found.',
        es: 'HCVPACK no encontrado.',
        ru: 'HCVPACK не найден.',
      ));
    }

    final bytes = await file.readAsBytes();
    if (_looksLikeZip(bytes)) {
      return _verifyZip(bytes);
    }
    return _verifyLegacyJson(bytes);
  }

  bool _looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  Future<_LocalPackEvidence> _verifyZip(List<int> packBytes) async {
    final archive = ZipDecoder().decodeBytes(packBytes);
    ArchiveFile? certEntry;
    ArchiveFile? metaEntry;
    for (final entry in archive.files) {
      final name = entry.name.toLowerCase();
      if (name == 'certificate.hcv') certEntry = entry;
      if (name == 'meta.json') metaEntry = entry;
    }
    if (certEntry == null || metaEntry == null) {
      throw Exception('HCVPACK incompleto: certificate.hcv/meta.json mancanti.');
    }

    final certBytes = List<int>.from(certEntry.content as List<int>);
    final metaBytes = List<int>.from(metaEntry.content as List<int>);
    final certificateRaw = utf8.decode(certBytes);
    final certificateSha256 = sha256.convert(certBytes).toString();
    final meta = jsonDecode(utf8.decode(metaBytes));
    if (meta is! Map<String, dynamic>) {
      throw Exception('meta.json non valido.');
    }

    final version = (meta['version'] as num?)?.toInt() ?? 0;
    if (meta['type'] != 'HCV_PACKAGE' ||
        (version != 2 && version != 3) ||
        meta['certificateFile'] != 'certificate.hcv' ||
        meta['hashAlgorithm'] != 'SHA256' ||
        meta['certificateFormat'] != 'HCV' ||
        meta['certificateSha256'] != certificateSha256) {
      throw Exception('Metadati HCVPACK non coerenti.');
    }

    final contentName = version == 3
        ? meta['contentFile']?.toString()
        : meta['videoFile']?.toString();
    if (contentName == null || contentName.isEmpty) {
      throw Exception('Nome contenuto HCVPACK mancante.');
    }

    ArchiveFile? contentEntry;
    for (final entry in archive.files) {
      if (entry.name == contentName) {
        contentEntry = entry;
        break;
      }
    }
    if (contentEntry == null) {
      throw Exception('Contenuto HCVPACK mancante.');
    }

    final contentBytes = List<int>.from(contentEntry.content as List<int>);
    final contentSha256 = sha256.convert(contentBytes).toString();
    final declaredContentSha256 = version == 3
        ? meta['contentSha256']?.toString()
        : meta['videoSha256']?.toString();
    if (declaredContentSha256 != contentSha256) {
      throw Exception('Hash contenuto HCVPACK non valido.');
    }

    final createdAt = meta['createdAt']?.toString() ?? '';
    final packageId = meta['packageId']?.toString() ?? '';
    final expectedPackageId = sha256
        .convert(
          utf8.encode('$contentSha256|$certificateSha256|$createdAt'),
        )
        .toString();
    if (createdAt.isEmpty || packageId != expectedPackageId) {
      throw Exception('Package ID HCVPACK non valido.');
    }

    return _verifyCertificateAndContent(
      certificateRaw: certificateRaw,
      contentSha256: contentSha256,
    );
  }

  Future<_LocalPackEvidence> _verifyLegacyJson(List<int> packBytes) async {
    final decoded = jsonDecode(utf8.decode(packBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('HCVPACK legacy non valido.');
    }
    final video = decoded['video'];
    final certificate = decoded['certificate'];
    if (video is! String || certificate is! Map<String, dynamic>) {
      throw Exception('HCVPACK legacy incompleto.');
    }
    final contentBytes = base64Decode(video);
    return _verifyCertificateAndContent(
      certificateRaw: jsonEncode(certificate),
      contentSha256: sha256.convert(contentBytes).toString(),
    );
  }

  Future<_LocalPackEvidence> _verifyCertificateAndContent({
    required String certificateRaw,
    required String contentSha256,
  }) async {
    final certificate = jsonDecode(certificateRaw);
    if (certificate is! Map<String, dynamic>) {
      throw Exception('Certificato HCV non valido.');
    }

    final tempDir = await getTemporaryDirectory();
    final tempHcv = File(
      p.join(
        tempDir.path,
        'hcv_provenance_${DateTime.now().microsecondsSinceEpoch}.hcv',
      ),
    );
    try {
      await tempHcv.writeAsString(certificateRaw, flush: true);
      if (!await _verifier.verifyFile(tempHcv.path)) {
        throw Exception('Firma o catena del certificato HCV non valida.');
      }
    } finally {
      try {
        if (await tempHcv.exists()) await tempHcv.delete();
      } catch (_) {}
    }

    final content = certificate['content'];
    final storedContentSha256 =
        content is Map ? content['hash']?.toString().trim().toLowerCase() : null;
    if (storedContentSha256 != contentSha256.toLowerCase()) {
      throw Exception('Il contenuto non corrisponde al certificato HCV.');
    }

    final meta = certificate['meta'];
    final identity = meta is Map ? meta['identity'] : null;
    final hcvId = meta is Map
        ? meta['hcvId']?.toString().trim().toUpperCase() ?? ''
        : '';
    final creatorId = identity is Map
        ? identity['creatorId']?.toString().trim() ?? ''
        : '';
    final deviceKeyFingerprint = identity is Map
        ? identity['devicePublicKeyFingerprint']
                ?.toString()
                .trim()
                .toLowerCase() ??
            ''
        : '';

    if (!RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(hcvId) ||
        creatorId.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(deviceKeyFingerprint)) {
      throw Exception('Identità tecnica HCV incompleta.');
    }

    return _LocalPackEvidence(
      hcvId: hcvId,
      certificateRaw: certificateRaw,
      contentSha256: contentSha256.toLowerCase(),
      creatorId: creatorId,
      deviceKeyFingerprint: deviceKeyFingerprint,
    );
  }

  Color get _stateColor {
    if (_registryState == HCVRegistryProvenanceState.invalid ||
        !_localIntegrityVerified) {
      return const Color(0xFFE83E9C);
    }
    if (_registryState == HCVRegistryProvenanceState.verifiedV2) {
      return SigillumTheme.verified;
    }
    return SigillumTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SigillumTheme.deep,
      appBar: AppBar(
        backgroundColor: SigillumTheme.panel,
        foregroundColor: SigillumTheme.ink,
        elevation: 0,
        title: Text(
          _localized(
            it: 'Verifica HCVPACK',
            en: 'Verify HCVPACK',
            es: 'Verificar HCVPACK',
            ru: 'Проверка HCVPACK',
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Icon(
                      _localIntegrityVerified
                          ? Icons.verified_user_rounded
                          : Icons.gpp_bad_rounded,
                      size: 78,
                      color: _stateColor,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _loading ? SigillumTheme.ink : _stateColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _detail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SigillumTheme.muted,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (_hcvId != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _hcvId!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SigillumTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (!_loading) ...[
                    const SizedBox(height: 28),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _localized(
                          it: 'INDIETRO',
                          en: 'BACK',
                          es: 'VOLVER',
                          ru: 'НАЗАД',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalPackEvidence {
  const _LocalPackEvidence({
    required this.hcvId,
    required this.certificateRaw,
    required this.contentSha256,
    required this.creatorId,
    required this.deviceKeyFingerprint,
  });

  final String hcvId;
  final String certificateRaw;
  final String contentSha256;
  final String creatorId;
  final String deviceKeyFingerprint;
}
