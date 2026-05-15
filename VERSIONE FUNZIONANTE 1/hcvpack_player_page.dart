import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:crypto/crypto.dart';

import 'hcv_verifier.dart';

class HCVPackPlayerPage extends StatefulWidget {
  final String? initialPath;

  const HCVPackPlayerPage({
    super.key,
    this.initialPath,
  });

  @override
  State<HCVPackPlayerPage> createState() => _HCVPackPlayerPageState();
}

class _HCVPackPlayerPageState extends State<HCVPackPlayerPage> {
  final verifier = HCVVerifier();

  late final Player player;
  late final VideoController controller;

  String status = "Seleziona file .hcvpack";
  String? result;

  File? extractedVideoFile;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    MediaKit.ensureInitialized();

    player = Player();
    controller = VideoController(player);

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      Future.microtask(() => loadPackage(widget.initialPath!));
    }
  }

  Future<void> pickPack() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (res == null) return;

      final path = res.files.single.path;
      if (path == null) return;

      if (!path.toLowerCase().endsWith('.hcvpack')) {
        setState(() {
          status = "Seleziona un file .hcvpack";
          result = "ERROR ❌";
        });
        return;
      }

      await loadPackage(path);
    } catch (e) {
      setState(() {
        status = "Errore selezione file: $e";
        result = "ERROR ❌";
      });
    }
  }

  Future<void> loadPackage(String packPath) async {
    try {
      setState(() {
        loading = true;
        status = "Analisi HCVPACK...";
        result = null;
      });

      final file = File(packPath);

      if (!await file.exists()) {
        setState(() {
          loading = false;
          status = "File non trovato:\n$packPath";
          result = "ERROR ❌";
        });
        return;
      }

      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr);

      if (data is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          status = "Formato HCVPACK non valido";
          result = "ERROR ❌";
        });
        return;
      }

      final videoBase64 = data["video"];
      final certificate = data["certificate"];

      if (videoBase64 == null || certificate == null) {
        setState(() {
          loading = false;
          status = "HCVPACK incompleto";
          result = "ERROR ❌";
        });
        return;
      }

      if (videoBase64 is! String) {
        setState(() {
          loading = false;
          status = "Video HCVPACK non valido";
          result = "ERROR ❌";
        });
        return;
      }

      if (certificate is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          status = "Certificato HCV non valido";
          result = "ERROR ❌";
        });
        return;
      }

      final bytes = base64Decode(videoBase64);
      final videoHash = sha256.convert(bytes).toString();

      final content = certificate["content"];

      if (content == null || content is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          status = "Certificato HCV incompleto";
          result = "INVALID ❌";
        });
        return;
      }

      final storedHash = content["hash"];

      if (storedHash == null || storedHash is! String) {
        setState(() {
          loading = false;
          status = "Hash mancante nel certificato";
          result = "INVALID ❌";
        });
        return;
      }

      final tempVideoFile = File(
        "${Directory.systemTemp.path}/hcv_video_${DateTime.now().millisecondsSinceEpoch}.mp4",
      );

      await tempVideoFile.writeAsBytes(bytes);

      final tempHcvFile = File(
        "${Directory.systemTemp.path}/hcv_cert_${DateTime.now().millisecondsSinceEpoch}.hcv",
      );

      await tempHcvFile.writeAsString(jsonEncode(certificate));

      final certOk = await verifier.verifyFile(tempHcvFile.path);

      if (!certOk) {
        extractedVideoFile = tempVideoFile;

        await player.open(
          Media(tempVideoFile.path),
          play: true,
        );

        setState(() {
          loading = false;
          result = "INVALID ❌";
          status = "Certificato non valido";
        });
        return;
      }

      if (videoHash != storedHash) {
        extractedVideoFile = tempVideoFile;

        await player.open(
          Media(tempVideoFile.path),
          play: true,
        );

        setState(() {
          loading = false;
          result = "TAMPERED ❌";
          status = "Video modificato";
        });
        return;
      }

      extractedVideoFile = tempVideoFile;

      await player.open(
        Media(tempVideoFile.path),
        play: true,
      );

      setState(() {
        loading = false;
        result = "HUMAN VERIFIED ✔";
        status = "Verifica completata";
      });
    } catch (e) {
      setState(() {
        loading = false;
        status = "ERRORE: $e";
        result = "ERROR ❌";
      });
    }
  }

  bool get isVerified {
    return result == "HUMAN VERIFIED ✔";
  }

  bool get hasResult {
    return result != null;
  }

  Widget buildBadge() {
    if (!hasResult) return const SizedBox();

    return Positioned(
      top: 18,
      left: 16,
      right: 16,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: isVerified ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            isVerified ? "HUMAN VERIFIED" : "NOT VERIFIED",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLoadingOverlay() {
    if (!loading) return const SizedBox();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget buildStatusPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isVerified)
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),

            if (result != null) ...[
              const SizedBox(height: 6),
              Text(
                isVerified ? "HUMAN VERIFIED ✔" : "NOT VERIFIED ❌",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isVerified ? Colors.green : Colors.red,
                ),
              ),
            ],

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: loading ? null : pickPack,
              child: const Text("APRI HCVPACK"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    player.dispose();

    try {
      extractedVideoFile?.deleteSync();
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("HCV Pack Player"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Video(controller: controller),
                  ),
                ),

                if (hasResult) buildBadge(),

                buildLoadingOverlay(),
              ],
            ),
          ),

          buildStatusPanel(),
        ],
      ),
    );
  }
}