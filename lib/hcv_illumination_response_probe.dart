import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';

/// Measures how strongly the framed scene responds to a brief external light
/// pulse while exposure is locked. This is deliberately asymmetric evidence:
/// a strong response can support a reflective-surface conflict, while a weak
/// response never proves that the scene is a display.
class HCVIlluminationResponseProbe {
  const HCVIlluminationResponseProbe();

  static const int framesPerPhase = 4;
  static const Duration phaseTimeout = Duration(milliseconds: 900);
  static const Duration torchSettle = Duration(milliseconds: 110);
  static const Duration opticalRestoreSettle = Duration(milliseconds: 250);

  Future<Map<String, dynamic>> capture(
    CameraController controller, {
    required FlashMode restoreFlash,
  }) async {
    if (!controller.value.isInitialized || controller.value.isRecordingVideo) {
      return unavailable('CAMERA_NOT_READY_FOR_ILLUMINATION_RESPONSE');
    }

    final offFrames = <List<double>>[];
    final onFrames = <List<double>>[];
    final offReady = Completer<void>();
    final onReady = Completer<void>();
    var phase = 0; // 0=OFF, 1=transition, 2=ON, 3=finished
    var streamStarted = false;
    var exposureLockApplied = false;
    var torchApplied = false;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.setFlashMode(FlashMode.off);

      try {
        await controller.setExposureMode(ExposureMode.locked);
        exposureLockApplied = true;
      } catch (_) {
        exposureLockApplied = false;
      }

      await Future.delayed(const Duration(milliseconds: 70));

      await controller.startImageStream((image) {
        if (phase != 0 && phase != 2) return;
        final cells = _cellLuma(image);
        if (cells == null || cells.length != 9) return;
        if (phase == 0) {
          if (offFrames.length < framesPerPhase) offFrames.add(cells);
          if (offFrames.length >= framesPerPhase && !offReady.isCompleted) {
            phase = 1;
            offReady.complete();
          }
        } else if (phase == 2) {
          if (onFrames.length < framesPerPhase) onFrames.add(cells);
          if (onFrames.length >= framesPerPhase && !onReady.isCompleted) {
            phase = 3;
            onReady.complete();
          }
        }
      });
      streamStarted = true;

      await offReady.future.timeout(phaseTimeout);

      try {
        await controller.setFlashMode(FlashMode.torch);
        torchApplied = true;
      } catch (error) {
        return unavailable(
          'TORCH_UNAVAILABLE_FOR_ILLUMINATION_RESPONSE',
          error: error,
          extra: {
            'offFramesCaptured': offFrames.length,
            'exposureLockApplied': exposureLockApplied,
          },
        );
      }

      await Future.delayed(torchSettle);
      phase = 2;
      await onReady.future.timeout(phaseTimeout);

      return _analyze(
        offFrames: offFrames,
        onFrames: onFrames,
        exposureLockApplied: exposureLockApplied,
        torchApplied: torchApplied,
      );
    } on TimeoutException catch (error) {
      return unavailable(
        'ILLUMINATION_RESPONSE_FRAME_TIMEOUT',
        error: error,
        extra: {
          'offFramesCaptured': offFrames.length,
          'onFramesCaptured': onFrames.length,
          'exposureLockApplied': exposureLockApplied,
          'torchApplied': torchApplied,
        },
      );
    } catch (error) {
      return unavailable(
        'ILLUMINATION_RESPONSE_CAPTURE_FAILED',
        error: error,
        extra: {
          'offFramesCaptured': offFrames.length,
          'onFramesCaptured': onFrames.length,
          'exposureLockApplied': exposureLockApplied,
          'torchApplied': torchApplied,
        },
      );
    } finally {
      phase = 3;
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (streamStarted && controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }
      try {
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setExposurePoint(null);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFocusPoint(null);
      } catch (_) {}
      try {
        await controller.setFlashMode(restoreFlash);
      } catch (_) {}
      await Future.delayed(opticalRestoreSettle);
    }
  }

  Map<String, dynamic> _analyze({
    required List<List<double>> offFrames,
    required List<List<double>> onFrames,
    required bool exposureLockApplied,
    required bool torchApplied,
  }) {
    if (offFrames.length < framesPerPhase ||
        onFrames.length < framesPerPhase ||
        offFrames.any((f) => f.length != 9) ||
        onFrames.any((f) => f.length != 9)) {
      return unavailable('ILLUMINATION_RESPONSE_NOT_ENOUGH_VALID_FRAMES');
    }

    final offCells = List<double>.generate(9, (cell) {
      final values = offFrames.map((f) => f[cell]).toList()..sort();
      return _median(values);
    });
    final onCells = List<double>.generate(9, (cell) {
      final values = onFrames.map((f) => f[cell]).toList()..sort();
      return _median(values);
    });

    final absoluteIncrease = <double>[];
    final relativeIncrease = <double>[];
    var responsiveCellCount = 0;
    var saturatedCellCount = 0;
    for (var i = 0; i < 9; i++) {
      final delta = onCells[i] - offCells[i];
      final relative = delta / max(0.05, offCells[i]);
      absoluteIncrease.add(delta);
      relativeIncrease.add(relative);
      if (delta >= 0.08 && relative >= 0.20) responsiveCellCount++;
      if (onCells[i] >= 0.98) saturatedCellCount++;
    }

    final absSorted = List<double>.from(absoluteIncrease)..sort();
    final relSorted = List<double>.from(relativeIncrease)..sort();
    final medianAbsoluteIncrease = _median(absSorted);
    final medianRelativeIncrease = _median(relSorted);
    final lowerQuartileRelativeIncrease = relSorted[2];

    // Intentionally stringent. This is not a generic reality classifier; it
    // only marks a large, spatially broad response to external illumination.
    final qualitySufficient =
        exposureLockApplied && torchApplied && saturatedCellCount <= 6;
    final strongReflectiveResponse = qualitySufficient &&
        medianAbsoluteIncrease >= 0.12 &&
        medianRelativeIncrease >= 0.35 &&
        lowerQuartileRelativeIncrease >= 0.20 &&
        responsiveCellCount >= 7;

    return {
      'type': 'SIGILLUM_ILLUMINATION_RESPONSE_PROBE_V1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'CONSERVATIVE_REFLECTION_CONFLICT_SUPPORT_ONLY',
      'captureSource':
          'FLUTTER_CAMERA_IMAGE_STREAM_FIXED_EXPOSURE_TORCH_OFF_ON',
      'exposureLockApplied': exposureLockApplied,
      'torchApplied': torchApplied,
      'framesPerPhaseTarget': framesPerPhase,
      'offFramesAnalyzed': offFrames.length,
      'onFramesAnalyzed': onFrames.length,
      'offCellLumaMedians': offCells,
      'onCellLumaMedians': onCells,
      'cellAbsoluteLumaIncrease': absoluteIncrease,
      'cellRelativeLumaIncrease': relativeIncrease,
      'medianAbsoluteLumaIncrease': medianAbsoluteIncrease,
      'medianRelativeLumaIncrease': medianRelativeIncrease,
      'lowerQuartileRelativeLumaIncrease': lowerQuartileRelativeIncrease,
      'responsiveCellCount': responsiveCellCount,
      'saturatedCellCount': saturatedCellCount,
      'measurementQualitySufficient': qualitySufficient,
      'strongReflectiveResponse': strongReflectiveResponse,
      'note':
          'A strong response supports a reflective-surface conflict only. A weak response never proves display emission.',
    };
  }

  static Map<String, dynamic> unavailable(
    String reason, {
    Object? error,
    Map<String, dynamic>? extra,
  }) {
    return {
      'type': 'SIGILLUM_ILLUMINATION_RESPONSE_PROBE_V1',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole': 'CONSERVATIVE_REFLECTION_CONFLICT_SUPPORT_ONLY',
      'reason': reason,
      if (error != null) 'error': error.toString(),
      if (extra != null) ...extra,
    };
  }

  List<double>? _cellLuma(CameraImage image) {
    if (image.width < 3 || image.height < 3 || image.planes.isEmpty) {
      return null;
    }
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;
    final bytesPerPixel = plane.bytesPerPixel ?? 1;
    if (bytesPerRow <= 0 || bytesPerPixel <= 0 || bytes.isEmpty) return null;

    final result = <double>[];
    for (var gridRow = 0; gridRow < 3; gridRow++) {
      for (var gridColumn = 0; gridColumn < 3; gridColumn++) {
        final x0 = image.width * gridColumn ~/ 3;
        final x1 = image.width * (gridColumn + 1) ~/ 3;
        final y0 = image.height * gridRow ~/ 3;
        final y1 = image.height * (gridRow + 1) ~/ 3;
        final xStep = max(1, (x1 - x0) ~/ 14);
        final yStep = max(1, (y1 - y0) ~/ 14);
        var sum = 0.0;
        var count = 0;

        for (var y = y0; y < y1; y += yStep) {
          for (var x = x0; x < x1; x += xStep) {
            final index = y * bytesPerRow + x * bytesPerPixel;
            if (index < 0 || index >= bytes.length) continue;
            double luma;
            if (image.planes.length == 1 &&
                bytesPerPixel >= 4 &&
                index + 2 < bytes.length) {
              final b = bytes[index].toDouble();
              final g = bytes[index + 1].toDouble();
              final r = bytes[index + 2].toDouble();
              luma = (0.114 * b + 0.587 * g + 0.299 * r) / 255.0;
            } else {
              luma = bytes[index] / 255.0;
            }
            sum += luma;
            count++;
          }
        }
        result.add(count == 0 ? 0.0 : sum / count);
      }
    }
    return result;
  }

  double _median(List<double> sorted) {
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2.0;
  }
}
