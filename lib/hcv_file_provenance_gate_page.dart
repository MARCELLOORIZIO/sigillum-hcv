import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'hcv_registry_provenance.dart';
import 'hcv_verifier.dart';
import 'sigillum_theme.dart';
import 'verify_page.dart';

class HCVFileProvenanceGatePage extends StatefulWidget {
  const HCVFileProvenanceGatePage({
    super.key,
    required this.path,
    this.languageCode = 'it',
  });

  final String path;
  final String languageCode;

  @override
  State<HCVFileProvenanceGatePage> createState() =>
      _HCVFileProvenanceGatePageState();
}

class _HCVFileProvenanceGatePageState
    extends State<HCVFileProvenanceGatePage> {
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
      it: 'Verifica certificato',
      en: 'Certificate verification',
      es: 'Verificación del certificado',
      ru: 'Проверка сертификата',
    );
    _detail = _localized(
      it: 'Controllo firma HCV e Registry SIGILLUM…',
      en: 'Checking HCV signature and SIGILLUM Registry…',
      es: 'Comprobando firma HCV y Registry SIGILLUM…',
      ru: 'Проверка подписи HCV и Registry SIGILLUM…',
    );
    Future.microtask(_verifyAndRoute);
  }

  Future<void> _verifyAndRoute() async {
    try {
      final file = File(widget.path);
      if (!await file.exists()) throw Exception('File HCV non trovato.');
      final certificateRaw = await file.readAsString();
      if (!await _verifier.verifyFile(widget.path)) {
        throw Exception('Firma o catena HCV non valida.');
      }

      final certificate = jsonDecode(certificateRaw);
      if (certificate is! Map<String, dynamic>) {
        throw Exception('Certificato HCV non leggibile.');
      }
      final meta = certificate['meta'];
      final identity = meta is Map ? meta['identity'] : null;
      final content = certificate['content'];
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
      final contentSha256 = content is Map
          ? content['hash']?.toString().trim().toLowerCase() ?? ''
          : '';

      if (!RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(hcvId) ||
          creatorId.isEmpty ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(deviceKeyFingerprint) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(contentSha256)) {
        throw Exception('Identità o contenuto HCV incompleti.');
      }

      if (!mounted) return;
      setState(() {
        _localIntegrityVerified = true;
        _hcvId = hcvId;
      });

      final provenance = await _registry.verify(
        hcvId: hcvId,
        certificateRaw: certificateRaw,
        contentSha256: contentSha256,
        creatorId: creatorId,
        deviceKeyFingerprint: deviceKeyFingerprint,
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
            builder: (_) => VerifyPage(
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
          it: 'La firma HCV è valida, ma il record Registry è legacy e non dispone dell’attestazione di provenienza v2.',
          en: 'The HCV signature is valid, but the Registry record is legacy and has no provenance v2 attestation.',
          es: 'La firma HCV es válida, pero el registro es legacy y no dispone de atestación de procedencia v2.',
          ru: 'Подпись HCV действительна, но запись Registry устаревшая и не содержит аттестации происхождения v2.',
        );
      case HCVRegistryProvenanceState.unavailable:
        return _localized(
          it: 'La firma HCV è valida, ma il Registry non è raggiungibile. È verificata solo l’integrità locale.',
          en: 'The HCV signature is valid, but the Registry is unavailable. Only local integrity is verified.',
          es: 'La firma HCV es válida, pero el Registry no está disponible. Solo se verifica la integridad local.',
          ru: 'Подпись HCV действительна, но Registry недоступен. Подтверждена только локальная целостность.',
        );
      case HCVRegistryProvenanceState.notFound:
        return _localized(
          it: 'La firma HCV è valida, ma l’HCV-ID non risulta nel Registry. È verificata solo l’integrità locale.',
          en: 'The HCV signature is valid, but the HCV-ID is not in the Registry. Only local integrity is verified.',
          es: 'La firma HCV es válida, pero el HCV-ID no está en el Registry. Solo se verifica la integridad local.',
          ru: 'Подпись HCV действительна, но HCV-ID отсутствует в Registry. Подтверждена только локальная целостность.',
        );
      default:
        return provenance.message;
    }
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
            it: 'Verifica HCV',
            en: 'Verify HCV',
            es: 'Verificar HCV',
            ru: 'Проверка HCV',
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
