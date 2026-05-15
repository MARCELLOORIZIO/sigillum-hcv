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
  State<HCVPackPlayerPage> createState() =>
      _HCVPackPlayerPageState();
}

class _HCVPackPlayerPageState extends State<HCVPackPlayerPage> {
  final verifier = HCVVerifier();

  late final player = Player();
  late final controller = VideoController(player);

  String status = "Seleziona file .hcvpack";
  String? result;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();

    if (widget.initialPath != null) {
      Future.microtask(() => loadPackage(widget.initialPath!));
    }
  }

  Future<void> pickPack() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['hcvpack'],
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    await loadPackage(path);
  }

  Future<void> loadPackage(String packPath) async {
    try {
      setState(() {
        status = "Caricamento...";
        result = null;
      });

      final file = File(packPath);

      if (!await file.exists()) {
        setState(() {
          status = "File .hcvpack non trovato";
          result = "ERROR ❌";
        });
        return;
      }

      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr);

      if (data is! Map<String, dynamic>) {
        setState(() {
          status = "Formato .hcvpack non valido";
          result = "ERROR ❌";
        });
        return;
      }

      if (data["type"] != "HCV_PACKAGE") {
        setState(() {
          status = "Tipo package non valido";
          result = "ERROR ❌";
        });
        return;
      }

      final videoBase64 = data["video"];
      final certificate = data["certificate"];

      if (videoBase64 is! String || certificate is! Map<String, dynamic>) {
        setState(() {
          status = "Package incompleto";
          result = "ERROR ❌";
        });
        return;
      }

      final bytes = base64Decode(videoBase64);

      final tempFile = File(
        "${Directory.systemTemp.path}/temp_${DateTime.now().millisecondsSinceEpoch}.mp4",
      );

      await tempFile.writeAsBytes(bytes);

      // verifica
      final videoHash = sha256.convert(bytes).toString();

      final content = certificate["content"];

      if (content is! Map<String, dynamic>) {
        setState(() {
          status = "Certificato senza content";
          result = "INVALID ❌";
        });
        return;
      }

      final storedHash = content["hash"];

      if (storedHash is! String) {
        setState(() {
          status = "Certificato senza hash video";
          result = "INVALID ❌";
        });
        return;
      }

      final tempHcv = File(
        "${Directory.systemTemp.path}/temp_${DateTime.now().millisecondsSinceEpoch}.hcv",
      );

      await tempHcv.writeAsString(jsonEncode(certificate));

      final ok = await verifier.verifyFile(tempHcv.path);

      if (!ok) {
        setState(() {
          result = "INVALID ❌";
          status = "Certificato non valido";
        });
        return;
      }

      if (videoHash != storedHash) {
        setState(() {
          result = "TAMPERED ❌";
          status = "Video modificato";
        });
        return;
      }

      await player.open(Media(tempFile.path));

      setState(() {
        result = "HUMAN VERIFIED ✔";
        status = "OK";
      });
    } catch (e) {
      setState(() {
        status = "ERRORE: $e";
        result = "ERROR ❌";
      });
    }
  }

  Widget buildBadge() {
    if (result == null) return const SizedBox();

    final isOk = result == "HUMAN VERIFIED ✔";

    return Positioned(
      top: 40,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: (isOk ? Colors.green : Colors.red)
              .withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isOk ? "HUMAN VERIFIED" : "NOT VERIFIED",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                Video(controller: controller),
                buildBadge(),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Text(status),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: pickPack,
            child: const Text("APRI HCVPACK"),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
