import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';

import 'hcv_verifier.dart';

class VideoVerifyPage extends StatefulWidget {
  final String? initialVideoPath;
  final String? initialHcvPath;

  const VideoVerifyPage({
    super.key,
    this.initialVideoPath,
    this.initialHcvPath,
  });

  @override
  State<VideoVerifyPage> createState() => _VideoVerifyPageState();
}

class _VideoVerifyPageState extends State<VideoVerifyPage> {
  final verifier = HCVVerifier();

  String status = "Seleziona video e certificato HCV";
  String? result;

  String? videoPath;
  String? hcvPath;

  @override
  void initState() {
    super.initState();

    videoPath = widget.initialVideoPath;
    hcvPath = widget.initialHcvPath;

    if (videoPath != null && hcvPath != null) {
      Future.microtask(verifyVideoWithHCV);
    } else if (videoPath != null) {
      status = "Video importato. Seleziona anche il certificato HCV";
    } else if (hcvPath != null) {
      status = "HCV importato. Seleziona anche il video";
    }
  }

  Future<void> pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    setState(() {
      videoPath = path;
      result = null;
      status = "Video selezionato";
    });
  }

  Future<void> pickHCV() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    if (!path.toLowerCase().endsWith(".hcv")) {
      setState(() {
        hcvPath = path;
        result = "INVALID ❌";
        status = "Seleziona un file .hcv";
      });
      return;
    }

    setState(() {
      hcvPath = path;
      result = null;
      status = "Certificato selezionato";
    });
  }

  Future<void> verifyVideoWithHCV() async {
    if (videoPath == null || hcvPath == null) {
      setState(() {
        status = "Seleziona prima video e HCV";
      });
      return;
    }

    try {
      setState(() {
        status = "Verifica in corso...";
        result = null;
      });

      final videoFile = File(videoPath!);
      final hcvFile = File(hcvPath!);

      if (!await videoFile.exists()) {
        setState(() {
          status = "Video non trovato";
          result = "INVALID ❌";
        });
        return;
      }

      if (!await hcvFile.exists()) {
        setState(() {
          status = "HCV non trovato";
          result = "INVALID ❌";
        });
        return;
      }

      final videoBytes = await videoFile.readAsBytes();
      final videoHash = sha256.convert(videoBytes).toString();

      final hcvJson = await hcvFile.readAsString();
      final hcvData = jsonDecode(hcvJson);

      final hcvOk = await verifier.verifyFile(hcvPath!);

      if (!hcvOk) {
        setState(() {
          status = "Certificato HCV non valido";
          result = "INVALID ❌";
        });
        return;
      }

      if (hcvData is! Map<String, dynamic>) {
        setState(() {
          status = "Formato HCV non valido";
          result = "INVALID ❌";
        });
        return;
      }

      if (!hcvData.containsKey("content")) {
        setState(() {
          status = "HCV senza contenuto collegato";
          result = "INVALID ❌";
        });
        return;
      }

      final content = hcvData["content"];

      if (content == null || content is! Map<String, dynamic>) {
        setState(() {
          status = "HCV senza content binding";
          result = "INVALID ❌";
        });
        return;
      }

      if (content["type"] != "video") {
        setState(() {
          status = "Il certificato non è per un video";
          result = "INVALID ❌";
        });
        return;
      }

      final storedHash = content["hash"];

      if (storedHash != videoHash) {
        setState(() {
          status = "Hash video non corrisponde";
          result = "TAMPERED / NOT VERIFIED ❌";
        });
        return;
      }

      setState(() {
        status = "Video verificato";
        result = "HUMAN VERIFIED ✔";
      });
    } catch (e) {
      setState(() {
        status = "ERRORE: $e";
        result = "INVALID ❌";
      });
    }
  }

  bool get isVerified {
    return result == "HUMAN VERIFIED ✔";
  }

  bool get hasResult {
    return result != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV Video Verify"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasResult
                    ? isVerified
                        ? Icons.verified
                        : Icons.error
                    : Icons.video_file,
                size: 72,
                color: hasResult
                    ? isVerified
                        ? Colors.green
                        : Colors.red
                    : Colors.grey,
              ),

              const SizedBox(height: 20),

              Text(
                status,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: pickVideo,
                child: const Text("SELEZIONA VIDEO"),
              ),

              if (videoPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  "VIDEO:\n$videoPath",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: pickHCV,
                child: const Text("SELEZIONA HCV"),
              ),

              if (hcvPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  "HCV:\n$hcvPath",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: verifyVideoWithHCV,
                child: const Text("VERIFICA VIDEO + HCV"),
              ),

              const SizedBox(height: 20),

              if (result != null)
                Text(
                  result!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? Colors.green : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}