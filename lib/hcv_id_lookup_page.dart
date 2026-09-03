import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_service.dart';
import 'hcv_verifier.dart';
import 'sigillum_theme.dart';

class HcvIdLookupPage extends StatefulWidget {
  const HcvIdLookupPage({
    super.key,
    this.languageCode = 'it',
  });

  final String languageCode;

  @override
  State<HcvIdLookupPage> createState() => _HcvIdLookupPageState();
}

class _HcvIdLookupPageState extends State<HcvIdLookupPage> {
  static final RegExp _hcvIdPattern = RegExp(r'^HCV-[A-F0-9]{16}$');

  final TextEditingController _idController = TextEditingController();
  final HCVRegistryService _registry = const HCVRegistryService();
  final HCVVerifier _verifier = HCVVerifier();

  bool _loading = false;
  String? _message;
  Map<String, dynamic>? _certificate;
  bool? _certificateValid;

  static const Map<String, Map<String, String>> _copy = {
    'it': {
      'title': 'Consulta HCV-ID',
      'helper': 'Inserisci un HCV-ID per consultare il certificato pubblicato nel Registry SIGILLUM.',
      'label': 'HCV-ID',
      'button': 'CONSULTA REGISTRY',
      'invalidId': 'HCV-ID non valido. Inserisci HCV- seguito da 16 caratteri esadecimali.',
      'loading': 'Consultazione Registry in corso...',
      'notFound': 'Certificato non presente nel Registry.',
      'unavailable': 'Registry temporaneamente non raggiungibile.',
      'invalidCertificate': 'Il certificato recuperato non supera la verifica crittografica.',
      'validCertificate': 'Certificato trovato e firma crittografica valida.',
      'warning': 'Questa funzione consulta e verifica il certificato registrato. Nessun file media è stato confrontato, quindi non certifica l’integrità di una copia posseduta dall’utente.',
      'details': 'Dati del certificato',
      'createdAt': 'Creato',
      'contentType': 'Tipo contenuto',
      'contentName': 'Nome contenuto',
      'creator': 'Creator',
      'provenance': 'Provenienza',
      'trust': 'Trust',
      'signature': 'Firma certificato',
      'signatureValid': 'VALIDA',
      'signatureInvalid': 'NON VALIDA',
    },
    'en': {
      'title': 'Look up HCV-ID',
      'helper': 'Enter an HCV-ID to retrieve the certificate published in the SIGILLUM Registry.',
      'label': 'HCV-ID',
      'button': 'LOOK UP REGISTRY',
      'invalidId': 'Invalid HCV-ID. Enter HCV- followed by 16 hexadecimal characters.',
      'loading': 'Looking up Registry...',
      'notFound': 'Certificate not found in the Registry.',
      'unavailable': 'Registry is temporarily unavailable.',
      'invalidCertificate': 'The retrieved certificate failed cryptographic verification.',
      'validCertificate': 'Certificate found and cryptographic signature is valid.',
      'warning': 'This function retrieves and verifies the registered certificate. No media file was compared, so it does not certify the integrity of a copy held by the user.',
      'details': 'Certificate data',
      'createdAt': 'Created',
      'contentType': 'Content type',
      'contentName': 'Content name',
      'creator': 'Creator',
      'provenance': 'Provenance',
      'trust': 'Trust',
      'signature': 'Certificate signature',
      'signatureValid': 'VALID',
      'signatureInvalid': 'INVALID',
    },
    'es': {
      'title': 'Consultar HCV-ID',
      'helper': 'Introduce un HCV-ID para consultar el certificado publicado en el Registry SIGILLUM.',
      'label': 'HCV-ID',
      'button': 'CONSULTAR REGISTRY',
      'invalidId': 'HCV-ID no válido. Introduce HCV- seguido de 16 caracteres hexadecimales.',
      'loading': 'Consultando Registry...',
      'notFound': 'Certificado no encontrado en Registry.',
      'unavailable': 'Registry no está disponible temporalmente.',
      'invalidCertificate': 'El certificado recuperado no supera la verificación criptográfica.',
      'validCertificate': 'Certificado encontrado y firma criptográfica válida.',
      'warning': 'Esta función consulta y verifica el certificado registrado. No se compara ningún archivo multimedia, por lo que no certifica la integridad de una copia del usuario.',
      'details': 'Datos del certificado',
      'createdAt': 'Creado',
      'contentType': 'Tipo de contenido',
      'contentName': 'Nombre del contenido',
      'creator': 'Creator',
      'provenance': 'Procedencia',
      'trust': 'Trust',
      'signature': 'Firma del certificado',
      'signatureValid': 'VÁLIDA',
      'signatureInvalid': 'NO VÁLIDA',
    },
    'ru': {
      'title': 'Проверить HCV-ID',
      'helper': 'Введите HCV-ID, чтобы получить сертификат из Registry SIGILLUM.',
      'label': 'HCV-ID',
      'button': 'ПРОВЕРИТЬ REGISTRY',
      'invalidId': 'Неверный HCV-ID. Введите HCV- и 16 шестнадцатеричных символов.',
      'loading': 'Запрос Registry...',
      'notFound': 'Сертификат не найден в Registry.',
      'unavailable': 'Registry временно недоступен.',
      'invalidCertificate': 'Полученный сертификат не прошёл криптографическую проверку.',
      'validCertificate': 'Сертификат найден, криптографическая подпись действительна.',
      'warning': 'Эта функция получает и проверяет зарегистрированный сертификат. Медиафайл не сравнивается, поэтому целостность пользовательской копии не подтверждается.',
      'details': 'Данные сертификата',
      'createdAt': 'Создан',
      'contentType': 'Тип контента',
      'contentName': 'Имя контента',
      'creator': 'Creator',
      'provenance': 'Происхождение',
      'trust': 'Trust',
      'signature': 'Подпись сертификата',
      'signatureValid': 'ДЕЙСТВИТЕЛЬНА',
      'signatureInvalid': 'НЕДЕЙСТВИТЕЛЬНА',
    },
  };

  String _t(String key) {
    final code = _copy.containsKey(widget.languageCode) ? widget.languageCode : 'en';
    return _copy[code]?[key] ?? _copy['en']?[key] ?? key;
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  Future<bool> _verifyCertificateMap(Map<String, dynamic> certificate) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/hcv_lookup_${DateTime.now().microsecondsSinceEpoch}.hcv',
    );

    try {
      await tempFile.writeAsString(jsonEncode(certificate), flush: true);
      return await _verifier.verifyFile(tempFile.path);
    } finally {
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _lookup() async {
    final hcvId = _idController.text.trim().toUpperCase();
    if (!_hcvIdPattern.hasMatch(hcvId)) {
      setState(() {
        _message = _t('invalidId');
        _certificate = null;
        _certificateValid = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = _t('loading');
      _certificate = null;
      _certificateValid = null;
    });

    try {
      final certificate = await _registry.fetchCertificate(hcvId);
      final valid = await _verifyCertificateMap(certificate);
      if (!mounted) return;
      setState(() {
        _certificate = certificate;
        _certificateValid = valid;
        _message = valid ? _t('validCertificate') : _t('invalidCertificate');
      });
    } on HCVRegistryException catch (error) {
      if (!mounted) return;
      setState(() {
        _certificate = null;
        _certificateValid = null;
        switch (error.kind) {
          case HCVRegistryFailureKind.notFound:
            _message = _t('notFound');
            break;
          case HCVRegistryFailureKind.unavailable:
          case HCVRegistryFailureKind.server:
            _message = _t('unavailable');
            break;
          case HCVRegistryFailureKind.invalidCertificate:
          case HCVRegistryFailureKind.invalidResponse:
            _message = error.message;
            break;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _certificate = null;
        _certificateValid = null;
        _message = error.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MapEntry<String, String>> _certificateRows() {
    final certificate = _certificate;
    if (certificate == null) return const [];

    final meta = _asMap(certificate['meta']) ?? const <String, dynamic>{};
    final content = _asMap(certificate['content']) ?? const <String, dynamic>{};
    final claims = _asMap(certificate['claims']) ?? const <String, dynamic>{};
    final identity = _asMap(meta['identity']) ?? const <String, dynamic>{};
    final provenance = _asMap(claims['provenance']) ?? const <String, dynamic>{};

    final rows = <MapEntry<String, String>>[];

    void add(String label, String? value) {
      if (value != null && value.isNotEmpty) rows.add(MapEntry(label, value));
    }

    add('HCV-ID', _firstNonEmpty([meta['hcvId'], _idController.text.trim().toUpperCase()]));
    add(
      _t('signature'),
      _certificateValid == true ? _t('signatureValid') : _t('signatureInvalid'),
    );
    add(_t('createdAt'), _firstNonEmpty([certificate['createdAt'], meta['createdAt']]));
    add(_t('contentType'), _firstNonEmpty([content['type'], claims['contentType']]));
    add(_t('contentName'), _firstNonEmpty([content['name']]));
    add(
      _t('creator'),
      _firstNonEmpty([
        identity['displayName'],
        identity['name'],
        meta['creatorName'],
        claims['creatorName'],
      ]),
    );
    add(
      _t('provenance'),
      _firstNonEmpty([
        provenance['status'],
        claims['provenanceState'],
        claims['provenanceStatus'],
      ]),
    );
    add(
      _t('trust'),
      _firstNonEmpty([
        claims['hcvTrustLevel'],
        meta['hcvTrustLevel'],
        identity['assuranceLevel'],
      ]),
    );

    return rows;
  }

  Widget _infoCard() {
    final rows = _certificateRows();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('details'),
            style: const TextStyle(
              color: SigillumTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows.length; i++) ...[
            Text(
              rows[i].key,
              style: const TextStyle(
                color: SigillumTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(
              rows[i].value,
              style: const TextStyle(
                color: SigillumTheme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (i != rows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _certificateValid;

    return Scaffold(
      backgroundColor: SigillumTheme.deep,
      appBar: AppBar(
        backgroundColor: SigillumTheme.panel,
        foregroundColor: SigillumTheme.ink,
        elevation: 0,
        title: Text(_t('title')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.manage_search_rounded,
                    color: SigillumTheme.ink,
                    size: 54,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SigillumTheme.ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('helper'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SigillumTheme.muted,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _idController,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: SigillumTheme.ink),
                    decoration: InputDecoration(
                      labelText: _t('label'),
                      hintText: 'HCV-0123456789ABCDEF',
                    ),
                    onSubmitted: (_) {
                      if (!_loading) _lookup();
                    },
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _loading ? null : _lookup,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(_t('button')),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: valid == false ? SigillumTheme.danger : SigillumTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (_certificate != null) ...[
                    const SizedBox(height: 20),
                    _infoCard(),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SigillumTheme.panelSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _t('warning'),
                      style: const TextStyle(
                        color: SigillumTheme.muted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
