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
import 'hcv_location_video_watermark.dart';

import 'package:path_provider/path_provider.dart';

import 'hcv_social_fingerprint.dart';
import 'hcv_location_image_watermark.dart';
import 'hcv_capture_location.dart';
import 'hcv_screen_replay_analyzer.dart';
import 'hcv_temporal_capture_probe.dart';
import 'hcv_ml_screen_replay_classifier.dart';
import 'hcv_display_risk_fusion.dart';
import 'hcv_capture_timestamp.dart';
import 'sigillum_localization.dart';
import 'camera_ui_extended_copy.dart';
import 'video_transcription_service.dart';
import 'sigillum_quick_guide_page.dart';

int _displayDecisionRank(String decision) {
  switch (decision) {
    case 'STRONG_DISPLAY_RISK':
      return 2;
    case 'NON_CONCLUSIVE':
      return 1;
    default:
      return 0;
  }
}

Map<String, dynamic>? _liveProbeFromAnalyses(
  List<Map<String, dynamic>?> analyses,
) {
  for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
    if (analysis['type'] == 'SIGILLUM_LIVE_SCREEN_PROBE_V1') {
      return analysis;
    }
  }
  return null;
}

Map<String, dynamic>? _mlAnalysisFromAnalyses(
  List<Map<String, dynamic>?> analyses,
) {
  for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
    if (analysis['type'] == 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1') {
      return analysis;
    }
  }
  return null;
}

bool _hasHardDisplayCorroboration(
  List<Map<String, dynamic>?> analyses,
) {
  for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
    final rawSignals = analysis['signals'];
    if (rawSignals is! Map) continue;
    if (rawSignals['confirmedDisplayTrace'] == true ||
        rawSignals['periodicLightTrace'] == true ||
        rawSignals['opticalCorroboratedTrace'] == true) {
      return true;
    }
  }
  return false;
}

HCVDisplayRiskResult _mergeMlPrimaryWithDiagnostics(
  HCVDisplayRiskResult primary,
  HCVDisplayRiskResult diagnostics,
) {
  final evidenceSources = <String>{
    ...primary.evidenceSources,
    ...diagnostics.evidenceSources,
  }.toList()
    ..sort();
  final strongSources = <String>{
    ...primary.strongSources,
    ...diagnostics.strongSources,
  }.toList()
    ..sort();
  final reasons = <String>{
    ...primary.reasons,
    ...diagnostics.reasons,
  }.toList();

  final finalScore = primary.decision == 'NO_DISPLAY_EVIDENCE'
      ? diagnostics.score.clamp(primary.score, 20).toInt()
      : primary.score;

  return HCVDisplayRiskResult(
    risk: primary.risk,
    score: finalScore,
    decision: primary.decision,
    analysisStatus: primary.analysisStatus,
    evidenceSources: evidenceSources,
    strongSources: strongSources,
    reasons: reasons,
  );
}

bool _hasLiveTemporalScreenCorroboration(Map<String, dynamic>? live) {
  if (live == null ||
      live['type'] != 'SIGILLUM_LIVE_SCREEN_PROBE_V1' ||
      live['analysisStatus'] == 'NOT_ANALYZED') {
    return false;
  }

  final rawSignals = live['signals'];
  final signals = rawSignals is Map ? rawSignals : const <String, dynamic>{};
  final frames = (live['framesAnalyzed'] as num?)?.toInt() ?? 0;
  final local = (live['localTemporalFlickerScore'] as num?)?.toDouble() ?? 0.0;
  final refresh = (live['refreshBandScore'] as num?)?.toDouble() ?? 0.0;
  final global = (live['globalFlicker'] as num?)?.toDouble() ?? 0.0;

  final activeIllumination =
      signals['activeIlluminationDisplayEvidence'] == true;
  final planarTemporal = signals['planarSceneEvidence'] == true &&
      (signals['periodicLightTrace'] == true ||
          signals['confirmedDisplayTrace'] == true);

  // Exact signature measured in the uploaded monitor photo certificate:
  // temporal bands and paired flicker are physical display evidence even
  // when the geometry layer has falsely labelled the full scene as reality.
  // The photo is promoted only when this live evidence is independently
  // corroborated by the post-capture structural analyzer.
  final exactBandSignature = frames >= 24 &&
      local >= 0.24 &&
      refresh >= 0.15 &&
      (global >= 0.08 || signals['pairedFlickerTrace'] == true) &&
      (signals['displayBandTrace'] == true ||
          signals['horizontalRefreshBands'] == true);

  return activeIllumination || planarTemporal || exactBandSignature;
}

HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final mlFirst = HCVDisplayRiskFusion.mlFirstPhotoDecision(
    _mlAnalysisFromAnalyses(analyses),
  );
  final legacy = _combinePhotoDisplayRiskLegacy(analyses);
  final liveProbe = _liveProbeFromAnalyses(analyses);
  final isTemporalV2 =
      liveProbe?['photoDecisionMethod'] == 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT';

  // A strong multi-frame/temporal DISPLAY result from the clip captured
  // immediately before the automatic still must not be erased by one semantic
  // still-image REALITY false negative (the C8FF failure mode).
  if (isTemporalV2 && legacy.decision == 'STRONG_DISPLAY_RISK') {
    return legacy;
  }

  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
  }
  return legacy;
}

HCVDisplayRiskResult _combinePhotoDisplayRiskLegacy(
  List<Map<String, dynamic>?> analyses,
) {
  final preCapture = HCVDisplayRiskFusion.combine(
    analyses,
    liveCaptureOnly: true,
  );
  if (preCapture.decision == 'STRONG_DISPLAY_RISK') return preCapture;

  // Post-capture analysis can corroborate, but never decide by itself. This
  // preserves the anti-false-positive policy while allowing the exact uploaded
  // photo case: temporal refresh bands before capture plus a structural screen
  // trace in the captured image.
  final liveProbe = _liveProbeFromAnalyses(analyses);
  if (!_hasLiveTemporalScreenCorroboration(liveProbe)) return preCapture;

  final corroborated = HCVDisplayRiskFusion.combine(analyses);
  final resolvedPhotoReality = preCapture.decision == 'NO_DISPLAY_EVIDENCE' &&
      preCapture.reasons.contains(
        'PHOTO_DUAL_REALITY_ML_AGREEMENT_OVERRIDES_ACTIVE_ONLY_SIGNAL',
      );
  if (resolvedPhotoReality && corroborated.decision != 'STRONG_DISPLAY_RISK') {
    return preCapture;
  }
  return _displayDecisionRank(corroborated.decision) >
          _displayDecisionRank(preCapture.decision)
      ? corroborated
      : preCapture;
}

HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final mlFirst = HCVDisplayRiskFusion.mlFirstVideoDecision(
    _mlAnalysisFromAnalyses(analyses),
  );
  final legacy = _combineVideoDisplayRiskLegacy(analyses);
  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
  }
  return legacy;
}

HCVDisplayRiskResult _combineVideoDisplayRiskLegacy(
  List<Map<String, dynamic>?> analyses,
) {
  final normalResult = HCVDisplayRiskFusion.combine(analyses);
  final resolvedFinalReality = normalResult.decision == 'NO_DISPLAY_EVIDENCE' &&
      (normalResult.reasons.contains(
            'GEOMETRIC_REALITY_AND_WEAK_MULTI_FRAME_SCREEN_EVIDENCE_AGREE',
          ) ||
          normalResult.reasons.contains(
            'MULTI_FRAME_REALITY_RESOLVES_UNCORROBORATED_TEMPORAL_SIGNAL',
          ) ||
          normalResult.reasons.contains(
            'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
          ) ||
          normalResult.reasons.contains(
            'SHORT_VIDEO_GEOMETRIC_AND_SEMANTIC_REALITY_AGREE',
          ) ||
          normalResult.reasons.contains(
            'PLANAR_GEOMETRY_RESOLVED_BY_SEMANTIC_REALITY_WITHOUT_HARD_DISPLAY_EVIDENCE',
          ));
  if (resolvedFinalReality) return normalResult;

  final liveProbe = _liveProbeFromAnalyses(analyses);
  if (liveProbe == null || liveProbe['videoEquivalentAvailable'] != true) {
    return normalResult;
  }

  final preCaptureResult = combinePhotoDisplayRiskFromPreCaptureEvidence([
    liveProbe,
  ]);
  return _displayDecisionRank(preCaptureResult.decision) >
          _displayDecisionRank(normalResult.decision)
      ? preCaptureResult
      : normalResult;
}

class CameraPage extends StatefulWidget {
  const CameraPage({
    super.key,
    this.initialPhotoMode = false,
    this.languageCode = 'it',
  });

  final bool initialPhotoMode;
  final String languageCode;

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
  final HCVCaptureLocationService _locationService =
      const HCVCaptureLocationService();
  Map<String, dynamic>? lastLiveSignals;
  Map<String, dynamic>? pendingLiveScreenProbe;
  HCVCaptureLocation? pendingVideoLocation;
  HCVCaptureLocation? _lastCaptureLocation;
  DateTime? pendingVideoCapturedAt;
  bool _printCoordinates = false;
  bool _locationBusy = false;

  bool ready = false;
  bool recording = false;
  bool _videoFinalizeInProgress = false;

  bool photoMode = false;

  FlashMode currentFlashMode = FlashMode.off;

  double currentZoom = 1.0;
  double minZoom = 1.0;
  double maxZoom = 1.0;

  String status = '';
  String? result;

  String? videoPath;
  String? hcvPath;
  String? packagePath;
  String? hcvId;
  String? verificationUrl;
  String? registryStatus;
  String? createdContentKind;
  bool _transcribingAudio = false;
  String? _videoTranscript;
  String? _subtitlePath;
  String? _captionedVideoPath;

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  String _c(String key) => CameraUiExtendedCopy.t(widget.languageCode, key);

  Future<void> _toggleCoordinateStamp() async {
    if (_locationBusy) return;
    if (_printCoordinates) {
      setState(() {
        _printCoordinates = false;
        _lastCaptureLocation = null;
      });
      _showLocationMessage(_c('coordinatesOff'));
      return;
    }

    setState(() => _locationBusy = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _printCoordinates = true;
        _lastCaptureLocation = location;
      });
      _showLocationMessage(location.watermarkText);
    } catch (error) {
      if (mounted) _showLocationMessage(error.toString());
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<HCVCaptureLocation?> _locationForCapture() async {
    if (!_printCoordinates) return null;
    final cached = _lastCaptureLocation;
    if (cached != null &&
        DateTime.now().difference(cached.measuredAt).abs() <
            const Duration(minutes: 1)) {
      return cached;
    }

    setState(() {
      _locationBusy = true;
      status = _c('acquiringCoordinates');
    });
    try {
      final location = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _lastCaptureLocation = location);
      return location;
    } catch (error) {
      if (mounted) {
        setState(() => status = _c('ready'));
        _showLocationMessage(error.toString());
      }
      return null;
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    photoMode = widget.initialPhotoMode;
    status = _c('initializing');
    initCamera();
    Future.microtask(_retryPendingRegistryUploads);
  }

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();

      if (cameras == null || cameras!.isEmpty) {
        setState(() => status = _c('noCamera'));
        return;
      }

      controller = CameraController(
        cameras![selectedCameraIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await controller!.initialize();

      minZoom = await controller!.getMinZoomLevel();
      final deviceMaxZoom = await controller!.getMaxZoomLevel();
      maxZoom = deviceMaxZoom.clamp(minZoom, 10.0).toDouble();
      currentZoom = currentZoom.clamp(minZoom, maxZoom).toDouble();
      await controller!.setZoomLevel(currentZoom);

      setState(() {
        ready = true;
        status = _c('ready');
      });
    } catch (e) {
      setState(() => status = '${_c('error')}: $e');
    }
  }

  Future<void> switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;
    pendingLiveScreenProbe = null;
    pendingVideoLocation = null;

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

  Future<void> _settleCameraAfterLiveProbe() async {
    final camera = controller;
    if (camera == null || !camera.value.isInitialized) return;

    if (camera.value.isStreamingImages) {
      await camera.stopImageStream();
    }
    await camera.setZoomLevel(currentZoom.clamp(minZoom, maxZoom).toDouble());
    // Second guard after the probe: wait for the preview/capture pipeline to
    // converge before takePicture, otherwise iOS can capture while zoomed.
    await Future.delayed(const Duration(milliseconds: 300));
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
        status = '${_c('zoomError')}: $e';
      });
    }
  }

  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) return;

    pendingLiveScreenProbe = null;
    pendingVideoLocation = captureLocation;
    lastLiveSignals = null;

    setState(() {
      recording = true;
      status = _c('starting');
      result = null;
      videoPath = null;
      hcvPath = null;
      packagePath = null;
      hcvId = null;
      verificationUrl = null;
      registryStatus = null;
    });

    try {
      // VIDEO starts on the user's first REC tap. There is no disposable
      // pre-capture clip and no parallax/geometry gate; display evidence comes
      // from the actual recorded video during post-capture analysis.
      await _settleCameraAfterLiveProbe();
      await controller!.startVideoRecording();
      pendingVideoCapturedAt = DateTime.now();

      try {
        await liveSignals.start();
      } catch (_) {
        lastLiveSignals = null;
      }

      setState(() => status = _c('recording'));
    } catch (e) {
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;
      pendingLiveScreenProbe = null;
      setState(() {
        recording = false;
        status = '${_c('startError')}: $e';
      });
    }
  }

  Future<void> _waitForFinalizedVideoContainer(String path) async {
    final file = File(path);
    const pollInterval = Duration(milliseconds: 250);
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    int? lastSize;
    var stableReads = 0;

    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await file.exists()) {
          final size = await file.length();
          if (size > 1024 && lastSize == size) {
            stableReads++;
            if (stableReads >= 3) return;
          } else {
            lastSize = size;
            stableReads = 0;
          }
        }
      } catch (_) {
        stableReads = 0;
      }
      await Future.delayed(pollInterval);
    }

    throw StateError('VIDEO_CONTAINER_NOT_FINALIZED');
  }

  Future<void> stop() async {
    if (controller == null || _videoFinalizeInProgress) return;
    _videoFinalizeInProgress = true;

    try {
      final file = await controller!.stopVideoRecording();

      try {
        lastLiveSignals = await liveSignals.stopAndBuildSummary();
      } catch (_) {
        lastLiveSignals = null;
      }

      await _waitForFinalizedVideoContainer(file.path);

      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
      final captureLocation = pendingVideoLocation;
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;

      setState(() {
        recording = false;
        status = _c('processingVideo');
      });

      await processVideo(
        file.path,
        capturedAt: capturedAt,
        captureLocation: captureLocation,
      );
    } catch (e) {
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;
      pendingLiveScreenProbe = null;
      try {
        lastLiveSignals = await liveSignals.stopAndBuildSummary();
      } catch (_) {
        lastLiveSignals = null;
      }
      if (mounted) {
        setState(() {
          recording = false;
          status = '${_c('stopError')}: $e';
        });
      }
    } finally {
      _videoFinalizeInProgress = false;
    }
  }

  Map<String, dynamic> _photoTemporalV2Unavailable(
    String reason, {
    Object? error,
  }) {
    return {
      'type': 'SIGILLUM_PHOTO_TEMPORAL_VIDEO_PROBE_V2',
      'analysisStatus': 'NOT_ANALYZED',
      'captureDurationMs':
          HCVTemporalCaptureProbe.defaultDuration.inMilliseconds,
      'temporaryVideoDeletedAfterAnalysis': true,
      'reason': reason,
      if (error != null) 'error': error.toString(),
    };
  }

  Map<String, dynamic> _buildPhotoTemporalV2LiveProbe(
    Map<String, dynamic> temporalProbe,
  ) {
    final opticalRaw = temporalProbe['screenReplayAnalysis'];
    final mlRaw = temporalProbe['mlScreenReplayAnalysis'];
    final optical = opticalRaw is Map
        ? Map<String, dynamic>.from(opticalRaw)
        : null;
    final ml = mlRaw is Map ? Map<String, dynamic>.from(mlRaw) : null;
    final analyzed = temporalProbe['analysisStatus'] == 'ANALYZED' &&
        (optical != null || ml != null);

    final temporalRisk = analyzed
        ? combineVideoDisplayRiskFromCaptureEvidence([optical, ml])
        : null;
    final opticalFrames = (optical?['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final mlFrames = (ml?['framesAnalyzed'] as num?)?.toInt() ?? 0;

    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 6,
      'analysisStatus': analyzed ? 'ANALYZED' : 'NOT_ANALYZED',
      'framesAnalyzed': opticalFrames > mlFrames ? opticalFrames : mlFrames,
      'screenReplayRisk': temporalRisk?.risk ?? 'UNKNOWN',
      'screenReplayRiskScore': temporalRisk?.score,
      'displayRiskDecision': temporalRisk?.decision ?? 'NOT_ANALYZED',
      'sceneClass': 'UNKNOWN',
      'reason': 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_NO_PARALLAX',
      'geometryChallenge': const {
        'sceneClass': 'UNKNOWN',
        'realityEvidence': false,
        'planarEvidence': false,
        'reasons': ['PHOTO_TEMPORAL_V2_NO_PARALLAX'],
      },
      'signals': {
        'photoTemporalVideoAnalyzed': analyzed,
        'photoTemporalVideoDeletedAfterAnalysis':
            temporalProbe['temporaryVideoDeletedAfterAnalysis'] == true,
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'planarSceneEvidence': false,
        'geometryChallengeCompleted': false,
        'activeChallengeIndeterminate': false,
      },
      'photoTemporalVideoProbe': temporalProbe,
      'photoDecisionMethod': 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT',
      'videoEquivalentAvailable': analyzed && temporalRisk != null,
      if (temporalRisk != null)
        'videoEquivalentDisplayRisk': temporalRisk.toJson(),
      'note':
          'Photo Temporal V2 uses a disposable 2.4 s clip immediately before automatic still capture. Manual parallax is not used.',
    };
  }

  Future<void> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) return;

    const temporalProbeEngine = HCVTemporalCaptureProbe();
    HCVTemporalCaptureClip? temporalClip;
    Map<String, dynamic>? temporalProbe;

    try {
      // One user tap starts the technical clip and automatically finishes with
      // the actual still. No PROSEGUI step and no 15-second scene gap remain.
      setState(() {
        status = _c('takingPhoto');
        result = null;
      });

      try {
        temporalClip = await temporalProbeEngine.capture(
          controller!,
          duration: HCVTemporalCaptureProbe.defaultDuration,
        );
      } catch (e) {
        temporalProbe = _photoTemporalV2Unavailable(
          'PHOTO_TEMPORAL_CAPTURE_FAILED',
          error: e,
        );
      }

      // The technical temporal clip is always captured with flash disabled.
      // Restore the user's selected photo flash/torch before the real still.
      if (currentFlashMode != FlashMode.off &&
          controller!.value.isInitialized) {
        try {
          await controller!.setFlashMode(currentFlashMode);
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (_) {}
      }

      await _settleCameraAfterLiveProbe();

      late final XFile file;
      try {
        file = await controller!.takePicture();
      } catch (_) {
        if (temporalClip != null) {
          await temporalProbeEngine.discard(temporalClip.path);
        }
        rethrow;
      }
      final capturedAt = DateTime.now();

      final savedPhotoPath = await savePhotoToDocuments(file.path);

      if (temporalClip != null) {
        setState(() {
          status = _c('analyzingScreen');
        });
        temporalProbe =
            await temporalProbeEngine.analyzeCapturedClip(temporalClip);
        temporalClip = null;
      }
      temporalProbe ??= _photoTemporalV2Unavailable(
        'PHOTO_TEMPORAL_NOT_AVAILABLE',
      );
      final liveScreenProbe = _buildPhotoTemporalV2LiveProbe(temporalProbe);

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
        status = _c('analyzingScreen');
      });

      try {
        screenReplayAnalysis = await HCVScreenReplayAnalyzer().analyzeImage(
          savedPhotoPath,
        );
      } catch (_) {
        screenReplayAnalysis = null;
      }

      try {
        mlScreenReplayAnalysis = await HCVMLScreenReplayClassifier.instance
            .analyzeImage(savedPhotoPath);
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

      if (screenReplayAnalysis != null) {
        screenReplayAnalysis = {
          ...screenReplayAnalysis,
          'decisionRole': 'POST_CAPTURE_DIAGNOSTIC_ONLY',
        };
      }
      mlScreenReplayAnalysis = {
        ...mlScreenReplayAnalysis,
        'decisionRole': 'POST_CAPTURE_DIAGNOSTIC_ONLY',
      };

      final screenReplayAnalyses = [
        liveScreenProbe,
        screenReplayAnalysis,
        mlScreenReplayAnalysis,
      ];
      final displayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(
        screenReplayAnalyses,
      );
      final detectedScreenReplayRisk = displayRisk.risk;
      final detectedScreenReplayScore = displayRisk.score;
      final displayRiskDecision = displayRisk.decision;
      final detectedScreenReplay = displayRiskDecision == "STRONG_DISPLAY_RISK";

      setState(() {
        status = _c('addingWatermark');
      });

      final publishedPhoto =
          await HCVLocationImageWatermark().createPublishedPhoto(
        inputPath: savedPhotoPath,
        hcvId: preparedHcvId,
        capturedAt: capturedAt,
        captureLocation: captureLocation,
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
        socialFingerprint = await HCVSocialFingerprint().buildFromImage(
          publishedPhoto,
        );
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
        "displayRiskDecision": displayRiskDecision,
        "displayRiskMeaning": _displayRiskMeaning(displayRiskDecision),
        "displayRiskEvidence": displayRisk.toJson(),
        "aiProofLevel": "STILL_IMAGE_CAPTURE_V1",
        "captureCreatedAt": capturedAt.toUtc().toIso8601String(),
        "captureCreatedAtLocal": HCVCaptureTimestamp.format(capturedAt),
        "captureLocation": captureLocation?.toJson(),
        "locationPrinted": captureLocation != null,
        "liveScreenProbe": liveScreenProbe,
        "physicalSceneClass": liveScreenProbe["sceneClass"] ?? "UNKNOWN",
        "geometryChallenge": liveScreenProbe["geometryChallenge"],
        "screenReplayAnalysis": screenReplayAnalysis,
        "mlScreenReplayAnalysis": mlScreenReplayAnalysis,
        "mlScreenReplayAnalysisStatus": _mlAnalysisStatus(
          mlScreenReplayAnalysis,
        ),
        "screenReplayRisk": detectedScreenReplayRisk,
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

        pack = await packer.createPhotoPackage(
          photoPath: publishedPhoto,
          hcvPath: hcv,
        );
        pack = await movePackageToUnifiedName(
          currentPath: pack,
          hcvId: preparedHcvId,
          contentKind: 'photo',
        );
      }

      setState(() {
        result = ok ? 'VALID' : 'INVALID';

        status = ok ? _c('photoVerified') : _c('photoInvalid');

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
      if (temporalClip != null) {
        await temporalProbeEngine.discard(temporalClip.path);
      }
      setState(() {
        status = '${_c('photoError')}: $e';
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
    if (!await sourceFile.exists()) {
      throw FileSystemException('Recorded video source not found', sourcePath);
    }
    final sourceSize = await sourceFile.length();
    if (sourceSize <= 1024) {
      throw StateError('VIDEO_CONTAINER_TOO_SMALL');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final savedPath = p.join(dir.path, 'hcv_video_$timestamp.mp4');
    final savedFile = await sourceFile.copy(savedPath);
    final copiedSize = await savedFile.length();
    if (copiedSize != sourceSize) {
      try {
        await savedFile.delete();
      } catch (_) {}
      throw StateError('VIDEO_CONTAINER_CHANGED_DURING_COPY');
    }

    return savedFile.path;
  }

  Future<String> savePhotoToDocuments(String sourcePath) async {
    final dir = await _downloadsDirectory();

    final sourceFile = File(sourcePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final savedPath = p.join(dir.path, 'hcv_photo_$timestamp.jpg');

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

    final newPath = p.join(dir.path, 'hcv_video_$safeId.mp4');

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

    final newPath = p.join(dir.path, 'hcv_video_$safeId.hcv');

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
    String contentKind = 'video',
  }) async {
    final currentFile = File(currentPath);
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final dir = await _downloadsDirectory();

    final contentPrefix = contentKind == 'photo' ? 'hcv_photo' : 'hcv_video';
    final newPath = p.join(dir.path, '${contentPrefix}_$safeId.hcvpack');

    final newFile = File(newPath);

    if (p.normalize(currentFile.absolute.path) ==
        p.normalize(newFile.absolute.path)) {
      if (!await currentFile.exists()) {
        throw FileSystemException(
          'HCVPACK source disappeared before final naming',
          currentFile.path,
        );
      }
      return currentFile.path;
    }

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

  String _displayRiskMeaning(String decision) {
    switch (decision) {
      case "STRONG_DISPLAY_RISK":
        return "Multiple consistent signals indicate possible display recapture.";
      case "NON_CONCLUSIVE":
        return "Ambiguous visual or optical signals were observed, but not enough for a display warning.";
      default:
        return "No sufficient display recapture evidence was observed.";
    }
  }

  String _mlAnalysisStatus(Map<String, dynamic>? analysis) {
    if (analysis == null) return "NOT_ANALYZED";
    final status = analysis["analysisStatus"]?.toString();
    if (status != null && status.isNotEmpty) return status;
    final score = analysis["screenReplayRiskScore"];
    return score == null ? "NOT_ANALYZED" : "ANALYZED";
  }

  Future<void> processVideo(
    String path, {
    DateTime? capturedAt,
    HCVCaptureLocation? captureLocation,
  }) async {
    final liveScreenProbe = pendingLiveScreenProbe;
    pendingLiveScreenProbe = null;
    final effectiveCapturedAt = capturedAt ?? DateTime.now();

    setState(() {
      status = _c('savingVideo');
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
      status = _c('analyzingScreen');
      videoPath = savedVideoPath;
      hcvId = preparedHcvId;
      verificationUrl = preparedVerificationUrl;
    });

    try {
      screenReplayAnalysis = await HCVScreenReplayAnalyzer().analyzeVideo(
        savedVideoPath,
      );
    } catch (_) {
      screenReplayAnalysis = null;
    }

    try {
      mlScreenReplayAnalysis = await HCVMLScreenReplayClassifier.instance
          .analyzeVideo(savedVideoPath);
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
    );
    final screenReplayAnalyses = [
      liveScreenProbe,
      screenReplayAnalysis,
      mlScreenReplayAnalysis,
    ];
    final displayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
    );
    final detectedScreenReplayRisk = displayRisk.risk;
    final detectedScreenReplayScore = displayRisk.score;
    final displayRiskDecision = displayRisk.decision;
    final detectedScreenReplay = displayRiskDecision == "STRONG_DISPLAY_RISK";

    setState(() {
      status = _c('addingLogo');
    });

    final originalVideoBeforeWatermark = savedVideoPath;

    try {
      savedVideoPath = await HCVLocationVideoWatermark().createPublishedVideo(
        inputPath: savedVideoPath,
        hcvId: preparedHcvId,
        capturedAt: effectiveCapturedAt,
        captureLocation: captureLocation,
      );

      try {
        if (originalVideoBeforeWatermark != savedVideoPath &&
            await File(originalVideoBeforeWatermark).exists()) {
          await File(originalVideoBeforeWatermark).delete();
        }
      } catch (_) {}
    } catch (e) {
      setState(() {
        status = '${_c('watermarkError')}: $e';
      });
      rethrow;
    }

    try {
      socialFingerprint = await HCVSocialFingerprint().buildFromVideo(
        savedVideoPath,
      );
    } catch (_) {
      socialFingerprint = null;
    }

    setState(() {
      status = _c('creatingCertificate');
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
      "captureMode": "STANDARD",
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
      "displayRiskDecision": displayRiskDecision,
      "displayRiskMeaning": _displayRiskMeaning(displayRiskDecision),
      "displayRiskEvidence": displayRisk.toJson(),
      "aiProofLevel": "PASSIVE_LIVE_CAPTURE_V1",
      "trustLevel": trustAnalysis["trustLevel"],
      "liveCaptureTrust": trustAnalysis["liveCaptureTrust"],
      "passiveLiveProofScore": trustAnalysis["score"],
      "captureModeNote": trustAnalysis["note"],
      "captureCreatedAt": effectiveCapturedAt.toUtc().toIso8601String(),
      "captureCreatedAtLocal": HCVCaptureTimestamp.format(effectiveCapturedAt),
      "captureLocation": captureLocation?.toJson(),
      "locationPrinted": captureLocation != null,
      "liveScreenProbe": liveScreenProbe,
      "physicalSceneClass": liveScreenProbe?["sceneClass"] ?? "UNKNOWN",
      "geometryChallenge": liveScreenProbe?["geometryChallenge"],
      "screenReplayAnalysis": screenReplayAnalysis,
      "mlScreenReplayAnalysis": mlScreenReplayAnalysis,
      "mlScreenReplayAnalysisStatus": _mlAnalysisStatus(mlScreenReplayAnalysis),
      "screenReplayRisk": detectedScreenReplayRisk,
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

    detectedId ??= preparedHcvId;
    detectedUrl ??= preparedVerificationUrl;

    if (detectedId.isNotEmpty) {
      try {
        savedVideoPath = await renameVideoWithHcvId(
          currentPath: savedVideoPath,
          hcvId: detectedId,
        );

        hcv = await moveHcvToUnifiedName(currentPath: hcv, hcvId: detectedId);
      } catch (e) {
        setState(() {
          status = '${_c('renameError')}: $e';
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
      status = _c('done');
    });

    if (ok) {
      await saveContentToGallery(savedVideoPath);
      await uploadCertificateToRegistry();
    }
  }

  Future<void> uploadCertificateToRegistry() async {
    if (hcvPath == null) return;
    final currentPath = File(hcvPath!).absolute.path;

    setState(() {
      registryStatus = _c('registryPublishing');
    });

    try {
      await registry.enqueueCertificateFile(currentPath);
      final report = await registry.retryPendingUploads();
      final currentUploaded = report.uploadedPaths.contains(currentPath);
      setState(() {
        registryStatus = currentUploaded
            ? '${_c('registryOk')}: ${hcvId ?? _c('certificatePublished')}'
            : _c('registryPending');
      });
    } catch (e) {
      setState(() {
        registryStatus = '${_c('registryUnavailableLocal')}: $e';
      });
    }
  }

  Future<void> _retryPendingRegistryUploads() async {
    try {
      final report = await registry.retryPendingUploads();
      if (!mounted || report.uploaded == 0) return;
      setState(() {
        registryStatus = report.pending == 0
            ? _c('registrySynced')
            : 'Registry: ${report.uploaded} ${_c('registryPublished')}, ${report.pending} ${_c('registryWaiting')}';
      });
    } catch (_) {
      // La certificazione locale resta valida; il retry avverra al prossimo avvio.
    }
  }

  Future<void> fakeTest() async {
    try {
      final temp = File('${Directory.systemTemp.path}/fake_video.mp4');
      await temp.writeAsString('HCV TEST VIDEO DATA ${DateTime.now()}');
      await processVideo(temp.path);
    } catch (e) {
      setState(() => status = '${_c('error')}: $e');
    }
  }

  Future<void> copyVerificationLink() async {
    final text = hcvId ?? verificationUrl;
    if (text == null) return;

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_c('hcvCopied'))));
  }

  Future<void> shareVideoAndCertificate() async {
    if (videoPath == null || hcvPath == null) {
      setState(() => status = _c('noFileToShare'));
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(videoPath!, mimeType: _contentMimeType(videoPath!))],
        text: hcvId == null
            ? _c('verifiedContent')
            : '${_c('verifiedContent')}\nID: $hcvId\nVerify with SIGILLUM',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      setState(() => status = '${_c('shareError')}: $e');
    }
  }

  Future<bool> saveContentToGallery(String path) async {
    if (!Platform.isIOS) return false;

    final lower = path.toLowerCase();
    final isCaptioned = lower.contains('_sottotitolato');
    final isPhoto = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');

    try {
      final saved = await _mediaChannel.invokeMethod<bool>('saveToPhotos', {
        'path': path,
      });
      if (saved == true && mounted) {
        final label = isCaptioned
            ? _c('captionedSavedPhotos')
            : isPhoto
                ? _c('certifiedPhotoSaved')
                : _c('certifiedOriginalSaved');
        setState(() {
          registryStatus =
              registryStatus == null ? label : '$registryStatus\n$label';
        });
        return true;
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          final label = isCaptioned
              ? _c('captionedAvailableFiles')
              : _c('photosPermissionUnavailable');
          registryStatus =
              registryStatus == null ? label : '$registryStatus\n$label';
        });
      }
      return false;
    }
  }

  Future<void> _saveCaptionedVideoToPhotos() async {
    final path = _captionedVideoPath;
    if (path == null) return;
    final saved = await saveContentToGallery(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? _c('captionedSavedPhotosSentence')
              : _c('captionedSaveFailed'),
        ),
      ),
    );
  }

  void _openCameraQuickGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SigillumQuickGuidePage(languageCode: widget.languageCode),
      ),
    );
  }

  Future<void> sharePackage() async {
    if (packagePath == null) {
      setState(() => status = _c('noPackToShare'));
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(packagePath!, mimeType: 'application/octet-stream')],
        text: hcvId == null
            ? 'HCVPACK offline SIGILLUM'
            : 'HCVPACK offline SIGILLUM\nID: $hcvId',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      setState(() => status = '${_c('sharePackError')}: $e');
    }
  }

  String get _createdContentLabel {
    if (createdContentKind == 'photo') return _c('photoLower');
    if (createdContentKind == 'video') return _c('videoLower');
    return _c('contentLower');
  }

  String get _createdFileLabel {
    if (createdContentKind == 'photo') return _c('photoTitle');
    if (createdContentKind == 'video') return _c('videoTitle');
    return _c('contentTitle');
  }

  String _contentMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'video/mp4';
  }

  Future<void> _transcribeCreatedVideo() async {
    final path = videoPath;
    if (path == null || createdContentKind != 'video' || _transcribingAudio)
      return;
    setState(() {
      _transcribingAudio = true;
      status = _c('transcriptionAudio');
    });
    try {
      final transcript = await const VideoTranscriptionService().transcribe(
        path,
        languageCode: widget.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _videoTranscript = transcript.text;
        _subtitlePath = transcript.subtitlePath;
        _captionedVideoPath = transcript.captionedVideoPath;
        status = _c('captionedReady');
      });
      final savedCaptionedToPhotos = await saveContentToGallery(
        transcript.captionedVideoPath,
      );
      if (!mounted) return;
      setState(() {
        status = savedCaptionedToPhotos
            ? _c('captionedReadyPhotos')
            : _c('captionedReadyFiles');
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Video sottotitolato creato'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _c('captionExplanation'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                SelectableText(
                  transcript.text.isEmpty
                      ? _c('subtitlesCreated')
                      : transcript.text,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_c('close')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => status = '${_c('transcriptionFailed')}: $error');
    } finally {
      if (mounted) setState(() => _transcribingAudio = false);
    }
  }

  Future<void> _shareSubtitleFile() async {
    final path = _subtitlePath;
    if (path == null) return;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/x-subrip')],
      text: _videoTranscript == null || _videoTranscript!.isEmpty
          ? _c('subtitleShareText')
          : _videoTranscript!,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  Future<void> _shareCaptionedVideo() async {
    final path = _captionedVideoPath;
    if (path == null) return;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'video/mp4')],
      text: _c('shareCaptionedText'),
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
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
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
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
          verified ? _c('humanVerified') : _c('notVerified'),
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
              '${_createdFileLabel}: ${_c('verifiableCreated')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 10),
            Text(
              'HCV-ID:\n${hcvId ?? '-'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '${_createdFileLabel}, ${_t('certificate')} HCV, HCVPACK: ${_c('linkedFiles')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: copyVerificationLink,
              icon: const Icon(Icons.copy),
              label: Text(_c('copyHcvId')),
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
    if (videoPath == null &&
        hcvPath == null &&
        packagePath == null &&
        _captionedVideoPath == null &&
        _subtitlePath == null) {
      return const SizedBox.shrink();
    }

    String fileName(String? value) => value == null ? '-' : p.basename(value);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7E3EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.folder_outlined, color: Color(0xFF0098A1), size: 34),
          const SizedBox(height: 8),
          Text(
            _c('filesWhere'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF280D5F),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _c('filesPath'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF280D5F),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _c('filesExplanation'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7A6EAA),
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
          const Divider(height: 24),
          if (videoPath != null)
            Text(
              '${_c('certifiedOriginal')}: ${fileName(videoPath)}',
              textAlign: TextAlign.center,
            ),
          if (hcvPath != null) ...[
            const SizedBox(height: 5),
            Text(
              '${_c('hcvCertificate')}: ${fileName(hcvPath)}',
              textAlign: TextAlign.center,
            ),
          ],
          if (packagePath != null) ...[
            const SizedBox(height: 5),
            Text(
              'HCVPACK: ${fileName(packagePath)}',
              textAlign: TextAlign.center,
            ),
          ],
          if (_captionedVideoPath != null) ...[
            const SizedBox(height: 5),
            Text(
              '${_c('captionedVideo')}: ${fileName(_captionedVideoPath)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          if (_subtitlePath != null) ...[
            const SizedBox(height: 5),
            Text(
              '${_c('srtSubtitles')}: ${fileName(_subtitlePath)}',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _openCameraQuickGuide,
            icon: const Icon(Icons.help_outline_rounded),
            label: Text(_c('quickGuide')),
          ),
        ],
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
              label: Text(_t('shareContent')),
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
              label: Text(_t('shareOfflinePack')),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (createdContentKind == 'video' &&
            videoPath != null &&
            Platform.isIOS) ...[
          SizedBox(
            width: 340,
            child: ElevatedButton.icon(
              onPressed: _transcribingAudio ? null : _transcribeCreatedVideo,
              icon: const Icon(Icons.subtitles_rounded),
              label: Text(
                _transcribingAudio
                    ? _c('transcribing')
                    : _c('createCaptionedVideo'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_captionedVideoPath != null)
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                onPressed: _saveCaptionedVideoToPhotos,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_c('saveCaptionedPhotos')),
              ),
            ),
          if (_captionedVideoPath != null) const SizedBox(height: 10),
          if (_captionedVideoPath != null)
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                onPressed: _shareCaptionedVideo,
                icon: const Icon(Icons.closed_caption_rounded),
                label: Text(_c('shareCaptionedVideo')),
              ),
            ),
          if (_captionedVideoPath != null) const SizedBox(height: 10),
          if (_subtitlePath != null)
            SizedBox(
              width: 340,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1FC7D4),
                  foregroundColor: const Color(0xFF280D5F),
                  minimumSize: const Size.fromHeight(64),
                ),
                onPressed: _shareSubtitleFile,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(_c('shareSrt')),
              ),
            ),
          if (_subtitlePath != null) const SizedBox(height: 10),
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
        title: Text(_t('cameraTitle')),
        actions: [
          IconButton(
            tooltip: _c('printGpsCoordinates'),
            onPressed: _locationBusy ? null : _toggleCoordinateStamp,
            icon: Icon(
              _printCoordinates ? Icons.location_on : Icons.location_off,
              color: _printCoordinates ? Colors.greenAccent : Colors.white,
            ),
          ),
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
              child: Container(color: Colors.black.withValues(alpha: 0.65)),
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
                    const Icon(Icons.zoom_out, color: Colors.white, size: 18),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.25,
                          ),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.15),
                          trackHeight: 2.5,
                        ),
                        child: Slider(
                          value: currentZoom.clamp(minZoom, maxZoom),
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
                  padding: const EdgeInsets.only(bottom: 14, top: 58),
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
                            label: Text(_t('video')),
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
                            label: Text(_t('photo')),
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
                              pendingLiveScreenProbe = null;
                              pendingVideoLocation = null;
                              setState(() {
                                photoMode = true;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: !ready || _videoFinalizeInProgress
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
                            border: Border.all(color: Colors.white70, width: 5),
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
                            ? _t('recording')
                            : photoMode
                                ? _t('photoMode')
                                : _t('videoMode'),
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
                                status = _c('ready');
                                result = null;
                                videoPath = null;
                                hcvPath = null;
                                packagePath = null;
                                hcvId = null;
                                verificationUrl = null;
                                registryStatus = null;
                                _videoTranscript = null;
                                _subtitlePath = null;
                                _captionedVideoPath = null;
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
                              status = _c('ready');
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
