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

    if (widget.initialVideoPath != null || widget.initialHcvPath != null) {
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
  }

  Future<void> pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
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
      type: FileType.custom,
      allowedExtensions: ['hcv'],
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

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

      if (!hcvData.containsKey("content")) {
        setState(() {
          status = "HCV senza contenuto collegato";
          result = "INVALID ❌";
        });
        return;
      }

      final content = hcvData["content"];

      if (content == null) {
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(status),

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
                  style: const TextStyle(fontSize: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
