import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'hcv_engine.dart';
import 'hcv_verifier.dart';
import 'hcv_registry_service.dart';

class TextCertPage extends StatefulWidget {
  const TextCertPage({super.key});

  @override
  State<TextCertPage> createState() => _TextCertPageState();
}

class _TextCertPageState extends State<TextCertPage> {
  final TextEditingController controller = TextEditingController();

  final verifier = HCVVerifier();
  final registry = const HCVRegistryService();

  String status = 'Scrivi un testo da certificare';
  String? result;
  String? hcvPath;
  String? textPath;
  String? hcvId;
  String? verificationUrl;
  String? registryStatus;

  bool loading = false;

  Future<Directory> _outputDirectory() async {
    final outputDir = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download')
        : Directory.systemTemp;

    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return outputDir;
  }

  Future<String> _renameTextWithHcvId({
    required String currentPath,
    required String hcvId,
  }) async {
    final currentFile = File(currentPath);
    final outputDir = await _outputDirectory();

    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final newPath = p.join(outputDir.path, 'hcv_text_$safeId.txt');

    final newFile = File(newPath);

    if (await newFile.exists()) {
      await newFile.delete();
    }

    final renamed = await currentFile.rename(newPath);
    return renamed.path;
  }

  Future<String> _renameHcvWithHcvId({
    required String currentPath,
    required String hcvId,
  }) async {
    final currentFile = File(currentPath);
    final outputDir = await _outputDirectory();

    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final newPath = p.join(outputDir.path, 'hcv_text_$safeId.hcv');

    final newFile = File(newPath);

    if (await newFile.exists()) {
      await newFile.delete();
    }

    final renamed = await currentFile.rename(newPath);
    return renamed.path;
  }

  Future<void> createTextCertificate() async {
    final text = controller.text.trim();

    if (text.isEmpty) {
      setState(() {
        status = 'Inserisci un testo';
        result = 'INVALID ❌';
      });
      return;
    }

    try {
      setState(() {
        loading = true;
        status = 'Creazione certificato testo...';
        result = null;
        hcvPath = null;
        textPath = null;
        hcvId = null;
        verificationUrl = null;
        registryStatus = null;
      });

      final outputDir = await _outputDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final textFile = File(
        p.join(outputDir.path, 'hcv_text_$timestamp.txt'),
      );

      await textFile.writeAsString(text, encoding: utf8);

      final engine = HCVEngine();
      engine.start();

      final textBytes = await textFile.readAsBytes();
      final textHash = sha256.convert(textBytes).toString();

      engine.setContent(
        type: 'text',
        hash: textHash,
        size: textBytes.length,
        name: p.basename(textFile.path),
      );

      engine.stop();

      final exportedPath = await engine.exportToFile();
      File pairedHcvFile = File(p.setExtension(textFile.path, '.hcv'));
      final exportedFile = File(exportedPath);

      if (exportedFile.path != pairedHcvFile.path) {
        await exportedFile.copy(pairedHcvFile.path);
        try {
          await exportedFile.delete();
        } catch (_) {}
      }

      final ok = await verifier.verifyFile(pairedHcvFile.path);

      String? detectedId;
      String? detectedUrl;

      try {
        final data = jsonDecode(await pairedHcvFile.readAsString());
        if (data is Map<String, dynamic>) {
          final meta = data['meta'];
          if (meta is Map) {
            detectedId = meta['hcvId']?.toString();
            detectedUrl = meta['verificationUrl']?.toString();
          }
        }
      } catch (_) {}

      String finalTextPath = textFile.path;
      String finalHcvPath = pairedHcvFile.path;

      if (detectedId != null && detectedId.isNotEmpty) {
        try {
          finalTextPath = await _renameTextWithHcvId(
            currentPath: textFile.path,
            hcvId: detectedId,
          );

          finalHcvPath = await _renameHcvWithHcvId(
            currentPath: pairedHcvFile.path,
            hcvId: detectedId,
          );

          pairedHcvFile = File(finalHcvPath);
        } catch (_) {}
      }

      setState(() {
        loading = false;
        hcvPath = finalHcvPath;
        textPath = finalTextPath;
        hcvId = detectedId;
        verificationUrl = detectedUrl;
        result = ok ? 'VALID ✔' : 'INVALID ❌';
        status = ok
            ? 'Testo certificato e verificato'
            : 'Certificato creato ma NON valido';
      });

      if (ok) {
        setState(() {
          registryStatus = 'Uploading certificate to registry...';
        });

        try {
          final res = await registry.uploadCertificateFile(pairedHcvFile.path);
          setState(() {
            registryStatus = 'Registry OK: ${res['hcvId'] ?? detectedId}';
          });
        } catch (e) {
          setState(() {
            registryStatus = 'Registry offline/non raggiungibile: $e';
          });
        }
      }
    } catch (e) {
      setState(() {
        loading = false;
        status = 'ERRORE: $e';
        result = 'INVALID ❌';
      });
    }
  }

  Future<void> copyHcvId() async {
    final text = hcvId ?? verificationUrl;
    if (text == null) return;

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HCV-ID copiato')),
    );
  }

  Future<void> copySocialText() async {
    final originalText = controller.text.trim();
    if (originalText.isEmpty) return;

    final socialText = hcvId == null
        ? originalText
        : '$originalText\n\nHCV VERIFIED ✔\nID: $hcvId\nVerify with HCV App';

    await Clipboard.setData(ClipboardData(text: socialText));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testo social copiato')),
    );
  }

  Future<void> shareSocialText() async {
    final originalText = controller.text.trim();
    if (originalText.isEmpty) return;

    final socialText = hcvId == null
        ? originalText
        : '$originalText\n\nHCV VERIFIED ✔\nID: $hcvId\nVerify with HCV App';

    await Share.share(
      socialText,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  Future<void> shareTextFileAndCertificate() async {
    if (textPath == null || hcvPath == null) return;

    final shareText = hcvId == null
        ? 'HCV Human Verified ✔'
        : 'HCV Human Verified ✔\nID: $hcvId\nVerify with HCV App';

    await Share.shareXFiles(
      [XFile(textPath!), XFile(hcvPath!)],
      text: shareText,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get isValid => result == 'VALID ✔';

  Widget _statusBadge() {
    if (result == null) {
      return Icon(
        Icons.text_fields,
        size: 72,
        color: loading ? Colors.orange : Colors.grey,
      );
    }

    return Icon(
      isValid ? Icons.verified : Icons.error,
      size: 72,
      color: isValid ? Colors.green : Colors.red,
    );
  }

  Widget _resultBlock() {
    if (result == null) {
      return Text(
        status,
        textAlign: TextAlign.center,
      );
    }

    return Column(
      children: [
        Text(
          isValid ? 'HUMAN VERIFIED ✔' : 'NOT VERIFIED ❌',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isValid ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _verifiedCard() {
    if (hcvId == null && verificationUrl == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Testo verificabile creato',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'HCV-ID:\n${hcvId ?? '-'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Per i social puoi copiare il testo con HCV-ID. '
              'Per file, puoi condividere TXT + certificato HCV.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: copyHcvId,
              icon: const Icon(Icons.copy),
              label: const Text('COPIA HCV-ID'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _registryCard() {
    if (registryStatus == null) {
      return const SizedBox.shrink();
    }

    final ok = registryStatus!.startsWith('Registry OK');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        registryStatus!,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: ok ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _actionButtons() {
    if (!isValid) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          width: 300,
          child: ElevatedButton.icon(
            onPressed: copySocialText,
            icon: const Icon(Icons.copy),
            label: const Text('COPIA TESTO SOCIAL'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 300,
          child: ElevatedButton.icon(
            onPressed: shareSocialText,
            icon: const Icon(Icons.share),
            label: const Text('CONDIVIDI COME POST'),
          ),
        ),
        const SizedBox(height: 10),
        if (textPath != null && hcvPath != null)
          SizedBox(
            width: 300,
            child: ElevatedButton.icon(
              onPressed: shareTextFileAndCertificate,
              icon: const Icon(Icons.attach_file),
              label: const Text('CONDIVIDI TXT + HCV'),
            ),
          ),
      ],
    );
  }

  Widget _createdFilesCard() {
    if (hcvPath == null && textPath == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Text(
              'File creati',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (textPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'TXT:\n$textPath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
            if (hcvPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Certificato:\n$hcvPath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void resetPage() {
    setState(() {
      controller.clear();
      status = 'Scrivi un testo da certificare';
      result = null;
      hcvPath = null;
      textPath = null;
      hcvId = null;
      verificationUrl = null;
      registryStatus = null;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certifica testo HCV'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statusBadge(),
              const SizedBox(height: 20),
              if (result == null)
                TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Testo da certificare',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 20),
              if (result == null)
                SizedBox(
                  width: 260,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : createTextCertificate,
                    icon: const Icon(Icons.verified),
                    label: Text(
                      loading ? 'CREAZIONE...' : 'CERTIFICA TESTO',
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _resultBlock(),
              _verifiedCard(),
              _registryCard(),
              _actionButtons(),
              _createdFilesCard(),
              if (result != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 260,
                  child: OutlinedButton.icon(
                    onPressed: resetPage,
                    icon: const Icon(Icons.refresh),
                    label: const Text('CREA NUOVO TESTO'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
