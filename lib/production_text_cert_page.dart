import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'hcv_engine.dart';
import 'hcv_package.dart';
import 'hcv_registry_service.dart';

class ProductionTextCertPage extends StatefulWidget {
  const ProductionTextCertPage({super.key});

  @override
  State<ProductionTextCertPage> createState() =>
      _ProductionTextCertPageState();
}

class _ProductionTextCertPageState extends State<ProductionTextCertPage> {
  final TextEditingController _controller = TextEditingController();
  final HCVRegistryService _registry = const HCVRegistryService();

  bool _loading = false;
  String _status = 'Scrivi il testo da certificare';
  String? _result;
  String? _hcvId;
  String? _textPath;
  String? _certificatePath;
  String? _packagePath;
  String? _registryStatus;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Directory> _outputDirectory() async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'sigillum', 'content'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _certify() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) {
      if (text.isEmpty) setState(() => _status = 'Inserisci un testo');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Creazione contenuto e certificato...';
      _result = null;
      _hcvId = null;
      _textPath = null;
      _certificatePath = null;
      _packagePath = null;
      _registryStatus = null;
    });

    try {
      final engine = HCVEngine()..start();
      final hcvId = engine.hcvId;
      final directory = await _outputDirectory();
      final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      final textFile = File(p.join(directory.path, 'hcv_text_$safeId.txt'));
      await textFile.writeAsString(text, encoding: utf8, flush: true);
      final bytes = await textFile.readAsBytes();
      final digest = sha256.convert(bytes).toString();

      engine.setContent(
        type: 'text',
        hash: digest,
        size: bytes.length,
        name: p.basename(textFile.path),
      );
      engine.setClaims({
        'fileIntegrity': 'VERIFIED',
        'captureSource': 'HCV_TEXT_EDITOR',
        'captureType': 'TEXT',
        'liveCapture': false,
        'displayRiskDecision': 'NOT_APPLICABLE',
        'displayRiskMeaning':
            'Il rischio di ripresa da display non si applica a un testo creato nell editor.',
        'sceneAuthenticity': 'NOT_APPLICABLE',
        'syntheticRisk': 'NOT_ASSESSED',
        'aiProofLevel': 'TEXT_AUTHORSHIP_DEVICE_SIGNATURE_V1',
        'socialVerification': true,
      });
      engine.stop();

      final certificate = await engine.exportToFile();
      final package = await HCVPackage().createContentPackage(
        contentPath: textFile.path,
        hcvPath: certificate,
      );
      await _registry.enqueueCertificateFile(certificate);
      String registryStatus;
      try {
        final report = await _registry.retryPendingUploads();
        registryStatus = report.pending == 0
            ? 'REGISTRY_CONFIRMED'
            : 'REGISTRY_PENDING (${report.pending})';
      } catch (_) {
        registryStatus = 'REGISTRY_PENDING';
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'VALID';
        _status = 'Testo certificato e verificato localmente';
        _hcvId = hcvId;
        _textPath = textFile.path;
        _certificatePath = certificate;
        _packagePath = package;
        _registryStatus = registryStatus;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'ERROR';
        _status = 'Errore certificazione testo: $error';
      });
    }
  }

  Future<void> _copySocialText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final value = _hcvId == null
        ? text
        : '$text\n\nHCV VERIFIED\nID: $_hcvId\nVerify with SIGILLUM';
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testo social copiato')),
    );
  }

  Future<void> _shareOutputs() async {
    final files = <XFile>[];
    for (final path in [_textPath, _certificatePath, _packagePath]) {
      if (path != null && await File(path).exists()) {
        files.add(XFile(path));
      }
    }
    if (files.isEmpty) return;
    await Share.shareXFiles(
      files,
      text: _hcvId == null ? 'SIGILLUM HCV' : 'SIGILLUM HCV\nID: $_hcvId',
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SelectableText('$label: $value', textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _result == 'VALID';
    return Scaffold(
      appBar: AppBar(title: const Text('Certifica testo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                valid ? Icons.verified : Icons.text_fields,
                size: 72,
                color: valid ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                minLines: 8,
                maxLines: 18,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Testo',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _certify,
                icon: const Icon(Icons.verified_user),
                label: const Text('CERTIFICA'),
              ),
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 14),
              SelectableText(_status, textAlign: TextAlign.center),
              _row('Esito', _result),
              _row('HCV-ID', _hcvId),
              _row('Registry', _registryStatus),
              if (valid) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _copySocialText,
                  icon: const Icon(Icons.copy),
                  label: const Text('COPIA TESTO SOCIAL'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _shareOutputs,
                  icon: const Icon(Icons.share),
                  label: const Text('CONDIVIDI TESTO + HCV + HCVPACK'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
