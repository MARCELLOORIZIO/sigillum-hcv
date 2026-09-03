import 'dart:io';

import 'package:camera/camera.dart';

import 'hcv_display_microtexture_probe.dart';
import 'hcv_ml_screen_replay_classifier.dart';
import 'hcv_screen_replay_analyzer.dart';

class HCVTemporalCaptureClip {
  const HCVTemporalCaptureClip({
    required this.path,
    required this.captureDurationMs,
    this.displayMicrotextureShadowCapture,
  });

  final String path;
  final int captureDurationMs;
  final Map<String, dynamic>? displayMicrotextureShadowCapture;
}

class HCVTemporalCaptureProbe {
  const HCVTemporalCaptureProbe();

  static const Duration defaultDuration = Duration(milliseconds: 2400);
  static const double photoMlFrameIntervalSeconds = 0.6;
  static const int photoMlFrameLimit = 4;

  // Allows the existing camera-page failure path to delete both the BUILD 80
  // temporal clip and the new disposable shadow clip without changing the
  // camera-page API.
  static final Map<String, Map<String, dynamic>> _shadowCaptureByPrimaryPath =
      <String, Map<String, dynamic>>{};

  /// Captures the experimental shadow probe first, restores camera state, then
  /// captures the original BUILD 80 disposable pre-photo temporal clip.
  ///
  /// The shadow probe is never used by the BUILD 80 fusion. The original 2.4 s
  /// clip remains the only temporal clip used for the production verdict and
  /// still ends immediately before the automatic still capture.
  Future<HCVTemporalCaptureClip> capture(
    CameraController controller, {
    Duration duration = defaultDuration,
  }) async {
    if (!controller.value.isInitialized) {
      throw StateError('CAMERA_NOT_READY');
    }
    if (controller.value.isStreamingImages) {
      throw StateError('IMAGE_STREAM_ACTIVE');
    }
    if (controller.value.isRecordingVideo) {
      throw StateError('CAMERA_ALREADY_RECORDING');
    }

    Map<String, dynamic>? displayMicrotextureShadowCapture;
    try {
      displayMicrotextureShadowCapture =
          await const HCVDisplayMicrotextureShadowProbe().capture(controller);
    } catch (error) {
      displayMicrotextureShadowCapture = {
        'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_CAPTURE_V1',
        'analysisStatus': 'NOT_CAPTURED',
        'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
        'reason': 'ACTIVE_SHADOW_CAPTURE_EXCEPTION',
        'error': error.toString(),
      };
    }

    String? temporaryVideoPath;
    var recordingStarted = false;

    try {
      // BUILD 80 baseline begins here. Any zoom/exposure changes made by the
      // shadow probe have already been restored before this point.
      await controller.setFlashMode(FlashMode.off);
      await Future.delayed(const Duration(milliseconds: 120));

      await controller.startVideoRecording();
      recordingStarted = true;
      await Future.delayed(duration);

      final capture = await controller.stopVideoRecording();
      recordingStarted = false;
      temporaryVideoPath = capture.path;

      final shadowPath =
          displayMicrotextureShadowCapture?['path']?.toString() ?? '';
      if (shadowPath.isNotEmpty) {
        _shadowCaptureByPrimaryPath[temporaryVideoPath] =
            displayMicrotextureShadowCapture!;
      }

      return HCVTemporalCaptureClip(
        path: temporaryVideoPath,
        captureDurationMs: duration.inMilliseconds,
        displayMicrotextureShadowCapture: displayMicrotextureShadowCapture,
      );
    } catch (_) {
      if (recordingStarted && controller.value.isRecordingVideo) {
        try {
          final capture = await controller.stopVideoRecording();
          temporaryVideoPath ??= capture.path;
        } catch (_) {}
      }
      if (temporaryVideoPath != null) {
        await discard(temporaryVideoPath);
      } else {
        await const HCVDisplayMicrotextureShadowProbe()
            .discardCapture(displayMicrotextureShadowCapture);
      }
      rethrow;
    }
  }

  /// Analyzes the unchanged BUILD 80 clip and, independently, the new shadow
  /// capture. Shadow metrics are embedded in the HCV but never supplied to the
  /// current DISPLAY/REALITY fusion.
  Future<Map<String, dynamic>> analyzeCapturedClip(
    HCVTemporalCaptureClip clip,
  ) async {
    var temporaryVideoPath = clip.path;
    final shadowCapture = clip.displayMicrotextureShadowCapture;

    try {
      late Map<String, dynamic> opticalAnalysis;
      late Map<String, dynamic> mlAnalysis;
      Map<String, dynamic> displayMicrotextureShadowAnalysis;

      try {
        displayMicrotextureShadowAnalysis =
            await const HCVDisplayMicrotextureShadowProbe()
                .analyzeCapture(shadowCapture);
      } catch (e) {
        displayMicrotextureShadowAnalysis = {
          'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_ANALYSIS_V1',
          'analysisStatus': 'NOT_ANALYZED',
          'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
          'productionDecisionChanged': false,
          'reason': 'SHADOW_ANALYSIS_EXCEPTION',
          'error': e.toString(),
        };
      }

      try {
        opticalAnalysis =
            await HCVScreenReplayAnalyzer().analyzeVideo(temporaryVideoPath);
      } catch (e) {
        opticalAnalysis = _analysisUnknown(
          type: 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
          reason: 'PHOTO_TEMPORAL_OPTICAL_ANALYSIS_EXCEPTION',
          error: e,
        );
      }

      try {
        mlAnalysis =
            await HCVMLScreenReplayClassifier.instance.analyzeVideo(
          temporaryVideoPath,
          frameSamplingIntervalSeconds: photoMlFrameIntervalSeconds,
          maxFrames: photoMlFrameLimit,
        );
      } catch (e) {
        mlAnalysis = _analysisUnknown(
          type: 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
          reason: 'PHOTO_TEMPORAL_ML_ANALYSIS_EXCEPTION',
          error: e,
        );
      }

      final opticalScore =
          (opticalAnalysis['screenReplayRiskScore'] as num?)?.toInt();
      final mlScore = (mlAnalysis['screenReplayRiskScore'] as num?)?.toInt();
      final analyzed = opticalScore != null || mlScore != null;
      final temporaryVideoDeleted = await discard(temporaryVideoPath);
      if (temporaryVideoDeleted) {
        temporaryVideoPath = '';
      }

      return {
        'type': 'SIGILLUM_PHOTO_TEMPORAL_VIDEO_PROBE_V2',
        'analysisStatus': analyzed ? 'ANALYZED' : 'NOT_ANALYZED',
        'captureDurationMs': clip.captureDurationMs,
        'temporaryVideoDeletedAfterAnalysis': temporaryVideoDeleted,
        'screenReplayAnalysis': {
          ...opticalAnalysis,
          'decisionRole': 'PRE_CAPTURE_TEMPORAL_EVIDENCE',
          'captureSource': 'PHOTO_TECHNICAL_MINI_VIDEO_V2',
        },
        'mlScreenReplayAnalysis': {
          ...mlAnalysis,
          'decisionRole': 'PRE_CAPTURE_TEMPORAL_EVIDENCE',
          'captureSource': 'PHOTO_TECHNICAL_MINI_VIDEO_V2',
        },
        'displayMicrotextureShadowProbe': {
          'capture': _redactShadowPath(shadowCapture),
          'analysis': displayMicrotextureShadowAnalysis,
          'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
          'productionDecisionChanged': false,
        },
      };
    } catch (e) {
      return _unknown(
        'PHOTO_TEMPORAL_ANALYSIS_FAILED',
        captureDurationMs: clip.captureDurationMs,
        error: e,
      );
    } finally {
      if (temporaryVideoPath.isNotEmpty) {
        await discard(temporaryVideoPath);
      }
      await const HCVDisplayMicrotextureShadowProbe()
          .discardCapture(shadowCapture);
    }
  }

  /// Backward-compatible convenience path for legacy callers.
  Future<Map<String, dynamic>> analyze(
    CameraController controller, {
    Duration duration = defaultDuration,
  }) async {
    try {
      final clip = await capture(controller, duration: duration);
      return await analyzeCapturedClip(clip);
    } catch (e) {
      return _unknown(
        'PHOTO_TEMPORAL_CAPTURE_FAILED',
        captureDurationMs: duration.inMilliseconds,
        error: e,
      );
    }
  }

  Future<bool> discard(String? path) async {
    if (path == null || path.isEmpty) return true;
    var primaryDeleted = true;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        primaryDeleted = !await file.exists();
      }
    } catch (_) {
      primaryDeleted = false;
    }

    final shadowCapture = _shadowCaptureByPrimaryPath.remove(path);
    final shadowDeleted = await const HCVDisplayMicrotextureShadowProbe()
        .discardCapture(shadowCapture);
    return primaryDeleted && shadowDeleted;
  }

  Map<String, dynamic>? _redactShadowPath(Map<String, dynamic>? capture) {
    if (capture == null) return null;
    final copy = Map<String, dynamic>.from(capture);
    if (copy.containsKey('path')) {
      copy['temporaryVideoPathStoredInHcv'] = false;
      copy.remove('path');
    }
    return copy;
  }

  Map<String, dynamic> _unknown(
    String reason, {
    int? captureDurationMs,
    Object? error,
  }) {
    return {
      'type': 'SIGILLUM_PHOTO_TEMPORAL_VIDEO_PROBE_V2',
      'analysisStatus': 'NOT_ANALYZED',
      if (captureDurationMs != null) 'captureDurationMs': captureDurationMs,
      'temporaryVideoDeletedAfterAnalysis': true,
      'reason': reason,
      if (error != null) 'error': error.toString(),
    };
  }

  Map<String, dynamic> _analysisUnknown({
    required String type,
    required String reason,
    required Object error,
  }) {
    return {
      'type': type,
      'analysisStatus': 'NOT_ANALYZED',
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'reason': reason,
      'error': error.toString(),
    };
  }
}
