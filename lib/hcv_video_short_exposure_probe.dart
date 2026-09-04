import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'hcv_display_microtexture_probe.dart';

class HCVVideoShortExposureProbe {
  const HCVVideoShortExposureProbe();

  static const MethodChannel _channel = MethodChannel('hcv.cameraProbe');
  static const double _requestedShortExposure = 1.0 / 240.0;
  static const Duration _zoomSettle = Duration(milliseconds: 150);
  static const Duration _exposureSettle = Duration(milliseconds: 100);
  static const Duration _captureWindow = Duration(milliseconds: 480);
  static const Duration _restoreSettle = Duration(milliseconds: 220);

  Future<Map<String, dynamic>> capture(CameraController controller) async {
    if (!Platform.isIOS) return _unavailable('IOS_ONLY');
    if (!controller.value.isInitialized)
      return _unavailable('CAMERA_NOT_READY');
    if (controller.value.isStreamingImages ||
        controller.value.isRecordingVideo) {
      return _unavailable('CAMERA_BUSY');
    }

    final uniqueId = controller.description.name;
    Map<String, dynamic>? originalState;
    String? path;
    var recording = false;
    final originalFlash = controller.value.flashMode;

    try {
      originalState = await _invokeMap('snapshotCameraState', {
        'deviceUniqueId': uniqueId,
      });
      if (originalState == null)
        return _unavailable('CAMERA_STATE_UNAVAILABLE');

      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final originalZoom =
          (originalState['zoomFactor'] as num?)?.toDouble() ?? minZoom;
      final oneX = 1.0.clamp(minZoom, maxZoom).toDouble();

      await controller.setFlashMode(FlashMode.off);
      await _invokeMap('setContinuousAutoExposure', {
        'deviceUniqueId': uniqueId,
      });
      await controller.setZoomLevel(oneX);
      await Future.delayed(_zoomSettle);

      await _invokeMap('applyShortExposure', {
        'deviceUniqueId': uniqueId,
        'targetDurationSeconds': _requestedShortExposure,
      });
      await Future.delayed(_exposureSettle);

      final shortState = await _invokeMap('snapshotCameraState', {
        'deviceUniqueId': uniqueId,
      });

      await controller.startVideoRecording();
      recording = true;
      final clock = Stopwatch()..start();
      await Future.delayed(_captureWindow);
      final video = await controller.stopVideoRecording();
      recording = false;
      clock.stop();
      path = video.path;

      await _restore(
        controller,
        uniqueId: uniqueId,
        originalState: originalState,
        originalZoom: originalZoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        originalFlash: originalFlash,
      );

      return {
        'type': 'SIGILLUM_VIDEO_SHORT_EXPOSURE_CAPTURE_V1',
        'analysisStatus': 'CAPTURED_NOT_ANALYZED',
        'decisionRole': 'ACTIVE_PHYSICAL_DISPLAY_DISCRIMINATOR',
        'path': path,
        'deviceUniqueId': uniqueId,
        'targetZoom': oneX,
        'targetShortExposureSeconds': _requestedShortExposure,
        'captureDurationMs': clock.elapsedMilliseconds,
        'phases': [
          {
            'id': 'SHORT_1X',
            'startMs': 0,
            'endMs': clock.elapsedMilliseconds,
            'requestedZoom': oneX,
            'exposureMode': 'CUSTOM_SHORT',
            if (shortState != null) 'exposureState': shortState,
          },
        ],
        'spatialPolicy': const {
          'gridRows': 3,
          'gridColumns': 3,
          'requiredDisplayCoverageCells': 9,
          'allowedRealityEscapeCells': 0,
          'decisionEnabled': true,
        },
      };
    } catch (error) {
      if (recording && controller.value.isRecordingVideo) {
        try {
          path = (await controller.stopVideoRecording()).path;
        } catch (_) {}
      }
      if (path != null) await _delete(path);
      if (originalState != null) {
        try {
          final minZoom = await controller.getMinZoomLevel();
          final maxZoom = await controller.getMaxZoomLevel();
          await _restore(
            controller,
            uniqueId: uniqueId,
            originalState: originalState,
            originalZoom:
                (originalState['zoomFactor'] as num?)?.toDouble() ?? minZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
            originalFlash: originalFlash,
          );
        } catch (_) {}
      }
      return _unavailable('VIDEO_SHORT_EXPOSURE_CAPTURE_FAILED', error: error);
    }
  }

  Future<Map<String, dynamic>> analyzeCapture(Map<String, dynamic>? capture) {
    return const HCVDisplayMicrotextureShadowProbe().analyzeCapture(capture);
  }

  Future<bool> discardCapture(Map<String, dynamic>? capture) {
    return const HCVDisplayMicrotextureShadowProbe().discardCapture(capture);
  }

  Future<Map<String, dynamic>?> _invokeMap(
    String method,
    Map<String, dynamic> args,
  ) async {
    final value = await _channel.invokeMapMethod<String, dynamic>(method, args);
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  Future<void> _restore(
    CameraController controller, {
    required String uniqueId,
    required Map<String, dynamic> originalState,
    required double originalZoom,
    required double minZoom,
    required double maxZoom,
    required FlashMode originalFlash,
  }) async {
    try {
      await _channel.invokeMethod<void>('restoreCameraState', {
        'deviceUniqueId': uniqueId,
        'state': originalState,
      });
    } catch (_) {}
    try {
      await controller.setZoomLevel(
        originalZoom.clamp(minZoom, maxZoom).toDouble(),
      );
    } catch (_) {}
    try {
      await controller.setFlashMode(originalFlash);
    } catch (_) {}
    await Future.delayed(_restoreSettle);
  }

  Future<bool> _delete(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return true;
      await file.delete();
      return !await file.exists();
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _unavailable(String reason, {Object? error}) => {
    'type': 'SIGILLUM_VIDEO_SHORT_EXPOSURE_CAPTURE_V1',
    'analysisStatus': 'NOT_CAPTURED',
    'decisionRole': 'ACTIVE_PHYSICAL_DISPLAY_DISCRIMINATOR',
    'reason': reason,
    if (error != null) 'error': error.toString(),
  };
}
