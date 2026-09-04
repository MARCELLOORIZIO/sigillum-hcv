import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVDisplayMicrotextureShadowProbe {
  const HCVDisplayMicrotextureShadowProbe();

  static const MethodChannel _channel = MethodChannel('hcv.cameraProbe');
  static const Duration _phaseDuration = Duration(milliseconds: 350);
  static const Duration _exposureSettle = Duration(milliseconds: 90);
  static const Duration _zoomSettle = Duration(milliseconds: 180);
  static const double _requestedShortExposure = 1.0 / 240.0;

  Future<Map<String, dynamic>> capture(CameraController controller) async {
    if (!Platform.isIOS) return _captureUnavailable('IOS_ONLY');
    if (!controller.value.isInitialized) {
      return _captureUnavailable('CAMERA_NOT_READY');
    }
    if (controller.value.isStreamingImages ||
        controller.value.isRecordingVideo) {
      return _captureUnavailable('CAMERA_BUSY');
    }

    final uniqueId = controller.description.name;
    Map<String, dynamic>? originalState;
    String? path;
    var recording = false;

    try {
      originalState = await _invokeMap('snapshotCameraState', {
        'deviceUniqueId': uniqueId,
      });
      if (originalState == null) {
        return _captureUnavailable('CAMERA_STATE_UNAVAILABLE');
      }

      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final originalZoom =
          (originalState['zoomFactor'] as num?)?.toDouble() ?? minZoom;
      final oneX = 1.0.clamp(minZoom, maxZoom).toDouble();
      final tenX = 10.0.clamp(minZoom, maxZoom).toDouble();

      await controller.setFlashMode(FlashMode.off);
      await _invokeMap('setContinuousAutoExposure', {
        'deviceUniqueId': uniqueId,
      });
      await controller.setZoomLevel(oneX);
      await Future.delayed(_zoomSettle);

      await controller.startVideoRecording();
      recording = true;
      final clock = Stopwatch()..start();
      final phases = <Map<String, dynamic>>[];

      Future<void> phase(String id, double zoom, String exposure) async {
        final state = await _invokeMap('snapshotCameraState', {
          'deviceUniqueId': uniqueId,
        });
        final start = clock.elapsedMilliseconds;
        await Future.delayed(_phaseDuration);
        phases.add({
          'id': id,
          'startMs': start,
          'endMs': clock.elapsedMilliseconds,
          'requestedZoom': zoom,
          'exposureMode': exposure,
          if (state != null) 'exposureState': state,
        });
      }

      await phase('NORMAL_1X', oneX, 'CONTINUOUS_AUTO');

      await _invokeMap('applyShortExposure', {
        'deviceUniqueId': uniqueId,
        'targetDurationSeconds': _requestedShortExposure,
      });
      await Future.delayed(_exposureSettle);
      await phase('SHORT_1X', oneX, 'CUSTOM_SHORT');

      await _invokeMap('setContinuousAutoExposure', {
        'deviceUniqueId': uniqueId,
      });
      await controller.setZoomLevel(tenX);
      await Future.delayed(_zoomSettle);
      await phase('NORMAL_10X', tenX, 'CONTINUOUS_AUTO');

      await _invokeMap('applyShortExposure', {
        'deviceUniqueId': uniqueId,
        'targetDurationSeconds': _requestedShortExposure,
      });
      await Future.delayed(_exposureSettle);
      await phase('SHORT_10X', tenX, 'CUSTOM_SHORT');

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
      );

      return {
        'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_CAPTURE_V1',
        'analysisStatus': 'CAPTURED_NOT_ANALYZED',
        'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
        'path': path,
        'deviceUniqueId': uniqueId,
        'originalCameraState': originalState,
        'targetZoom': tenX,
        'targetShortExposureSeconds': _requestedShortExposure,
        'captureDurationMs': clock.elapsedMilliseconds,
        'phases': phases,
        'spatialPolicy': const {
          'gridRows': 3,
          'gridColumns': 3,
          'requiredDisplayCoverageCells': 9,
          'allowedRealityEscapeCells': 0,
          'decisionEnabled': false,
          'note': '9/9 coverage is the future policy; no numeric production threshold is applied in shadow mode.',
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
          );
        } catch (_) {}
      }
      return _captureUnavailable('ACTIVE_SHADOW_CAPTURE_FAILED', error: error);
    }
  }

  Future<Map<String, dynamic>> analyzeCapture(
    Map<String, dynamic>? capture,
  ) async {
    final videoPath = capture?['path']?.toString();
    if (videoPath == null ||
        videoPath.isEmpty ||
        !await File(videoPath).exists()) {
      return _analysisUnavailable('SHADOW_VIDEO_NOT_FOUND');
    }
    final rawPhases = capture?['phases'];
    if (rawPhases is! List || rawPhases.isEmpty) {
      return _analysisUnavailable('PHASE_METADATA_MISSING');
    }

    final root = Directory(
      p.join(
        (await getTemporaryDirectory()).path,
        'hcv_microtexture_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    try {
      await root.create(recursive: true);
      final results = <String, Map<String, dynamic>>{};
      for (var i = 0; i < rawPhases.length; i++) {
        final raw = rawPhases[i];
        if (raw is! Map) continue;
        final phase = Map<String, dynamic>.from(raw);
        final id = phase['id']?.toString() ?? 'PHASE_$i';
        final startMs = (phase['startMs'] as num?)?.toInt();
        final endMs = (phase['endMs'] as num?)?.toInt();
        if (startMs == null || endMs == null || endMs <= startMs) continue;
        final dir = Directory(p.join(root.path, id.toLowerCase()));
        await dir.create(recursive: true);
        final frames = await _extractFrames(
          videoPath,
          dir,
          startMs: startMs,
          endMs: endMs,
        );
        results[id] = {...phase, ..._phaseMetrics(frames)};
      }

      double? structured(String id) =>
          (results[id]?['structuredTemporalAxisRatio'] as num?)?.toDouble();

      return {
        'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_ANALYSIS_V1',
        'analysisStatus': results.isEmpty ? 'NOT_ANALYZED' : 'ANALYZED',
        'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
        'productionDecisionChanged': false,
        'phaseResults': results,
        'comparisons': {
          'shortExposureGain1x': _gain(
            structured('SHORT_1X'),
            structured('NORMAL_1X'),
          ),
          'shortExposureGain10x': _gain(
            structured('SHORT_10X'),
            structured('NORMAL_10X'),
          ),
          'zoomGainNormal': _gain(
            structured('NORMAL_10X'),
            structured('NORMAL_1X'),
          ),
          'zoomGainShort': _gain(
            structured('SHORT_10X'),
            structured('SHORT_1X'),
          ),
        },
        'spatialPolicy': capture?['spatialPolicy'],
        'note': 'Raw 1x/10x and normal/short-shutter metrics. This block is never supplied to production fusion.',
      };
    } catch (error) {
      return _analysisUnavailable('SHADOW_ANALYSIS_FAILED', error: error);
    } finally {
      try {
        if (await root.exists()) await root.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<bool> discardCapture(Map<String, dynamic>? capture) async {
    final path = capture?['path']?.toString();
    if (path == null || path.isEmpty) return true;
    return await _delete(path);
  }

  Future<List<img.Image>> _extractFrames(
    String videoPath,
    Directory dir, {
    required int startMs,
    required int endMs,
  }) async {
    final start = startMs / 1000.0;
    final duration = max(0.10, (endMs - startMs) / 1000.0).toDouble();
    final pattern = p.join(dir.path, 'frame_%03d.png');
    final command =
        "-y -ss ${start.toStringAsFixed(4)} -i '$videoPath' "
        "-t ${duration.toStringAsFixed(4)} -vf \"fps=15\" -frames:v 6 '$pattern'";
    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();
    if (code == null || !ReturnCode.isSuccess(code)) return <img.Image>[];

    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.png'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final frames = <img.Image>[];
    for (final file in files) {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded != null) frames.add(decoded);
    }
    return frames;
  }

  Map<String, dynamic> _phaseMetrics(List<img.Image> frames) {
    if (frames.length < 3) {
      return const {
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'NOT_ENOUGH_NATIVE_FRAMES',
      };
    }

    final cells = <Map<String, dynamic>>[];
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        cells.add({
          'row': row,
          'column': column,
          ..._cellMetrics(frames, row: row, column: column),
        });
      }
    }

    final temporal =
        cells
            .map(
              (cell) =>
                  (cell['structuredTemporalAxisRatio'] as num?)?.toDouble(),
            )
            .whereType<double>()
            .toList()
          ..sort();
    final chroma = cells
        .map((cell) => (cell['fineChromaLumaRatio'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final lattice = cells
        .map((cell) => (cell['flatFieldLatticeScore'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    return {
      'analysisStatus': temporal.length == 9 ? 'ANALYZED' : 'PARTIAL',
      'framesAnalyzed': frames.length,
      'cellsAnalyzed': temporal.length,
      'requiredDisplayCoverageCells': 9,
      'allowedRealityEscapeCells': 0,
      'coverageDecisionEnabled': false,
      'structuredTemporalAxisRatio': _mean(temporal),
      'minimumCellStructuredTemporalAxisRatio': temporal.isEmpty
          ? null
          : temporal.first,
      'medianCellStructuredTemporalAxisRatio': _median(temporal),
      'maximumCellStructuredTemporalAxisRatio': temporal.isEmpty
          ? null
          : temporal.last,
      'fineChromaLumaRatio': _mean(chroma),
      'flatFieldLatticeScore': _mean(lattice),
      'cells': cells,
    };
  }

  Map<String, dynamic> _cellMetrics(
    List<img.Image> frames, {
    required int row,
    required int column,
  }) {
    final axis = <double>[];
    final rows = <double>[];
    final columns = <double>[];
    for (var i = 1; i < frames.length; i++) {
      final temporal = _temporalMetrics(
        frames[i - 1],
        frames[i],
        row: row,
        column: column,
      );
      axis.add(temporal['axis']!);
      rows.add(temporal['row']!);
      columns.add(temporal['column']!);
    }
    final spatial = _spatialMetrics(frames.last, row: row, column: column);
    return {
      'structuredTemporalAxisRatio': _mean(axis),
      'rowTemporalCoherence': _mean(rows),
      'columnTemporalCoherence': _mean(columns),
      ...spatial,
    };
  }

  Map<String, double> _temporalMetrics(
    img.Image a,
    img.Image b, {
    required int row,
    required int column,
  }) {
    final width = min(a.width, b.width);
    final height = min(a.height, b.height);
    final x0 = (width * column / 3).floor();
    final x1 = (width * (column + 1) / 3).floor();
    final y0 = (height * row / 3).floor();
    final y1 = (height * (row + 1) / 3).floor();
    const step = 4;

    var global = 0.0;
    var count = 0;
    for (var y = y0; y < y1; y += step) {
      for (var x = x0; x < x1; x += step) {
        global += _luma(b.getPixel(x, y)) - _luma(a.getPixel(x, y));
        count++;
      }
    }
    if (count == 0) return const {'axis': 0.0, 'row': 0.0, 'column': 0.0};
    final globalDelta = global / count;

    final rowProfile = <double>[];
    final columnProfile = <double>[];
    var residualSq = 0.0;
    var residualCount = 0;

    for (var y = y0; y < y1; y += step) {
      var sum = 0.0;
      var n = 0;
      for (var x = x0; x < x1; x += step) {
        final d =
            _luma(b.getPixel(x, y)) - _luma(a.getPixel(x, y)) - globalDelta;
        sum += d;
        residualSq += d * d;
        residualCount++;
        n++;
      }
      if (n > 0) rowProfile.add(sum / n);
    }

    for (var x = x0; x < x1; x += step) {
      var sum = 0.0;
      var n = 0;
      for (var y = y0; y < y1; y += step) {
        sum += _luma(b.getPixel(x, y)) - _luma(a.getPixel(x, y)) - globalDelta;
        n++;
      }
      if (n > 0) columnProfile.add(sum / n);
    }

    final residual = sqrt(residualSq / max(1, residualCount));
    final rowRms = _rms(rowProfile);
    final columnRms = _rms(columnProfile);
    final denom = max(1e-6, residual);
    return {
      'axis': sqrt(rowRms * rowRms + columnRms * columnRms) / denom,
      'row': rowRms / denom,
      'column': columnRms / denom,
    };
  }

  Map<String, double> _spatialMetrics(
    img.Image image, {
    required int row,
    required int column,
  }) {
    final x0 = (image.width * column / 3).floor();
    final x1 = (image.width * (column + 1) / 3).floor();
    final y0 = (image.height * row / 3).floor();
    final y1 = (image.height * (row + 1) / 3).floor();
    const step = 2;
    var lumaEnergy = 0.0;
    var chromaH = 0.0;
    var chromaV = 0.0;
    var samples = 0;
    final chromaSeries = <double>[];

    for (var y = y0; y < y1 - step; y += step) {
      for (var x = x0; x < x1 - step; x += step) {
        final c = image.getPixel(x, y);
        final right = image.getPixel(x + step, y);
        final down = image.getPixel(x, y + step);
        final lc = _luma(c);
        lumaEnergy += (lc - _luma(right)).abs() + (lc - _luma(down)).abs();
        final cc = _chroma(c);
        chromaH += (cc - _chroma(right)).abs();
        chromaV += (cc - _chroma(down)).abs();
        chromaSeries.add(cc);
        samples++;
      }
    }

    if (samples == 0) {
      return const {
        'highFrequencyLumaEnergy': 0.0,
        'fineChromaLumaRatio': 0.0,
        'chromaAnisotropy': 0.0,
        'flatFieldLatticeScore': 0.0,
      };
    }
    final luma = lumaEnergy / (2 * samples);
    final chroma = (chromaH + chromaV) / (2 * samples);
    return {
      'highFrequencyLumaEnergy': luma,
      'fineChromaLumaRatio': chroma / max(1e-6, luma),
      'chromaAnisotropy':
          max(chromaH, chromaV) / max(1e-6, min(chromaH, chromaV)),
      'flatFieldLatticeScore': _autocorrelationPeak(chromaSeries),
    };
  }

  double _autocorrelationPeak(List<double> values) {
    if (values.length < 32) return 0.0;
    final mean = _mean(values) ?? 0.0;
    var variance = 0.0;
    for (final value in values) {
      final d = value - mean;
      variance += d * d;
    }
    if (variance <= 1e-9) return 0.0;
    var best = 0.0;
    for (var lag = 1; lag <= 8; lag++) {
      var covariance = 0.0;
      for (var i = lag; i < values.length; i++) {
        covariance += (values[i] - mean) * (values[i - lag] - mean);
      }
      best = max(best, covariance / variance);
    }
    return best.clamp(0.0, 1.0).toDouble();
  }

  double _luma(img.Pixel pixel) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
  }

  double _chroma(img.Pixel pixel) {
    final r = pixel.r.toDouble() / 255.0;
    final g = pixel.g.toDouble() / 255.0;
    final b = pixel.b.toDouble() / 255.0;
    return (r - g).abs() + (b - g).abs();
  }

  double _rms(List<double> values) {
    if (values.isEmpty) return 0.0;
    var total = 0.0;
    for (final value in values) total += value * value;
    return sqrt(total / values.length);
  }

  double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2.0;
  }

  double? _gain(double? numerator, double? denominator) {
    if (numerator == null || denominator == null || denominator.abs() < 1e-9) {
      return null;
    }
    return numerator / denominator;
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
    await Future.delayed(const Duration(milliseconds: 260));
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

  Map<String, dynamic> _captureUnavailable(String reason, {Object? error}) => {
    'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_CAPTURE_V1',
    'analysisStatus': 'NOT_CAPTURED',
    'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
    'reason': reason,
    if (error != null) 'error': error.toString(),
  };

  Map<String, dynamic> _analysisUnavailable(String reason, {Object? error}) => {
    'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_ANALYSIS_V1',
    'analysisStatus': 'NOT_ANALYZED',
    'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
    'productionDecisionChanged': false,
    'reason': reason,
    if (error != null) 'error': error.toString(),
  };
}
