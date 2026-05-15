import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'hcv_engine.dart';
import 'hcv_verifier.dart';
import 'hcv_package.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  List<CameraDescription>? cameras;

  final verifier = HCVVerifier();

  bool ready = false;
  bool recording = false;

  String status = "INIT";
  String? result;

  String? videoPath;
  String? hcvPath;
  String? packagePath;

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

  // 🔴 START FIXATO
  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;

    if (controller!.value.isRecordingVideo) return;

    setState(() {
      recording = true;
      status = "STARTING...";
      result = null;
      videoPath = null;
      hcvPath = null;
      packagePath = null;
    });

    try {
      await controller!.startVideoRecording();

      setState(() {
        status = "RECORDING...";
      });
    } catch (e) {
      setState(() {
        recording = false;
        status = "ERROR START: $e";
      });
    }
  }

  // 🔴 STOP SICURO (non crasha su emulator)
  Future<void> stop() async {
    if (controller == null || !controller!.value.isRecordingVideo) return;

    try {
      final video = await controller!.stopVideoRecording();
      videoPath = video.path;

      await processVideo(videoPath!);
    } catch (e) {
      // 👉 fallback emulator
      setState(() {
        recording = false;
        status = "EMULATOR CAMERA ERROR → usa TEST";
      });
    }
  }

  // 🔥 CORE HCV (riusabile)
  Future<void> processVideo(String path) async {
    final videoFile = File(path);
    final videoBytes = await videoFile.readAsBytes();
    final videoHash = sha256.convert(videoBytes).toString();

    final engine = HCVEngine();
    engine.start();

    engine.setContent(
      type: "video",
      hash: videoHash,
      size: videoBytes.length,
      name: p.basename(path),
    );

    engine.stop();

    final hcv = await engine.exportToFile();
    final ok = await verifier.verifyFile(hcv);

    String? pack;

    if (ok) {
      final packer = HCVPackage();
      pack = await packer.createPackage(
        videoPath: path,
        hcvPath: hcv,
      );
    }

    setState(() {
      recording = false;
      videoPath = path;
      hcvPath = hcv;
      packagePath = pack;
      result = ok ? "VALID ✔" : "INVALID ❌";
      status = "DONE";
    });
  }

  // 🔥 TEST SENZA CAMERA (fondamentale su emulator)
  Future<void> fakeTest() async {
    try {
      final temp = File(
        "${Directory.systemTemp.path}/fake_video.txt",
      );

      await temp.writeAsString("HCV TEST VIDEO DATA");

      await processVideo(temp.path);
    } catch (e) {
      setState(() {
        status = "ERROR TEST: $e";
      });
    }
  }

  Future<void> sharePackage() async {
    if (packagePath == null) return;

    await Share.shareXFiles(
      [XFile(packagePath!)],
      text: "HCV Human Verified ✔",
    );
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
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(status),

              const SizedBox(height: 20),

              if (ok)
                SizedBox(
                  width: 300,
                  height: 150,
                  child: CameraPreview(controller!),
                ),

              const SizedBox(height: 20),

              if (result != null)
                Text(result!, style: const TextStyle(fontSize: 20)),

              if (packagePath != null) ...[
                const SizedBox(height: 10),
                Text("PACKAGE:\n$packagePath"),
                ElevatedButton(
                  onPressed: sharePackage,
                  child: const Text("CONDIVIDI HCVPACK"),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: !ready ? null : (recording ? stop : start),
                child: Text(recording ? "STOP" : "START"),
              ),

              const SizedBox(height: 10),

              // 🔥 bottone test
              ElevatedButton(
                onPressed: fakeTest,
                child: const Text("TEST HCV (NO CAMERA)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}