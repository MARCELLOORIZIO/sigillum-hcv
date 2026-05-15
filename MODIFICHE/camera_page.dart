import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'hcv_engine.dart';
import 'hcv_verifier.dart';
import 'hcv_package.dart';
import 'hcv_registry_service.dart';
import 'hcv_live_signals.dart';
import 'hcv_trust_analyzer.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  List<CameraDescription>? cameras;

  final verifier = HCVVerifier();
  final registry = const HCVRegistryService();

  final liveSignals = HCVLiveSignals();
  Map<String, dynamic>? lastLiveSignals;

  bool ready = false;
  bool recording = false;

  String status = 'INIT';
  String? result;

  String? videoPath;
  String? hcvPath;
  String? packagePath;
  String? hcvId;
  String? verificationUrl;
  String? registryStatus;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();

      if (cameras == null || cameras!.isEmpty) {
        setState(() => status = 'NO CAMERA');
        return;
      }

      controller = CameraController(
        cameras!.first,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await controller!.initialize();

      setState(() {
        ready = true;
        status = 'READY ✔';
      });
    } catch (e) {
      setState(() => status = 'ERROR: $e');
    }
  }

  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    setState(() {
      recording = true;
      status = 'STARTING...';
      result = null;
      videoPath = null;
      hcvPath = null;
      packagePath = null;
      hcvId = null;
      verificationUrl = null;
      registryStatus = null;
    });

    try {
      await controller!.startVideoRecording();

      try {
        await liveSignals.start();
      } catch (_) {
        lastLiveSignals = null;
      }

      setState(() => status = 'RECORDING...');
    } catch (e) {
      setState(() {
        recording = false;
        status = 'ERROR START: $e';
      });
    }
  }

  Future<void> stop() async {
    if (controller == null || !controller!.value.isRecordingVideo) return;

    try {
      final video = await controller!.stopVideoRecording();
      try {
        lastLiveSignals = await liveSignals.stopAndBuildSummary();
      } catch (_) {
        lastLiveSignals = null;
      }

      await processVideo(video.path);
    } catch (e) {
      setState(() {
        recording = false;
        status = 'EMULATOR CAMERA ERROR → usa TEST';
      });
    }
  }

  Directory _downloadsDirectory() {
    return Directory('/storage/emulated/0/Download');
  }

  Future<void> _ensureDownloadsDirectory() async {
    final dir = _downloadsDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<String> saveVideoToDownloadsTemporary(String sourcePath) async {
    await _ensureDownloadsDirectory();

    final sourceFile = File(sourcePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final savedPath = p.join(
      _downloadsDirectory().path,
      'hcv_video_$timestamp.mp4',
    );

    final savedFile = await sourceFile.copy(savedPath);
    return savedFile.path;
  }

  Future<String> renameVideoWithHcvId({
    required String currentPath,
    required String hcvId,
  }) async {
    await _ensureDownloadsDirectory();

    final currentFile = File(currentPath);
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final newPath = p.join(
      _downloadsDirectory().path,
      'hcv_video_$safeId.mp4',
    );

    final newFile = File(newPath);

    if (await newFile.exists()) {
      await newFile.delete();
    }

    final renamed = await currentFile.rename(newPath);
    return renamed.path;
  }

  Future<String> moveHcvToUnifiedName({
    required String currentPath,
    required String hcvId,
  }) async {
    await _ensureDownloadsDirectory();

    final currentFile = File(currentPath);
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final newPath = p.join(
      _downloadsDirectory().path,
      'hcv_video_$safeId.hcv',
    );

    final newFile = File(newPath);

    if (await newFile.exists()) {
      await newFile.delete();
    }

    final moved = await currentFile.copy(newPath);

    try {
      if (currentFile.path != moved.path && await currentFile.exists()) {
        await currentFile.delete();
      }
    } catch (_) {}

    return moved.path;
  }

  Future<String> movePackageToUnifiedName({
    required String currentPath,
    required String hcvId,
  }) async {
    await _ensureDownloadsDirectory();

    final currentFile = File(currentPath);
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final newPath = p.join(
      _downloadsDirectory().path,
      'hcv_video_$safeId.hcvpack',
    );

    final newFile = File(newPath);

    if (await newFile.exists()) {
      await newFile.delete();
    }

    final moved = await currentFile.copy(newPath);

    try {
      if (currentFile.path != moved.path && await currentFile.exists()) {
        await currentFile.delete();
      }
    } catch (_) {}

    return moved.path;
  }

  Future<void> processVideo(String path) async {
    setState(() {
      status = 'SAVING MP4 TO DOWNLOAD...';
      registryStatus = null;
    });

    String savedVideoPath = await saveVideoToDownloadsTemporary(path);

    setState(() {
      status = 'CREATING HCV CERTIFICATE...';
      videoPath = savedVideoPath;
    });

    final videoFile = File(savedVideoPath);
    final videoBytes = await videoFile.readAsBytes();
    final videoHash = sha256.convert(videoBytes).toString();

    final engine = HCVEngine();
    engine.start();

    engine.setContent(
      type: 'video',
      hash: videoHash,
      size: videoBytes.length,
      name: p.basename(savedVideoPath),
    );

    final trustAnalysis = HCVTrustAnalyzer.analyze(
      liveSignals: lastLiveSignals,
      audioCaptured: true,
    );

    engine.setClaims({
      "fileIntegrity": "VERIFIED",
      "captureSource": "HCV_CAMERA",
      "liveCapture": true,
      "liveCaptureMode": "PASSIVE",
      "audioCaptured": true,
      "audioIncludedInVideoContainer": true,
      "sensorIntegrity": lastLiveSignals == null ? "NOT_RECORDED" : "RECORDED",
      "screenReplayRisk": "REDUCED",
      "syntheticRisk": "REDUCED",
      "sceneAuthenticity": "LIVE_CAPTURE",
      "aiProofLevel": "PASSIVE_LIVE_CAPTURE_V1",
      "trustLevel": "HCV_LIVE",
      "liveCaptureTrust": trustAnalysis["liveCaptureTrust"],
      "audioTrust": trustAnalysis["audioTrust"],
    });

    if (lastLiveSignals != null) {
      engine.setLiveSignals(lastLiveSignals!);
    }

    engine.stop();

    String hcv = await engine.exportToFile();
    final ok = await verifier.verifyFile(hcv);

    String? pack;
    String? detectedId;
    String? detectedUrl;

    try {
      final data = jsonDecode(await File(hcv).readAsString());
      if (data is Map<String, dynamic>) {
        final meta = data['meta'];
        if (meta is Map) {
          detectedId = meta['hcvId']?.toString();
          detectedUrl = meta['verificationUrl']?.toString();
        }
      }
    } catch (_) {}

    if (detectedId != null && detectedId!.isNotEmpty) {
      try {
        savedVideoPath = await renameVideoWithHcvId(
          currentPath: savedVideoPath,
          hcvId: detectedId!,
        );

        hcv = await moveHcvToUnifiedName(
          currentPath: hcv,
          hcvId: detectedId!,
        );
      } catch (_) {}
    }

    if (ok) {
      final packer = HCVPackage();
      pack = await packer.createPackage(
        videoPath: savedVideoPath,
        hcvPath: hcv,
      );

      if (detectedId != null && detectedId!.isNotEmpty && pack != null) {
        try {
          pack = await movePackageToUnifiedName(
            currentPath: pack,
            hcvId: detectedId!,
          );
        } catch (_) {}
      }
    }

    setState(() {
      recording = false;
      videoPath = savedVideoPath;
      hcvPath = hcv;
      packagePath = pack;
      hcvId = detectedId;
      verificationUrl = detectedUrl;
      result = ok ? 'VALID ✔' : 'INVALID ❌';
      status = 'DONE';
    });

    if (ok) {
      await uploadCertificateToRegistry();
    }
  }

  Future<void> uploadCertificateToRegistry() async {
    if (hcvPath == null) return;

    setState(() {
      registryStatus = 'Uploading certificate to registry...';
    });

    try {
      final res = await registry.uploadCertificateFile(hcvPath!);
      setState(() {
        registryStatus = 'Registry OK: ${res['hcvId'] ?? hcvId}';
      });
    } catch (e) {
      setState(() {
        registryStatus = 'Registry offline/non raggiungibile: $e';
      });
    }
  }

  Future<void> fakeTest() async {
    try {
      final temp = File('${Directory.systemTemp.path}/fake_video.mp4');
      await temp.writeAsString('HCV TEST VIDEO DATA ${DateTime.now()}');
      await processVideo(temp.path);
    } catch (e) {
      setState(() => status = 'ERROR TEST: $e');
    }
  }

  Future<void> copyVerificationLink() async {
    final text = hcvId ?? verificationUrl;
    if (text == null) return;

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HCV-ID copiato')),
    );
  }

  Future<void> shareVideoAndCertificate() async {
    if (videoPath == null || hcvPath == null) return;

    final shareText = hcvId == null
        ? 'HCV Human Verified ✔'
        : 'HCV Human Verified ✔\nID: $hcvId\nVerify with HCV App';

    await Share.shareXFiles(
      [XFile(videoPath!), XFile(hcvPath!)],
      text: shareText,
    );
  }

  Future<void> sharePackage() async {
    if (packagePath == null) return;

    final shareText = hcvId == null
        ? 'HCV Human Verified ✔'
        : 'HCV Human Verified ✔\nID: $hcvId\nOffline package';

    await Share.shareXFiles(
      [XFile(packagePath!)],
      text: shareText,
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Widget _statusBadge() {
    if (result == null) {
      return Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
      );
    }

    final verified = result == 'VALID ✔';

    return Column(
      children: [
        Icon(
          verified ? Icons.verified : Icons.error,
          size: 64,
          color: verified ? Colors.green : Colors.red,
        ),
        const SizedBox(height: 8),
        Text(
          verified ? 'HUMAN VERIFIED ✔' : 'NOT VERIFIED ❌',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: verified ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _verifiedCard() {
    if (hcvId == null && verificationUrl == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Video verificabile creato',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'HCV-ID:\n${hcvId ?? '-'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'MP4, certificato HCV e HCVPACK usano lo stesso nome base. '
              'La verifica online usa HCV-ID e Registry.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: copyVerificationLink,
              icon: const Icon(Icons.copy),
              label: const Text('COPIA HCV-ID'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _registryCard() {
    if (registryStatus == null) {
      return const SizedBox.shrink();
    }

    final ok = registryStatus!.startsWith('Registry OK');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        registryStatus!,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: ok ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _createdFilesCard() {
    if (videoPath == null && hcvPath == null && packagePath == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Text(
              'File creati',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (videoPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'MP4:\n$videoPath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
            if (hcvPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Certificato:\n$hcvPath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
            if (packagePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'HCVPACK:\n$packagePath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButtons() {
    return Column(
      children: [
        if (videoPath != null && hcvPath != null) ...[
          SizedBox(
            width: 300,
            child: ElevatedButton.icon(
              onPressed: shareVideoAndCertificate,
              icon: const Icon(Icons.share),
              label: const Text('CONDIVIDI VIDEO VERIFICABILE'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (packagePath != null) ...[
          SizedBox(
            width: 300,
            child: ElevatedButton.icon(
              onPressed: sharePackage,
              icon: const Icon(Icons.inventory_2),
              label: const Text('CONDIVIDI PACCHETTO OFFLINE'),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ok = controller != null && controller!.value.isInitialized;

    return Scaffold(
      appBar: AppBar(title: const Text('Crea video HCV')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _statusBadge(),
              const SizedBox(height: 20),
              if (ok && result == null)
                SizedBox(
                  width: 300,
                  height: 170,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CameraPreview(controller!),
                  ),
                ),
              if (result == null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 260,
                  child: ElevatedButton.icon(
                    onPressed: !ready ? null : (recording ? stop : start),
                    icon: Icon(recording ? Icons.stop : Icons.videocam),
                    label: Text(
                      recording ? 'STOP REGISTRAZIONE' : 'REGISTRA VIDEO',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 260,
                  child: OutlinedButton.icon(
                    onPressed: fakeTest,
                    icon: const Icon(Icons.science),
                    label: const Text('TEST HCV'),
                  ),
                ),
              ],
              _verifiedCard(),
              _registryCard(),
              _actionButtons(),
              _createdFilesCard(),
              if (result != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 260,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        status = 'READY ✔';
                        result = null;
                        videoPath = null;
                        hcvPath = null;
                        packagePath = null;
                        hcvId = null;
                        verificationUrl = null;
                        registryStatus = null;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('CREA NUOVO VIDEO'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
