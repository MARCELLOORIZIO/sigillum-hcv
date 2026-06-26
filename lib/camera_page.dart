import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'hcv_social_fingerprint.dart';
import 'hcv_image_watermark.dart';
import 'hcv_screen_replay_analyzer.dart';
import 'hcv_live_screen_probe.dart';
import 'hcv_ml_screen_replay_classifier.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({
    super.key,
    this.initialPhotoMode = false,
  });

  final bool initialPhotoMode;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  List<CameraDescription>? cameras;

  int selectedCameraIndex = 0;

  final verifier = HCVVerifier();
  final registry = const HCVRegistryService();
  static const MethodChannel _mediaChannel = MethodChannel('hcv.media');

  final liveSignals = HCVLiveSignals();
  Map<String, dynamic>? lastLiveSignals;
  Map<String, dynamic>? pendingLiveScreenProbe;

  bool ready = false;
  bool recording = false;

  bool photoMode = false;
  String captureMode = 'studio';

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
  String? createdContentKind;

  @override
  void initState() {
    super.initState();
    photoMode = widget.initialPhotoMode;
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
        status = 'READY';
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
      status = 'CHECKING LIVE SCREEN FLICKER...';
      result = null;
      videoPath = null;
      hcvPath = null;
      packagePath = null;
      hcvId = null;
      verificationUrl = null;
      registryStatus = null;
    });

    try {
      pendingLiveScreenProbe = await HCVLiveScreenProbe().analyzePreview(
        controller!,
        restoreZoomLevel: currentZoom,
      );

      setState(() {
        recording = true;
        status = 'STARTING...';
      });

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
    if (controller == null) return;

    try {
      final file = await controller!.stopVideoRecording();

      setState(() {
        recording = false;
        status = 'PROCESSING VIDEO...';
      });

      await processVideo(file.path);
    } catch (e) {
      setState(() {
        status = 'STOP ERROR: $e';
      });
    }
  }

  Future<void> takePhoto() async {
    if (controller == null) return;

    try {
      setState(() {
        status = 'CHECKING LIVE SCREEN FLICKER...';
      });

      final liveScreenProbe = await HCVLiveScreenProbe().analyzePreview(
        controller!,
        restoreZoomLevel: currentZoom,
      );

      setState(() {
        status = 'SCATTO FOTO...';
      });

      final file = await controller!.takePicture();

      final savedPhotoPath = await savePhotoToDocuments(file.path);

      final engine = HCVEngine();

      engine.start();

      final preparedHcvId = engine.hcvId;

      final preparedVerificationUrl = "hcv://verify/$preparedHcvId";

      Map<String, dynamic>? socialFingerprint;
      Map<String, dynamic>? screenReplayAnalysis;
      Map<String, dynamic>? mlScreenReplayAnalysis;

      setState(() {
        hcvId = preparedHcvId;
        verificationUrl = preparedVerificationUrl;
        status = 'ANALYZING SCREEN REPLAY RISK...';
      });

      try {
        screenReplayAnalysis =
            await HCVScreenReplayAnalyzer().analyzeImage(savedPhotoPath);
      } catch (_) {
        screenReplayAnalysis = null;
      }

      try {
        mlScreenReplayAnalysis =
            await HCVMLScreenReplayClassifier.instance.analyzeImage(
          savedPhotoPath,
        );
      } catch (e) {
        mlScreenReplayAnalysis = {
          'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
          'screenReplayRisk': 'UNKNOWN',
          'screenReplayRiskScore': null,
          'reason': 'ML_ANALYSIS_EXCEPTION',
          'analysisStatus': 'NOT_ANALYZED',
          'error': e.toString(),
        };
      }

      final screenReplayAnalyses = [
        liveScreenProbe,
        screenReplayAnalysis,
        mlScreenReplayAnalysis,
      ];
      final detectedScreenReplayRisk =
          _combinedScreenReplayRisk(screenReplayAnalyses);
      final detectedScreenReplay = detectedScreenReplayRisk == "HIGH" ||
          detectedScreenReplayRisk == "MEDIUM";
      final detectedScreenReplayScore =
          _combinedScreenReplayScore(screenReplayAnalyses);

      setState(() {
        status = 'ADDING SIGILLUM WATERMARK...';
      });

      final publishedPhoto = await HCVImageWatermark().createPublishedPhoto(
        inputPath: savedPhotoPath,
        hcvId: preparedHcvId,
        screenReplayLabel: _screenReplayWatermarkLabel(
          detectedScreenReplayRisk,
          detectedScreenReplayScore,
          mlScreenReplayAnalysis,
        ),
      );

      try {
        if (savedPhotoPath != publishedPhoto &&
            await File(savedPhotoPath).exists()) {
          await File(savedPhotoPath).delete();
        }
      } catch (_) {}

      final fileBytes = await File(publishedPhoto).readAsBytes();

      final hash = sha256.convert(fileBytes).toString();

      try {
        socialFingerprint =
            await HCVSocialFingerprint().buildFromImage(publishedPhoto);
      } catch (_) {
        socialFingerprint = null;
      }

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
        "liveCapture": true,
        "liveCaptureMode": "STILL_CAPTURE",
        "liveCaptureTrust": "PHOTO_CAPTURE",
        "syntheticRisk":
            detectedScreenReplay ? "POSSIBLE_SCREEN_REPLAY" : "UNKNOWN",
        "sceneAuthenticity": detectedScreenReplay
            ? "PHOTO_CAPTURE_WITH_SCREEN_REPLAY_RISK"
            : "PHOTO_CAPTURE",
        "aiProofLevel": "STILL_IMAGE_CAPTURE_V1",
        "liveScreenProbe": liveScreenProbe,
        "screenReplayAnalysis": screenReplayAnalysis,
        "mlScreenReplayAnalysis": mlScreenReplayAnalysis,
        "mlScreenReplayAnalysisStatus":
            _mlAnalysisStatus(mlScreenReplayAnalysis),
        "screenReplayRisk": detectedScreenReplayRisk ?? "UNKNOWN",
        "screenReplayRiskScore": detectedScreenReplayScore,
        "watermark": "SIGILLUM_VISIBLE",
        "socialVerification": true,
        "socialFingerprintAlgorithm": socialFingerprint?["algorithm"],
        "socialFingerprint": socialFingerprint,
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
        pack = await movePackageToUnifiedName(
          currentPath: pack,
          hcvId: preparedHcvId,
        );
      }

      setState(() {
        result = ok ? 'VALID' : 'INVALID';

        status = ok ? 'PHOTO VERIFIED' : 'PHOTO INVALID';

        videoPath = publishedPhoto;
        hcvPath = hcv;
        packagePath = pack;
        createdContentKind = 'photo';

        recording = false;
      });
      if (ok) {
        await saveContentToGallery(publishedPhoto);
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

  String? _strongestScreenReplayRisk(List<Map<String, dynamic>?> analyses) {
    var score = -1;
    String? risk;

    for (final analysis in analyses) {
      if (analysis == null) continue;

      final currentRisk = analysis["screenReplayRisk"]?.toString();
      final currentScore = (analysis["screenReplayRiskScore"] as num?)?.toInt();

      if (currentScore != null && currentScore > score) {
        score = currentScore;
        risk = currentRisk;
      }
    }

    return risk;
  }

  int? _strongestScreenReplayScore(List<Map<String, dynamic>?> analyses) {
    int? score;

    for (final analysis in analyses) {
      if (analysis == null) continue;

      final currentScore = (analysis["screenReplayRiskScore"] as num?)?.toInt();
      if (currentScore == null) continue;

      if (score == null || currentScore > score) {
        score = currentScore;
      }
    }

    return score;
  }

  String? _combinedScreenReplayRisk(List<Map<String, dynamic>?> analyses) {
    final score = _combinedScreenReplayScore(analyses);
    if (score == null) return null;

    return score >= 80
        ? "HIGH"
        : score >= 55
            ? "MEDIUM"
            : "LOW";
  }

  int? _combinedScreenReplayScore(List<Map<String, dynamic>?> analyses) {
    final strongestScore = _strongestScreenReplayScore(analyses);
    Map<String, dynamic>? mlAnalysis;
    for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
      if (analysis["type"] == "SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1") {
        mlAnalysis = analysis;
        break;
      }
    }

    if (mlAnalysis == null) return strongestScore;

    final mlScore = (mlAnalysis["screenReplayRiskScore"] as num?)?.toInt();
    final mlClass = mlAnalysis["predictedClass"]?.toString();
    final nonMlScores = analyses
        .whereType<Map<String, dynamic>>()
        .where((analysis) =>
            analysis["type"] != "SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1")
        .map((analysis) => (analysis["screenReplayRiskScore"] as num?)?.toInt())
        .whereType<int>()
        .toList();
    final strongestNonMl =
        nonMlScores.isEmpty ? null : nonMlScores.reduce((a, b) => max(a, b));
    final mlSaysScreen =
        mlClass != null && mlClass.startsWith("SCREEN_") && mlScore != null;
    final mlSaysReality =
        mlClass != null && mlClass.startsWith("REALITY_") && mlScore != null;

    if (mlScore == null) {
      return strongestScore == null ? null : min(strongestScore, 34);
    }

    if (mlSaysReality) {
      if (strongestNonMl == null || strongestNonMl < 80 || mlScore < 55) {
        return max(min(mlScore, 34), min(strongestNonMl ?? 0, 34));
      }

      return min(strongestScore ?? mlScore, 54);
    }

    if (mlSaysScreen && mlScore < 80) {
      if (strongestNonMl == null || strongestNonMl < 35) {
        return max(strongestNonMl ?? 0, min(mlScore, 34));
      }
    }

    return strongestScore;
  }

  String _mlAnalysisStatus(Map<String, dynamic>? analysis) {
    if (analysis == null) return "NOT_ANALYZED";
    final status = analysis["analysisStatus"]?.toString();
    if (status != null && status.isNotEmpty) return status;
    final score = analysis["screenReplayRiskScore"];
    return score == null ? "NOT_ANALYZED" : "ANALYZED";
  }

  bool _mlNotAnalyzed(Map<String, dynamic>? analysis) {
    return _mlAnalysisStatus(analysis) == "NOT_ANALYZED";
  }

  String _screenReplayWatermarkLabel(
    String? risk,
    int? score, [
    Map<String, dynamic>? mlAnalysis,
  ]) {
    if (_mlNotAnalyzed(mlAnalysis)) {
      final optical = score == null ? "UNKNOWN" : "OPTICAL / $score";
      return "ML NOT ANALYZED: $optical";
    }

    final normalizedRisk = risk?.toUpperCase();
    if (normalizedRisk == "HIGH" || normalizedRisk == "MEDIUM") {
      final suffix =
          score == null ? normalizedRisk : "$normalizedRisk / $score";
      return "SCREEN RISK: $suffix";
    }

    if (normalizedRisk == "LOW") {
      final suffix = score == null ? "OK" : "OK / $score";
      return "REALITY CHECK: $suffix";
    }

    return "REALITY CHECK: NOT CONCLUSIVE";
  }

  Future<void> processVideo(String path) async {
    final liveScreenProbe = pendingLiveScreenProbe;
    pendingLiveScreenProbe = null;

    setState(() {
      status = 'SAVING MP4 TO DOWNLOAD...';
      registryStatus = null;
    });

    String savedVideoPath = await saveVideoToDownloadsTemporary(path);

    final engine = HCVEngine();
    engine.start();

    final preparedHcvId = engine.hcvId;
    final preparedVerificationUrl = "hcv://verify/$preparedHcvId";

    Map<String, dynamic>? socialFingerprint;
    Map<String, dynamic>? screenReplayAnalysis;
    Map<String, dynamic>? mlScreenReplayAnalysis;

    setState(() {
      status = 'ANALYZING SCREEN REPLAY RISK...';
      videoPath = savedVideoPath;
      hcvId = preparedHcvId;
      verificationUrl = preparedVerificationUrl;
    });

    try {
      screenReplayAnalysis =
          await HCVScreenReplayAnalyzer().analyzeVideo(savedVideoPath);
    } catch (_) {
      screenReplayAnalysis = null;
    }

    try {
      mlScreenReplayAnalysis =
          await HCVMLScreenReplayClassifier.instance.analyzeVideo(
        savedVideoPath,
      );
    } catch (e) {
      mlScreenReplayAnalysis = {
        'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
        'screenReplayRisk': 'UNKNOWN',
        'screenReplayRiskScore': null,
        'reason': 'VIDEO_ML_ANALYSIS_EXCEPTION',
        'analysisStatus': 'NOT_ANALYZED',
        'error': e.toString(),
      };
    }

    final trustAnalysis = HCVTrustAnalyzer.analyze(
      liveSignals: lastLiveSignals,
      audioCaptured: true,
      captureMode: captureMode,
    );
    final screenReplayAnalyses = [
      liveScreenProbe,
      screenReplayAnalysis,
      mlScreenReplayAnalysis,
    ];
    final detectedScreenReplayRisk =
        _combinedScreenReplayRisk(screenReplayAnalyses);
    final detectedScreenReplay = detectedScreenReplayRisk == "HIGH" ||
        detectedScreenReplayRisk == "MEDIUM";
    final detectedScreenReplayScore =
        _combinedScreenReplayScore(screenReplayAnalyses);

    setState(() {
      status = 'ADDING SIGILLUM LOGO...';
    });

    final originalVideoBeforeWatermark = savedVideoPath;

    try {
      savedVideoPath = await HCVVideoWatermark().createPublishedVideo(
        inputPath: savedVideoPath,
        hcvId: preparedHcvId,
        verificationUrl: preparedVerificationUrl,
        screenReplayLabel: _screenReplayWatermarkLabel(
          detectedScreenReplayRisk,
          detectedScreenReplayScore,
          mlScreenReplayAnalysis,
        ),
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

    engine.setClaims({
      "fileIntegrity": "VERIFIED",
      "captureSource": "HCV_CAMERA",
      "captureMode": captureMode,
      "liveCapture": true,
      "liveCaptureMode": "PASSIVE",
      "audioCaptured": true,
      "audioIncludedInVideoContainer": true,
      "sensorIntegrity": lastLiveSignals == null ? "NOT_RECORDED" : "RECORDED",
      "syntheticRisk":
          detectedScreenReplay ? "POSSIBLE_SCREEN_REPLAY" : "REDUCED",
      "sceneAuthenticity": detectedScreenReplay
          ? "LIVE_CAPTURE_WITH_SCREEN_REPLAY_RISK"
          : "LIVE_CAPTURE",
      "aiProofLevel": "PASSIVE_LIVE_CAPTURE_V1",
      "trustLevel": trustAnalysis["trustLevel"],
      "liveCaptureTrust": trustAnalysis["liveCaptureTrust"],
      "passiveLiveProofScore": trustAnalysis["score"],
      "captureModeNote": trustAnalysis["note"],
      "liveScreenProbe": liveScreenProbe,
      "screenReplayAnalysis": screenReplayAnalysis,
      "mlScreenReplayAnalysis": mlScreenReplayAnalysis,
      "mlScreenReplayAnalysisStatus": _mlAnalysisStatus(mlScreenReplayAnalysis),
      "screenReplayRisk":
          detectedScreenReplayRisk ?? trustAnalysis["screenReplayRisk"],
      "screenReplayRiskScore": detectedScreenReplayScore,
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

    if (detectedId.isNotEmpty) {
      try {
        savedVideoPath = await renameVideoWithHcvId(
          currentPath: savedVideoPath,
          hcvId: detectedId,
        );

        hcv = await moveHcvToUnifiedName(
          currentPath: hcv,
          hcvId: detectedId,
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
      print(await File(pack).exists());

      if (detectedId.isNotEmpty) {
        try {
          pack = await movePackageToUnifiedName(
            currentPath: pack,
            hcvId: detectedId,
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
      createdContentKind = 'video';
      result = ok ? 'VALID' : 'INVALID';
      status = 'DONE';
    });

    if (ok) {
      await saveContentToGallery(savedVideoPath);
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
          XFile(videoPath!, mimeType: _contentMimeType(videoPath!)),
        ],
        text: hcvId == null
            ? 'Contenuto verificato SIGILLUM'
            : 'Contenuto verificato SIGILLUM\nID: $hcvId\nVerify with SIGILLUM',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      setState(() => status = 'SHARE ERROR: $e');
    }
  }

  Future<void> saveContentToGallery(String path) async {
    if (!Platform.isIOS) {
      return;
    }

    try {
      final saved = await _mediaChannel.invokeMethod<bool>(
        'saveToPhotos',
        {'path': path},
      );

      if (saved == true && mounted) {
        setState(() {
          registryStatus = registryStatus == null
              ? 'Salvato anche in Foto'
              : '$registryStatus\nSalvato anche in Foto';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          registryStatus = registryStatus == null
              ? 'Non salvato in Foto: permesso non disponibile'
              : '$registryStatus\nNon salvato in Foto: permesso non disponibile';
        });
      }
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
            ? 'HCVPACK offline SIGILLUM'
            : 'HCVPACK offline SIGILLUM\nID: $hcvId',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      setState(() => status = 'SHARE PACK ERROR: $e');
    }
  }

  String get _createdContentLabel {
    if (createdContentKind == 'photo') return 'foto';
    if (createdContentKind == 'video') return 'video';
    return 'contenuto';
  }

  String get _createdFileLabel {
    if (createdContentKind == 'photo') return 'Foto';
    if (createdContentKind == 'video') return 'Video';
    return 'Contenuto';
  }

  String _contentMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'video/mp4';
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

    final verified = result == 'VALID';

    return Column(
      children: [
        Icon(
          verified ? Icons.verified : Icons.error,
          size: 64,
          color: verified ? Colors.green : Colors.red,
        ),
        const SizedBox(height: 8),
        Text(
          verified ? 'HUMAN VERIFIED' : 'NOT VERIFIED',
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
            Text(
              '${_createdFileLabel} verificabile creato',
              textAlign: TextAlign.center,
              style: const TextStyle(
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
            Text(
              '${_createdFileLabel}, certificato HCV e HCVPACK sono collegati dallo stesso HCV-ID. '
              'La verifica online usa HCV-ID e Registry.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
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
                '$_createdFileLabel:\n$videoPath',
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
              label: Text('CONDIVIDI ${_createdContentLabel.toUpperCase()}'),
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
              label: const Text('CONDIVIDI HCVPACK OFFLINE'),
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
                    bottom: 14,
                    top: 58,
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
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        child: photoMode
                            ? const SizedBox.shrink()
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ChoiceChip(
                                    label: const Text('STUDIO'),
                                    selected: captureMode == 'studio',
                                    showCheckmark: false,
                                    selectedColor:
                                        Colors.green.withValues(alpha: 0.28),
                                    backgroundColor:
                                        Colors.black.withValues(alpha: 0.62),
                                    side: BorderSide(
                                      color: captureMode == 'studio'
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                    ),
                                    labelStyle: TextStyle(
                                      color: captureMode == 'studio'
                                          ? Colors.greenAccent
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    onSelected: recording
                                        ? null
                                        : (_) {
                                            setState(() {
                                              captureMode = 'studio';
                                            });
                                          },
                                  ),
                                  const SizedBox(width: 14),
                                  ChoiceChip(
                                    label: const Text('FIELD'),
                                    selected: captureMode == 'field',
                                    showCheckmark: false,
                                    selectedColor:
                                        Colors.green.withValues(alpha: 0.28),
                                    backgroundColor:
                                        Colors.black.withValues(alpha: 0.62),
                                    side: BorderSide(
                                      color: captureMode == 'field'
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                    ),
                                    labelStyle: TextStyle(
                                      color: captureMode == 'field'
                                          ? Colors.greenAccent
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    onSelected: recording
                                        ? null
                                        : (_) {
                                            setState(() {
                                              captureMode = 'field';
                                            });
                                          },
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
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
                          width: recording ? 78 : 86,
                          height: recording ? 78 : 86,
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
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  )
                                : Icon(
                                    photoMode
                                        ? Icons.camera_alt
                                        : Icons.videocam,
                                    color: Colors.black,
                                    size: 34,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        recording
                            ? 'REGISTRAZIONE IN CORSO'
                            : photoMode
                                ? 'MODALITA FOTO'
                                : 'MODALITA VIDEO',
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
                                status = 'READY';
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
                              status = 'READY';
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
