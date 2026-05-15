import 'dart:io';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

import 'hcvpack_player_page.dart';
import 'verify_page.dart';
import 'video_verify_page.dart';
import 'hcv_verifier.dart';

class HCVImportRouterPage extends StatefulWidget {
  final String path;

  const HCVImportRouterPage({
    super.key,
    required this.path,
  });

  @override
  State<HCVImportRouterPage> createState() => _HCVImportRouterPageState();
}

class _HCVImportRouterPageState extends State<HCVImportRouterPage> {
  final verifier = HCVVerifier();

  String status = "Analisi file...";
  bool? isVerified;

  @override
  void initState() {
    super.initState();
    Future.microtask(processFile);
  }

  Future<void> processFile() async {
    final lower = widget.path.toLowerCase();

    if (lower.endsWith(".hcvpack")) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HCVPackPlayerPage(
            initialPath: widget.path,
          ),
        ),
      );
      return;
    }

    if (lower.endsWith(".hcv")) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyPage(
            initialPath: widget.path,
          ),
        ),
      );
      return;
    }

    if (lower.endsWith(".mp4") ||
        lower.endsWith(".mov") ||
        lower.endsWith(".m4v")) {
      await verifyVideo(widget.path);
      return;
    }

    setState(() {
      status = "Formato non supportato:\n${widget.path}";
      isVerified = false;
    });
  }

  Future<void> verifyVideo(String videoPath) async {
    try {
      setState(() {
        status = "Calcolo hash video...";
        isVerified = null;
      });

      final file = File(videoPath);

      if (!await file.exists()) {
        setState(() {
          status = "Video non trovato:\n$videoPath";
          isVerified = false;
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      setState(() {
        status = "Ricerca certificato HCV associato...";
      });

      final hcvPath = _guessHcvPath(videoPath);
      final hcvFile = File(hcvPath);

      if (!await hcvFile.exists()) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VideoVerifyPage(
              initialVideoPath: videoPath,
            ),
          ),
        );
        return;
      }

      setState(() {
        status = "Verifica certificato HCV...";
      });

      final certOk = await verifier.verifyFile(hcvPath);

      if (!certOk) {
        setState(() {
          status = "Certificato HCV non valido";
          isVerified = false;
        });
        return;
      }

      final certJson = await hcvFile.readAsString();

      if (!certJson.contains(hash)) {
        setState(() {
          status = "Video modificato o certificato non corrispondente";
          isVerified = false;
        });
        return;
      }

      setState(() {
        status = "HUMAN VERIFIED ✔";
        isVerified = true;
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VideoVerifyPage(
            initialVideoPath: videoPath,
            initialHcvPath: hcvPath,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        status = "Errore: $e";
        isVerified = false;
      });
    }
  }

  String _guessHcvPath(String videoPath) {
    final lower = videoPath.toLowerCase();

    if (lower.endsWith(".mp4")) {
      return videoPath.substring(0, videoPath.length - 4) + ".hcv";
    }

    if (lower.endsWith(".mov")) {
      return videoPath.substring(0, videoPath.length - 4) + ".hcv";
    }

    if (lower.endsWith(".m4v")) {
      return videoPath.substring(0, videoPath.length - 4) + ".hcv";
    }

    return "$videoPath.hcv";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV Import"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),

              const SizedBox(height: 24),

              Text(
                status,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              if (isVerified != null)
                Text(
                  isVerified! ? "HUMAN VERIFIED ✔" : "NOT VERIFIED ❌",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: isVerified! ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}