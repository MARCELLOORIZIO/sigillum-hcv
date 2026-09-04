import 'dart:io';

import 'package:camera/camera.dart';

import 'hcv_ml_screen_replay_classifier.dart';
import 'hcv_screen_replay_analyzer.dart';

class HCVTemporalCaptureClip {
  const HCVTemporalCaptureClip({
    required this.path,
    required this.captureDurationMs,
  });

  final String path;
  final int captureDurationMs;
}

class HCVTemporalCaptureProbe {
  const HCVTemporalCaptureProbe();

  static const Duration defaultDuration = Duration(milliseconds: 2400);
  static const double photoMlFrameIntervalSeconds = 0.6;
  static const int photoMlFrameLimit = 4;

  /// Captures only the disposable pre-photo temporal clip.
  ///
  /// Analysis is intentionally deferred until after the still image is taken,
  /// so no ML/optical processing delay can separate the end of this clip from
  /// the actual photo capture.
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

    String? temporaryVideoPath;
    var recordingStarted = false;

    try {
      await controller.setFlashMode(FlashMode.off);
      await Future.delayed(const Duration(milliseconds: 120));

      await controller.startVideoRecording();
      recordingStarted = true;
      await Future.delayed(duration);

      final capture = await controller.stopVideoRecording();
      recordingStarted = false;
      temporaryVideoPath = capture.path;

      return HCVTemporalCaptureClip(
        path: temporaryVideoPath,
        captureDurationMs: duration.inMilliseconds,
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
      }
      rethrow;
    }
  }

  /// Analyzes a clip already captured immediately before a still photo.
  /// Four ML samples are requested at 0.6 s spacing inside the 2.4 s clip,
  /// while optical analysis keeps its denser temporal sampling for
  /// refresh/flicker evidence.
  Future<Map<String, dynamic>> analyzeCapturedClip(
    HCVTemporalCaptureClip clip,
  ) async {
    var temporaryVideoPath = clip.path;

    try {
      late Map<String, dynamic> opticalAnalysis;
      late Map<String, dynamic> mlAnalysis;

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
    try {
      final file = File(path);
      if (!await file.exists()) return true;
      await file.delete();
      return !await file.exists();
    } catch (_) {
      return false;
    }
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
