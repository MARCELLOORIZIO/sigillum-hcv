import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_service.dart';
import 'hcv_text_integrity.dart';
import 'hcv_verifier.dart';

class TextSocialVerifyPage extends StatefulWidget {
  const TextSocialVerifyPage({
    super.key,
    this.languageCode = 'it',
    this.initialText,
  });

  final String languageCode;
  final String? initialText;

  @override
  State<TextSocialVerifyPage> createState() => _TextSocialVerifyPageState();
}

class _TextSocialVerifyPageState extends State<TextSocialVerifyPage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final HCVRegistryService _registry = const HCVRegistryService();
  final HCVVerifier _verifier = HCVVerifier();

  bool _busy = false;
  String _status = '';
  HCVTextMatchResult? _match;
  bool? _signatureValid;
  String? _source;
  String? _originalFromPackage;

  bool get _it => widget.languageCode.toLowerCase().startsWith('it');
  String _label(String it, String en) => _it ? it : en;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText ?? '';
    _textController.text = initial;
    _idController.text = HCVTextIntegrity.extractHcvId(initial) ?? '';
    _status = _label(
      'Incolla il testo pubblicato con la riga SIGILLUM.',
      'Paste the published text including the SIGILLUM line.',
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<bool> _verifyCertificateRaw(String rawCertificate) async {
    final tempDirectory = await getTemporaryDirectory();
    final tempFile = File(
      p.join(
        tempDirectory.path,
        'sigillum_text_verify_${DateTime.now().microsecondsSinceEpoch}.hcv',
      ),
    );
    try {
      await tempFile.writeAsString(rawCertificate, encoding: utf8, flush: true);
      return await _verifier.verifyFile(tempFile.path);
    } finally {
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _verifyRegistryText() async {
    if (_busy) return;
    final published = _textController.text;
    final detected = HCVTextIntegrity.extractHcvId(published);
    final entered = HCVTextIntegrity.extractHcvId(_idController.text);
    final id = entered ?? detected;
    if (id == null) {
      setState(() {
        _status = _label(
          'HCV-ID mancante. Incolla anche la riga “🔏 SIGILLUM HCV-…”.',
          'Missing HCV-ID. Paste the “🔏 SIGILLUM HCV-…” line too.',
        );
        _match = null;
        _signatureValid = null;
      });
      return;
    }
    if (published.trim().isEmpty) {
      setState(() {
        _status = _label(
          'Incolla il testo pubblicato.',
          'Paste the published text.',
        );
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = _label(
        'Recupero e verifica del certificato…',
        'Retrieving and verifying certificate…',
      );
      _match = null;
      _signatureValid = null;
      _source = null;
      _idController.text = id;
    });

    try {
      final certificate = await _registry.fetchCertificate(id);
      final rawCertificate = jsonEncode(certificate);
      final signatureValid = await _verifyCertificateRaw(rawCertificate);
      if (!signatureValid) {
        setState(() {
          _signatureValid = false;
          _status = _label(
            'Il certificato recuperato non supera la verifica crittografica.',
            'The retrieved certificate failed cryptographic verification.',
          );
          _source = 'Registry';
        });
        return;
      }
      final match = HCVTextIntegrity.comparePublishedText(
        publishedText: published,
        certificate: certificate,
      );
      setState(() {
        _signatureValid = true;
        _match = match;
        _source = 'Registry';
        _status = _statusFor(match.kind);
      });
    } on HCVRegistryException catch (error) {
      setState(() {
        _status = error.kind == HCVRegistryFailureKind.notFound
            ? _label(
                'Certificato non presente nel Registry.',
                'Certificate is not present in the Registry.',
              )
            : '${_label('Registry non disponibile', 'Registry unavailable')}: ${error.message}';
        _source = 'Registry';
      });
    } catch (error) {
      setState(() {
        _status = '${_label('Verifica non completata', 'Verification failed')}: $error';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<FilePickerResult?> _pickTextHcvPackage() {
    if (Platform.isIOS) {
      // iOS can display unknown custom extensions as disabled when the picker
      // is restricted to an undeclared UTI. Let Files return the selected
      // document and enforce the .hcvpack extension immediately afterwards.
      return FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
    }
    return FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['hcvpack'],
      allowMultiple: false,
    );
  }

  Future<void> _verifyTextPackage() async {
    if (_busy) return;
    final selected = await _pickTextHcvPackage();
    final packagePath = selected?.files.single.path;
    if (packagePath == null || packagePath.isEmpty) return;

    if (p.extension(packagePath).toLowerCase() != '.hcvpack') {
      setState(() {
        _status = _label(
          'Seleziona un file HCVPACK (.hcvpack).',
          'Select an HCVPACK file (.hcvpack).',
        );
        _match = null;
        _signatureValid = null;
        _source = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = _label('Apertura HCVPACK…', 'Opening HCVPACK…');
      _match = null;
      _signatureValid = null;
      _source = null;
    });

    try {
      final package = await HCVTextPackage.read(packagePath);
      final signatureValid = await _verifyCertificateRaw(package.certificateRaw);
      if (!signatureValid) {
        setState(() {
          _signatureValid = false;
          _status = _label(
            'La firma del certificato contenuto nel pacchetto non è valida.',
            'The certificate signature inside the package is invalid.',
          );
          _source = 'HCVPACK';
        });
        return;
      }
      final decoded = jsonDecode(package.certificateRaw);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Certificato HCV non valido');
      }
      final match = HCVTextIntegrity.comparePublishedText(
        publishedText: package.originalText,
        certificate: decoded,
      );
      final id = HCVTextIntegrity.extractHcvId(
        package.meta?['hcvId']?.toString() ?? '',
      );
      setState(() {
        _signatureValid = true;
        _match = match;
        _source = 'HCVPACK';
        _originalFromPackage = package.originalText;
        _textController.text = package.originalText;
        if (id != null) _idController.text = id;
        _status = _statusFor(match.kind);
      });
    } catch (error) {
      setState(() {
        _status = '${_label('HCVPACK non verificabile', 'HCVPACK cannot be verified')}: $error';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusFor(HCVTextMatchKind kind) {
    switch (kind) {
      case HCVTextMatchKind.exact:
        return _label(
          'Il testo coincide esattamente con quello certificato.',
          'The text exactly matches the certified text.',
        );
      case HCVTextMatchKind.formattingOnly:
        return _label(
          'Parole e punteggiatura coincidono. Sono cambiati soltanto gli spazi o i ritorni a capo.',
          'Words and punctuation match. Only whitespace or line breaks changed.',
        );
      case HCVTextMatchKind.modified:
        return _label(
          'Il contenuto pubblicato non coincide con quello certificato.',
          'The published content does not match the certified text.',
        );
      case HCVTextMatchKind.unsupportedCertificate:
        return _label(
          'Il certificato non contiene un’impronta testuale verificabile.',
          'The certificate does not contain a verifiable text fingerprint.',
        );
    }
  }

  Future<void> _copyOriginal() async {
    final text = _originalFromPackage;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_label('Testo originale copiato', 'Original text copied')),
      ),
    );
  }

  Color _resultColor() {
    if (_signatureValid == false) return Colors.red;
    switch (_match?.kind) {
      case HCVTextMatchKind.exact:
        return Colors.green;
      case HCVTextMatchKind.formattingOnly:
        return Colors.lightGreen;
      case HCVTextMatchKind.modified:
        return Colors.red;
      case HCVTextMatchKind.unsupportedCertificate:
      case null:
        return Colors.orange;
    }
  }

  String _resultTitle() {
    if (_signatureValid == false) {
      return _label('CERTIFICATO NON VALIDO', 'INVALID CERTIFICATE');
    }
    switch (_match?.kind) {
      case HCVTextMatchKind.exact:
        return _label('TESTO ORIGINALE VERIFICATO', 'ORIGINAL TEXT VERIFIED');
      case HCVTextMatchKind.formattingOnly:
        return _label(
          'TESTO VERIFICATO — FORMATTAZIONE MODIFICATA',
          'TEXT VERIFIED — FORMATTING CHANGED',
        );
      case HCVTextMatchKind.modified:
        return _label('TESTO MODIFICATO', 'TEXT MODIFIED');
      case HCVTextMatchKind.unsupportedCertificate:
        return _label('VERIFICA NON SUPPORTATA', 'VERIFICATION NOT SUPPORTED');
      case null:
        return _label('VERIFICA TESTO', 'TEXT VERIFICATION');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _match != null || _signatureValid == false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_label('Verifica testo pubblicato', 'Verify published text')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          TextField(
            controller: _textController,
            minLines: 7,
            maxLines: 18,
            onChanged: (value) {
              final detected = HCVTextIntegrity.extractHcvId(value);
              if (detected != null && _idController.text != detected) {
                _idController.text = detected;
              }
            },
            decoration: InputDecoration(
              labelText: _label('Testo copiato dal social', 'Text copied from social media'),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'HCV-ID',
              helperText: _label(
                'Viene letto automaticamente dalla riga SIGILLUM.',
                'Automatically read from the SIGILLUM line.',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _verifyRegistryText,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(
              _busy
                  ? _label('VERIFICA IN CORSO…', 'VERIFYING…')
                  : _label('VERIFICA DAL REGISTRY', 'VERIFY FROM REGISTRY'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _verifyTextPackage,
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(_label('APRI HCVPACK TESTO', 'OPEN TEXT HCVPACK')),
          ),
          if (_busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasResult ? _resultColor().withValues(alpha: 0.16) : Colors.white10,
              border: Border.all(color: hasResult ? _resultColor() : Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  hasResult ? Icons.verified_outlined : Icons.text_snippet_outlined,
                  color: hasResult ? _resultColor() : Colors.white70,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  _resultTitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hasResult ? _resultColor() : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_status, textAlign: TextAlign.center),
                if (_source != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_label('Fonte', 'Source')}: $_source',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (_originalFromPackage != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copyOriginal,
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(_label('COPIA TESTO ORIGINALE', 'COPY ORIGINAL TEXT')),
            ),
          ],
        ],
      ),
    );
  }
}
