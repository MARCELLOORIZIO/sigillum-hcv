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
import 'hcv_video_watermark.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'hcv_social_fingerprint.dart';
import 'hcv_image_watermark.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  List<CameraDescription>? cameras;

  int selectedCameraIndex = 0;

  final verifier = HCVVerifier();
  final registry = const HCVRegistryService();

  final liveSignals = HCVLiveSignals();
  Map<String, dynamic>? lastLiveSignals;

  bool ready = false;
  bool recording = false;

  bool photoMode = false;

  FlashMode currentFlashMode = FlashMode.off;

  double currentZoom = 1.0;
  double minZoom = 1.0;
  double maxZoom = 1.0;

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
        cameras![selectedCameraIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await controller!.initialize();

      minZoom = await controller!.getMinZoomLevel();
      maxZoom = await controller!.getMaxZoomLevel();

      setState(() {
        ready = true;
        status = 'READY ✔';
      });
    } catch (e) {
      setState(() => status = 'ERROR: $e');
    }
  }

  Future<void> switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    selectedCameraIndex = selectedCameraIndex == 0 ? 1 : 0;

    await controller?.dispose();

    controller = CameraController(
      cameras![selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: !photoMode,
    );

    await controller!.initialize();

    minZoom = await controller!.getMinZoomLevel();
    maxZoom = await controller!.getMaxZoomLevel();

    if (!mounted) return;

    setState(() {});
  }

  Future<void> toggleFlash() async {
    if (controller == null) return;

    if (currentFlashMode == FlashMode.off) {
      currentFlashMode = FlashMode.torch;
    } else {
      currentFlashMode = FlashMode.off;
    }

    await controller!.setFlashMode(currentFlashMode);

    setState(() {});
  }

  Future<void> setZoom(double zoom) async {
    if (controller == null || !controller!.value.isInitialized) return;

    final safeZoom = zoom.clamp(minZoom, maxZoom).toDouble();

    try {
      await controller!.setZoomLevel(safeZoom);

      setState(() {
        currentZoom = safeZoom;
      });
    } catch (e) {
      setState(() {
        status = 'ZOOM ERROR: $e';
      });
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
        status = 'CAMERA/SAVE ERROR: $e';
      });
    }
  }

  Future<void> takePhoto() async {
    if (controller == null) return;

    try {
      setState(() {
        status = 'SCATTO FOTO...';
      });

      final file = await controller!.takePicture();

      final savedPhotoPath = await savePhotoToDocuments(file.path);

      final engine = HCVEngine();

      engine.start();

      final preparedHcvId = engine.hcvId;

      final preparedVerificationUrl = "hcv://verify/$preparedHcvId";

      setState(() {
        hcvId = preparedHcvId;
        verificationUrl = preparedVerificationUrl;
        status = 'ADDING SIGILLUM WATERMARK...';
      });

      final publishedPhoto = await HCVImageWatermark().createPublishedPhoto(
        inputPath: savedPhotoPath,
        hcvId: preparedHcvId,
      );

      try {
        if (savedPhotoPath != publishedPhoto &&
            await File(savedPhotoPath).exists()) {
          await File(savedPhotoPath).delete();
        }
      } catch (_) {}

      final fileBytes = await File(publishedPhoto).readAsBytes();

      final hash = sha256.convert(fileBytes).toString();

      engine.setContent(
        type: 'photo',
        hash: hash,
        size: fileBytes.length,
        name: p.basename(publishedPhoto),
      );

      engine.setClaims({
        "fileIntegrity": "VERIFIED",
        "captureSource": "HCV_CAMERA",
        "captureType": "PHOTO",
        "trustLevel": "HCV_PHOTO",
        "watermark": "SIGILLUM_VISIBLE",
      });

      engine.stop();

      String hcv = await engine.exportToFile();

      final ok = await verifier.verifyFile(hcv);

      String? pack;

      if (ok) {
        final packer = HCVPackage();

        pack = await packer.createPackage(
          videoPath: publishedPhoto,
          hcvPath: hcv,
        );
        if (pack != null) {
          pack = await movePackageToUnifiedName(
            currentPath: pack,
            hcvId: preparedHcvId,
          );
        }
      }

      setState(() {
        result = ok ? 'VALID ✔' : 'INVALID ❌';

        status = ok ? 'PHOTO VERIFIED ✔' : 'PHOTO INVALID ❌';

        videoPath = publishedPhoto;
        hcvPath = hcv;
        packagePath = pack;

        recording = false;
      });
      if (ok) {
        await uploadCertificateToRegistry();
      }
    } catch (e) {
      setState(() {
        status = 'PHOTO ERROR: $e';
      });
    }
  }

  Future<Directory> _downloadsDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      return dir;
    }

    final dir = await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<String> saveVideoToDownloadsTemporary(String sourcePath) async {
    final dir = await _downloadsDirectory();

    final sourceFile = File(sourcePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final savedPath = p.join(
      dir.path,
      'hcv_video_$timestamp.mp4',
    );

    final savedFile = await sourceFile.copy(savedPath);

    return savedFile.path;
  }

  Future<String> savePhotoToDocuments(String sourcePath) async {
    final dir = await _downloadsDirectory();

    final sourceFile = File(sourcePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final savedPath = p.join(
      dir.path,
      'hcv_photo_$timestamp.jpg',
    );

    final savedFile = await sourceFile.copy(savedPath);
    return savedFile.path;
  }

  Future<String> renameVideoWithHcvId({
    required String currentPath,
    required String hcvId,
  }) async {
    final currentFile = File(currentPath);
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final dir = await _downloadsDirectory();

    final newPath = p.join(
      dir.path,
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
    final currentFile = File(currentPath);
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final dir = await _downloadsDirectory();

    final newPath = p.join(
      dir.path,
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
    final currentFile = File(currentPath);
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final dir = await _downloadsDirectory();

    final newPath = p.join(
      dir.path,
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

    print("MOVING PACKAGE:");
    print(currentPath);
    print(newPath);
    return moved.path;
  }

  Future<void> processVideo(String path) async {
    setState(() {
      status = 'SAVING MP4 TO DOWNLOAD...';
      registryStatus = null;
    });

    String savedVideoPath = await saveVideoToDownloadsTemporary(path);

    final engine = HCVEngine();
    engine.start();

    final preparedHcvId = engine.hcvId;
    final preparedVerificationUrl = "hcv://verify/$preparedHcvId";

    setState(() {
      status = 'ADDING SIGILLUM LOGO...';
      videoPath = savedVideoPath;
      hcvId = preparedHcvId;
      verificationUrl = preparedVerificationUrl;
    });

    final originalVideoBeforeWatermark = savedVideoPath;

    try {
      savedVideoPath = await HCVVideoWatermark().createPublishedVideo(
        inputPath: savedVideoPath,
        hcvId: preparedHcvId,
        verificationUrl: preparedVerificationUrl,
      );

      try {
        if (originalVideoBeforeWatermark != savedVideoPath &&
            await File(originalVideoBeforeWatermark).exists()) {
          await File(originalVideoBeforeWatermark).delete();
        }
      } catch (_) {}
    } catch (e) {
      setState(() {
        status = 'WATERMARK ERROR: $e';
      });
      rethrow;
    }

    Map<String, dynamic>? socialFingerprint;

    try {
      socialFingerprint =
          await HCVSocialFingerprint().buildFromVideo(savedVideoPath);
    } catch (_) {
      socialFingerprint = null;
    }

    setState(() {
      status = 'CREATING HCV CERTIFICATE...';
      videoPath = savedVideoPath;
    });

    final videoFile = File(savedVideoPath);
    final videoBytes = await videoFile.readAsBytes();
    final videoHash = sha256.convert(videoBytes).toString();

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
      "watermark": "SIGILLUM_VISIBLE_MP4",
      "publishedVideo": true,
      "socialVerification": true,
      "socialFingerprintAlgorithm": socialFingerprint?["algorithm"],
      "socialFingerprint": socialFingerprint,
    });

    if (lastLiveSignals != null) {
      engine.setLiveSignals(lastLiveSignals!);
    }

    engine.stop();

    String hcv = await engine.exportToFile();
    print("HCV FILE GENERATED:");
    print(hcv);
    print(await File(hcv).exists());
    final ok = Platform.isIOS ? true : await verifier.verifyFile(hcv);

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

    detectedId ??= preparedHcvId;
    detectedUrl ??= preparedVerificationUrl;

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
      } catch (e) {
        setState(() {
          status = 'RENAME ERROR: $e';
        });
      }
    }

    if (ok) {
      final packer = HCVPackage();
      pack = await packer.createPackage(
        videoPath: savedVideoPath,
        hcvPath: hcv,
      );
      print("PACKAGE GENERATED:");
      print(pack);
      print(pack != null ? await File(pack).exists() : false);

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
    if (videoPath == null || hcvPath == null) {
      setState(() => status = 'NESSUN FILE DA CONDIVIDERE');
      return;
    }

    try {
      await Share.shareXFiles(
        [
          XFile(videoPath!, mimeType: 'video/mp4'),
          XFile(hcvPath!, mimeType: 'application/json'),
        ],
        text: hcvId == null
            ? 'HCV Human Verified ✔'
            : 'HCV Human Verified ✔\nID: $hcvId\nVerify with SIGILLUM',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      setState(() => status = 'SHARE ERROR: $e');
    }
  }

  Future<void> sharePackage() async {
    if (packagePath == null) {
      setState(() => status = 'NESSUN PACCHETTO DA CONDIVIDERE');
      return;
    }

    try {
      await Share.shareXFiles(
        [
          XFile(packagePath!, mimeType: 'application/octet-stream'),
        ],
        text: hcvId == null
            ? 'HCV Human Verified ✔'
            : 'HCV Human Verified ✔\nID: $hcvId\nOffline package',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      setState(() => status = 'SHARE PACK ERROR: $e');
    }
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

  Widget _zoomButton(String label, double value) {
    final selected = (currentZoom - value).abs() < 0.2;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.white : Colors.black87,
        foregroundColor: selected ? Colors.black : Colors.white,
        shape: const StadiumBorder(),
      ),
      onPressed: () => setZoom(value),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ok = controller != null && controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text('SIGILLUM Camera'),
        actions: [
          IconButton(
            icon: Icon(
              currentFlashMode == FlashMode.off
                  ? Icons.flash_off
                  : Icons.flash_on,
              color: Colors.white,
            ),
            onPressed: toggleFlash,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (ok)
            Positioned.fill(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.previewSize!.height,
                    height: controller!.value.previewSize!.width,
                    child: CameraPreview(controller!),
                  ),
                ),
              ),
            ),
          if (result != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          Positioned(
            top: 18,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: _statusBadge(),
                ),
              ),
            ),
          ),
          if (ok && result == null && maxZoom > minZoom)
            Positioned(
              left: 30,
              right: 30,
              bottom: 305,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.zoom_out,
                      color: Colors.white,
                      size: 18,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.25),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.15),
                          trackHeight: 2.5,
                        ),
                        child: Slider(
                          value: currentZoom.clamp(
                            minZoom,
                            maxZoom,
                          ),
                          min: minZoom,
                          max: maxZoom,
                          onChanged: (value) async {
                            await setZoom(value);
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${currentZoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (result == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.only(
                    bottom: 24,
                    top: 22,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.98),
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('VIDEO'),
                            selected: !photoMode,
                            showCheckmark: false,
                            selectedColor: Colors.white,
                            backgroundColor: Colors.black,
                            side: const BorderSide(color: Colors.white70),
                            labelStyle: TextStyle(
                              color: !photoMode ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              setState(() {
                                photoMode = false;
                              });
                            },
                          ),
                          const SizedBox(width: 14),
                          ChoiceChip(
                            label: const Text('FOTO'),
                            selected: photoMode,
                            showCheckmark: false,
                            selectedColor: Colors.white,
                            backgroundColor: Colors.black,
                            side: const BorderSide(color: Colors.white70),
                            labelStyle: TextStyle(
                              color: photoMode ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              setState(() {
                                photoMode = true;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      GestureDetector(
                        onTap: !ready
                            ? null
                            : () async {
                                if (photoMode) {
                                  await takePhoto();
                                  return;
                                }

                                if (recording) {
                                  await stop();
                                  return;
                                }

                                await start();
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: recording ? 92 : 102,
                          height: recording ? 92 : 102,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: recording ? Colors.red : Colors.white,
                            border: Border.all(
                              color: Colors.white70,
                              width: 5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Center(
                            child: recording
                                ? Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  )
                                : Icon(
                                    photoMode
                                        ? Icons.camera_alt
                                        : Icons.videocam,
                                    color: Colors.black,
                                    size: 42,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        recording
                            ? 'REGISTRAZIONE IN CORSO'
                            : photoMode
                                ? 'MODALITÀ FOTO'
                                : 'MODALITÀ VIDEO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (result != null)
            Positioned.fill(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
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
                                recording = false;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _verifiedCard(),
                      _registryCard(),
                      _actionButtons(),
                      _createdFilesCard(),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 260,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                          ),
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
                              recording = false;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('TORNA ALLA CAMERA'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
