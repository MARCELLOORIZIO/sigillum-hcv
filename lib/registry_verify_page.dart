import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_service.dart';
import 'hcv_verifier.dart';
import 'package:path/path.dart' as p;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

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
  String? extractHcvIdFromName(String fileName) {
    final patterns = [
      RegExp(r'hcv_video_(HCV-[A-Z0-9]+)', caseSensitive: false),
      RegExp(r'(HCV-[A-Z0-9]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fileName);

      if (match != null) {
        return match.group(1)!.toUpperCase();
      }
    }

    return null;
  }

  Future<String?> extractHcvIdFromImage(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);

      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      final recognizedText = await textRecognizer.processImage(inputImage);

      await textRecognizer.close();

      final text = recognizedText.text.toUpperCase();

      final normalized = text
          .replaceAll(' ', '')
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll('HCV-ID:', 'HCV-')
          .replaceAll('HCVID:', 'HCV-')
          .replaceAll('HCV1D:', 'HCV-')
          .replaceAll('HCV—', 'HCV-')
          .replaceAll('HCV_', 'HCV-');

      final patterns = [
        RegExp(r'HCV-[A-Z0-9]{4,20}'),
        RegExp(r'HCV[A-Z0-9]{4,20}'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(normalized);

        if (match != null) {
          final raw = match.group(0)!;

          if (raw.startsWith('HCV-')) {
            return raw;
          }

          return raw.replaceFirst('HCV', 'HCV-');
        }
      }

      return null;

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> extractHcvIdFromVideoFrame(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final framePath =
          '${tempDir.path}/hcv_ocr_frame_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final command =
          "-y -i '$videoPath' -ss 00:00:00.3 -frames:v 1 '$framePath'";

      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();

      if (code == null || !ReturnCode.isSuccess(code)) {
        return null;
      }

      final id = await extractHcvIdFromImage(framePath);

      try {
        final frameFile = File(framePath);
        if (await frameFile.exists()) {
          await frameFile.delete();
        }
      } catch (_) {}

      return id;
    } catch (_) {
      return null;
    }
  }

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
      withData: true,
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

    final pickedFile = picked.files.single;
    String? path = pickedFile.path;

    if (path == null && pickedFile.bytes != null) {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/${pickedFile.name}');
      await localFile.writeAsBytes(pickedFile.bytes!);
      path = localFile.path;
    }

    if (path == null) {
      setState(() {
        status = 'File selezionato ma non importabile su iOS';
      });
      return;
    }

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

    final fileName = picked.files.single.name;

    final detectedId = extractHcvIdFromName(fileName);

    if (detectedId != null) {
      idController.text = detectedId;
    } else {
      String? ocrId;

      final lowerPath = path.toLowerCase();

      if (lowerPath.endsWith('.jpg') ||
          lowerPath.endsWith('.jpeg') ||
          lowerPath.endsWith('.png')) {
        ocrId = await extractHcvIdFromImage(path);
      } else if (lowerPath.endsWith('.mp4') ||
          lowerPath.endsWith('.mov') ||
          lowerPath.endsWith('.m4v')) {
        ocrId = await extractHcvIdFromVideoFrame(path);
      }

      if (ocrId != null) {
        idController.text = ocrId;

        setState(() {
          status = 'HCV-ID rilevato via OCR nel media ✔';
        });
      }

      if (ocrId != null) {
        idController.text = ocrId;

        setState(() {
          status = 'HCV-ID rilevato via OCR ✔';
        });
      }
    }

    setState(() {
      mediaPath = path;
      result = null;

      status = detectedId != null
          ? 'HCV-ID rilevato dal nome file. Ora premi VERIFICA DA REGISTRY'
          : 'Video selezionato. Leggi HCV-ID dal watermark e inseriscilo manualmente.';
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

      final forensicVerified = actualHash == expectedHash;

      setState(() {
        loading = false;

        certificate = cert;

        if (forensicVerified) {
          status =
              'FORENSIC VERIFIED ✔\nFile identico all’originale certificato. Hash SHA-256 corrispondente.';

          result = 'FORENSIC VERIFIED ✔';
        } else {
          status =
              'SOCIAL VERIFIED ✔\nFile ricompresso, rinominato o modificato dai social. HCV-ID e certificato Registry validi, ma hash non identico.';

          final hcvIdWasDetectedInMedia = status.toUpperCase().contains('OCR');

          if (hcvIdWasDetectedInMedia) {
            status =
                'SOCIAL VERIFIED ✔\nHCV-ID rilevato nel media e certificato Registry valido. Hash diverso perché il file è stato ricompresso o rinominato.';

            result = 'SOCIAL VERIFIED ✔';
          } else {
            status =
                'HCV-ID valido nel Registry, ma non rilevato automaticamente nel file selezionato. Verifica social non conclusiva.';

            result = 'ID VALID / MEDIA NOT VERIFIED ⚠️';
          }
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

  bool get isVerified =>
      result == 'HUMAN VERIFIED ✔' ||
      result == 'FORENSIC VERIFIED ✔' ||
      result == 'SOCIAL VERIFIED ✔';

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
