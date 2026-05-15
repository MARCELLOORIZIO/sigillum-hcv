import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:video_player/video_player.dart';

import 'hcv_verifier.dart';

class VideoPlayerVerifyPage extends StatefulWidget {
  const VideoPlayerVerifyPage({super.key});

  @override
  State<VideoPlayerVerifyPage> createState() =>
      _VideoPlayerVerifyPageState();
}

class _VideoPlayerVerifyPageState extends State<VideoPlayerVerifyPage> {
  final verifier = HCVVerifier();

  VideoPlayerController? _controller;

  String? videoPath;
  String? hcvPath;

  String status = "Seleziona video";
  String? result;

  Future<void> pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    _controller?.dispose();

    final controller = VideoPlayerController.file(File(path));

    await controller.initialize();

    setState(() {
      videoPath = path;
      _controller = controller;
      status = "Video caricato";
      result = null;
    });

    controller.play();
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
      status = "Certificato caricato";
    });

    await verify();
  }

  Future<void> verify() async {
    if (videoPath == null) return;

    try {
      setState(() {
        status = "Verifica...";
        result = null;
      });

      final videoFile = File(videoPath!);
      final videoBytes = await videoFile.readAsBytes();
      final videoHash = sha256.convert(videoBytes).toString();

      if (hcvPath == null) {
        setState(() {
          result = "NOT VERIFIED ❌";
          status = "Nessun certificato";
        });
        return;
      }

      final hcvFile = File(hcvPath!);
      final hcvJson = await hcvFile.readAsString();
      final data = jsonDecode(hcvJson);

      final hcvOk = await verifier.verifyFile(hcvPath!);

      if (!hcvOk) {
        setState(() {
          result = "INVALID CERT ❌";
          status = "Certificato non valido";
        });
        return;
      }

      final content = data["content"];

      if (content == null || content["type"] != "video") {
        setState(() {
          result = "NOT VERIFIED ❌";
          status = "HCV non compatibile";
        });
        return;
      }

      final storedHash = content["hash"];

      if (storedHash != videoHash) {
        setState(() {
          result = "TAMPERED ❌";
          status = "Video modificato";
        });
        return;
      }

      setState(() {
        result = "HUMAN VERIFIED ✔";
        status = "OK";
      });
    } catch (e) {
      setState(() {
        result = "ERROR ❌";
        status = "$e";
      });
    }
  }

  Widget buildBadge() {
    if (result == null) return const SizedBox();

    Color color;
    String text;

    if (result!.contains("VERIFIED")) {
      color = Colors.green;
      text = "HUMAN VERIFIED";
    } else {
      color = Colors.red;
      text = "NOT VERIFIED";
    }

    return Positioned(
      top: 40,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV Player"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _controller == null
                  ? const Text("Seleziona un video")
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio:
                              _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                        buildBadge(),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 10),

          Text(status),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: pickVideo,
            child: const Text("CARICA VIDEO"),
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: pickHCV,
            child: const Text("CARICA HCV"),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}