import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_service.dart';
import 'hcv_verifier.dart';
import 'package:path/path.dart' as p;

class RegistryVerifyPage extends StatefulWidget {
  final String? initialMediaPath;

  const RegistryVerifyPage({
    super.key,
    this.initialMediaPath,
  });

  @override
  State<RegistryVerifyPage> createState() => _RegistryVerifyPageState();
}

class _RegistryVerifyPageState extends State<RegistryVerifyPage> {
  final idController = TextEditingController();

  final registry = const HCVRegistryService();
  final verifier = HCVVerifier();

  String status =
      'Inserisci HCV-ID e seleziona il file originale da verificare';

  String? result;
  String? mediaPath;

  Map<String, dynamic>? certificate;

  String? creatorName;
  String? trustLevel;
  String? contentType;
  String? hcvTrustLevel;
  String? liveCaptureTrust;
  String? screenReplayRisk;
  String? syntheticRisk;
  String? sceneAuthenticity;
  String? aiProofLevel;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    final path = widget.initialMediaPath;

    if (path != null && path.isNotEmpty) {
      mediaPath = path;

      final fileName = path.split('/').last;

      final match = RegExp(
        r'hcv_video_([A-Za-z0-9\-]+)',
        caseSensitive: false,
      ).firstMatch(fileName);

      if (match != null) {
        idController.text = match.group(1)!.toUpperCase();
        status =
            'Video ricevuto. HCV-ID rilevato automaticamente. Premi VERIFICA DA REGISTRY';
      } else {
        status =
            'Video ricevuto. Inserisci HCV-ID e premi VERIFICA DA REGISTRY';
      }
    }
  }

  @override
  void dispose() {
    idController.dispose();
    super.dispose();
  }

  Future<void> pickMedia() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4',
        'mov',
        'jpg',
        'jpeg',
        'png',
        'txt',
        'pdf',
        'mp3',
        'wav',
      ],
    );

    if (picked == null) return;

    final path = picked.files.single.path;
    if (path == null) return;

    final lowerPath = path.toLowerCase();

    if (lowerPath.endsWith('.hcv') || lowerPath.endsWith('.hcvpack')) {
      setState(() {
        mediaPath = null;
        result = 'INVALID ❌';
        status =
            'Qui devi selezionare il file ORIGINALE (mp4, jpg, pdf, txt, audio), NON .hcv o .hcvpack';
      });

      return;
    }

    final fileName = path.split('/').last;

    final match = RegExp(
      r'HCV-[A-Z0-9]+',
      caseSensitive: false,
    ).firstMatch(fileName);

    if (match != null) {
      idController.text = match.group(1)!.toUpperCase();
    }

    setState(() {
      mediaPath = path;
      result = null;
      status = match != null
          ? 'HCV-ID rilevato dal nome file. Ora premi VERIFICA DA REGISTRY'
          : 'Media originale selezionato. Inserisci HCV-ID e premi VERIFICA DA REGISTRY';
    });
  }

  Future<void> verifyFromRegistry() async {
    var hcvId = idController.text.trim();

    if (hcvId.startsWith('hcv://verify/')) {
      hcvId = hcvId.replaceFirst('hcv://verify/', '');
    }

    hcvId = hcvId.toUpperCase();

    if (hcvId.isEmpty) {
      setState(() {
        status = 'Inserisci HCV-ID';
      });

      return;
    }

    if (mediaPath == null) {
      setState(() {
        status = 'Seleziona il file originale da verificare';
      });

      return;
    }

    setState(() {
      loading = true;

      result = null;

      status = 'Scaricamento certificato dal Registry HCV...';

      certificate = null;

      creatorName = null;
      trustLevel = null;
      contentType = null;
      hcvTrustLevel = null;
      liveCaptureTrust = null;
      screenReplayRisk = null;
      syntheticRisk = null;
      sceneAuthenticity = null;
      aiProofLevel = null;
    });

    try {
      final cert = await registry.fetchCertificate(hcvId);

      final claims = cert['claims'];

      if (claims is Map) {
        hcvTrustLevel = claims['trustLevel']?.toString();
        liveCaptureTrust = claims['liveCaptureTrust']?.toString();
        screenReplayRisk = claims['screenReplayRisk']?.toString();
        syntheticRisk = claims['syntheticRisk']?.toString();
        sceneAuthenticity = claims['sceneAuthenticity']?.toString();
        aiProofLevel = claims['aiProofLevel']?.toString();
      }

      final tempDir = await getTemporaryDirectory();

      final tempHcv = File('${tempDir.path}/$hcvId.hcv');

      await tempHcv.writeAsString(
        const JsonEncoder.withIndent('  ').convert(cert),
      );

      final certOk = await verifier.verifyFile(tempHcv.path);

      if (!certOk) {
        setState(() {
          loading = false;

          status = 'Certificato scaricato ma firma crittografica NON valida';

          result = 'INVALID ❌';

          certificate = cert;
        });

        return;
      }

      final content = cert['content'];

      if (content is! Map<String, dynamic>) {
        setState(() {
          loading = false;

          status = 'Certificato senza content binding';

          result = 'INVALID ❌';

          certificate = cert;
        });

        return;
      }

      final mediaFile = File(mediaPath!);

      if (!await mediaFile.exists()) {
        setState(() {
          loading = false;

          status = 'File media non trovato';

          result = 'INVALID ❌';
        });

        return;
      }

      final mediaBytes = await mediaFile.readAsBytes();

      final actualHash = sha256.convert(mediaBytes).toString();

      final expectedHash = content['hash']?.toString();

      final meta = cert['meta'];

      final identity = meta is Map ? meta['identity'] : null;

      if (identity is Map) {
        creatorName = identity['creatorName']?.toString();

        trustLevel = identity['trustLevel']?.toString();
      }

      contentType = content['type']?.toString();

      final verified = actualHash == expectedHash;

      setState(() {
        loading = false;

        certificate = cert;

        if (verified) {
          status = 'File verificato automaticamente tramite Registry HCV';

          result = 'HUMAN VERIFIED ✔';
        } else {
          status = 'HASH DIFFERENTE → file modificato o non originale';

          result = 'TAMPERED / NOT VERIFIED ❌';
        }
      });
    } catch (e) {
      setState(() {
        loading = false;

        status = 'ERRORE REGISTRY: $e';

        result = 'INVALID ❌';
      });
    }
  }

  bool get isVerified => result == 'HUMAN VERIFIED ✔';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify by HCV-ID'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                result == null
                    ? Icons.cloud_sync
                    : isVerified
                        ? Icons.verified
                        : Icons.error,
                size: 72,
                color: result == null
                    ? Colors.grey
                    : isVerified
                        ? Colors.green
                        : Colors.red,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: idController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'HCV-ID',
                  hintText: 'HCV-DE27F535',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loading ? null : pickMedia,
                child: const Text('SELEZIONA MEDIA ORIGINALE'),
              ),
              if (mediaPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  mediaPath!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : verifyFromRegistry,
                child: Text(
                  loading ? 'VERIFICA...' : 'VERIFICA DA REGISTRY',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Il certificato viene recuperato automaticamente dal Registry HCV. Devi selezionare SOLO il file originale.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 20),
                Text(
                  result!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? Colors.green : Colors.red,
                  ),
                ),
              ],
              if (creatorName != null ||
                  trustLevel != null ||
                  contentType != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Creator: ${creatorName ?? '-'}\n'
                  'Trust: ${trustLevel ?? '-'}\n'
                  'Type: ${contentType ?? '-'}',
                  textAlign: TextAlign.center,
                ),
              ],
              if (hcvTrustLevel != null ||
                  liveCaptureTrust != null ||
                  screenReplayRisk != null ||
                  syntheticRisk != null ||
                  sceneAuthenticity != null ||
                  aiProofLevel != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'HCV Trust',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trust Level: ${hcvTrustLevel ?? '-'}\n'
                  'Live Capture: ${liveCaptureTrust ?? '-'}\n'
                  'Screen Replay Risk: ${screenReplayRisk ?? '-'}\n'
                  'Synthetic Risk: ${syntheticRisk ?? '-'}\n'
                  'Scene Authenticity: ${sceneAuthenticity ?? '-'}\n'
                  'AI Proof Level: ${aiProofLevel ?? '-'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
