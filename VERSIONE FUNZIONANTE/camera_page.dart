import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'hcv_engine.dart';
import 'hcv_verifier.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  List<CameraDescription>? cameras;

  final engine = HCVEngine();
  final verifier = HCVVerifier();

  bool ready = false;
  bool recording = false;

  String status = "INIT";
  String? result;

  String? videoPath;
  String? hcvPath;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();

      if (cameras == null || cameras!.isEmpty) {
        setState(() => status = "NO CAMERA");
        return;
      }

      controller = CameraController(
        cameras!.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller!.initialize();

      setState(() {
        ready = true;
        status = "READY ✔";
      });
    } catch (e) {
      setState(() => status = "ERROR: $e");
    }
  }

  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;

    try {
      await controller!.startVideoRecording();

      engine.start();

      setState(() {
        recording = true;
        status = "RECORDING...";
        result = null;
        videoPath = null;
        hcvPath = null;
      });
    } catch (e) {
      setState(() {
        status = "ERROR START: $e";
      });
    }
  }

  Future<void> stop() async {
    if (controller == null || !controller!.value.isRecordingVideo) return;

    try {
      final video = await controller!.stopVideoRecording();
      videoPath = video.path;

      final videoFile = File(videoPath!);
      final videoBytes = await videoFile.readAsBytes();
      final videoHash = sha256.convert(videoBytes).toString();

      engine.setContent(
        type: "video",
        hash: videoHash,
        size: videoBytes.length,
        name: p.basename(videoPath!),
      );

      engine.stop();

      final path = await engine.exportToFile();
      final ok = await verifier.verifyFile(path);

      setState(() {
        recording = false;
        hcvPath = path;
        result = ok ? "VALID ✔" : "INVALID ❌";
        status = "STOPPED";
      });
    } catch (e) {
      setState(() {
        recording = false;
        status = "ERROR STOP: $e";
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = controller != null && controller!.value.isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status),

            const SizedBox(height: 20),

            if (ok)
              SizedBox(
                width: 300,
                height: 220,
                child: CameraPreview(controller!),
              )
            else if (status.startsWith("ERROR") || status == "NO CAMERA")
              Text(status)
            else
              const CircularProgressIndicator(),

            const SizedBox(height: 20),

            if (result != null)
              Text(result!, style: const TextStyle(fontSize: 20)),

            if (videoPath != null) ...[
              const SizedBox(height: 10),
              Text(
                "VIDEO:\n$videoPath",
                textAlign: TextAlign.center,
              ),
            ],

            if (hcvPath != null) ...[
              const SizedBox(height: 10),
              Text(
                "HCV:\n$hcvPath",
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: !ready ? null : (recording ? stop : start),
              child: Text(recording ? "STOP" : "START"),
            ),
          ],
        ),
      ),
    );
  }
}