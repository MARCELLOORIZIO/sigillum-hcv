import 'dart:io';

import 'package:camera/camera.dart';

import 'hcv_ml_screen_replay_classifier.dart';
import 'hcv_screen_replay_analyzer.dart';

class HCVTemporalCaptureProbe {
  const HCVTemporalCaptureProbe();

  static const Duration defaultDuration = Duration(milliseconds: 1800);

  Future<Map<String, dynamic>> analyze(
    CameraController controller, {
    Duration duration = defaultDuration,
  }) async {
    if (!controller.value.isInitialized) {
      return _unknown('CAMERA_NOT_READY');
    }
    if (controller.value.isStreamingImages) {
      return _unknown('IMAGE_STREAM_ACTIVE');
    }
    if (controller.value.isRecordingVideo) {
      return _unknown('CAMERA_ALREADY_RECORDING');
    }

    String? temporaryVideoPath;
    var recordingStarted = false;

    try {
      await controller.setFlashMode(FlashMode.off);
      await Future.delayed(const Duration(milliseconds: 200));

      await controller.startVideoRecording();
      recordingStarted = true;
      await Future.delayed(duration);

      final capture = await controller.stopVideoRecording();
      recordingStarted = false;
      temporaryVideoPath = capture.path;

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
          frameIntervalSeconds: 1,
          maxFrames: 2,
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
      final temporaryVideoDeleted =
          await _deleteTemporaryVideo(temporaryVideoPath);
      if (temporaryVideoDeleted) {
        temporaryVideoPath = null;
      }

      return {
        'type': 'SIGILLUM_PHOTO_TEMPORAL_VIDEO_PROBE_V1',
        'analysisStatus': analyzed ? 'ANALYZED' : 'NOT_ANALYZED',
        'captureDurationMs': duration.inMilliseconds,
        'temporaryVideoDeletedAfterAnalysis': temporaryVideoDeleted,
        'screenReplayAnalysis': {
          ...opticalAnalysis,
          'decisionRole': 'PRE_CAPTURE_TEMPORAL_EVIDENCE',
          'captureSource': 'PHOTO_TECHNICAL_MINI_VIDEO',
        },
        'mlScreenReplayAnalysis': {
          ...mlAnalysis,
          'decisionRole': 'PRE_CAPTURE_TEMPORAL_EVIDENCE',
          'captureSource': 'PHOTO_TECHNICAL_MINI_VIDEO',
        },
      };
    } catch (e) {
      if (recordingStarted && controller.value.isRecordingVideo) {
        try {
          final capture = await controller.stopVideoRecording();
          temporaryVideoPath ??= capture.path;
        } catch (_) {}
      }
      return _unknown('PHOTO_TEMPORAL_CAPTURE_FAILED', error: e);
    } finally {
      if (temporaryVideoPath != null) {
        try {
          final file = File(temporaryVideoPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<bool> _deleteTemporaryVideo(String? path) async {
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

  Map<String, dynamic> _unknown(String reason, {Object? error}) {
    return {
      'type': 'SIGILLUM_PHOTO_TEMPORAL_VIDEO_PROBE_V1',
      'analysisStatus': 'NOT_ANALYZED',
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
