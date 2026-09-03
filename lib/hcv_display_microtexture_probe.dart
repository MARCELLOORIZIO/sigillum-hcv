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

  static const MethodChannel _cameraProbeChannel =
      MethodChannel('hcv.cameraProbe');

  static const Duration _phaseDuration = Duration(milliseconds: 350);
  static const Duration _exposureSettle = Duration(milliseconds: 90);
  static const Duration _zoomSettle = Duration(milliseconds: 180);
  static const double _shortExposureSeconds = 1.0 / 240.0;

  Future<Map<String, dynamic>> capture(CameraController controller) async {
    if (!Platform.isIOS) {
      return _unavailable('IOS_ONLY_ACTIVE_EXPOSURE_PROBE');
    }
    if (!controller.value.isInitialized) {
      return _unavailable('CAMERA_NOT_READY');
    }
    if (controller.value.isStreamingImages ||
        controller.value.isRecordingVideo) {
      return _unavailable('CAMERA_BUSY');
    }

    final deviceUniqueId = controller.description.name;
    Map<String, dynamic>? originalState;
    String? temporaryVideoPath;
    var recordingStarted = false;

    try {
      originalState = await _invokeMap(
        'snapshotCameraState',
        {'deviceUniqueId': deviceUniqueId},
      );
      if (originalState == null) {
        return _unavailable('CAMERA_STATE_UNAVAILABLE');
      }

      final minZoom = await controller.getMinZoomLevel();
      final deviceMaxZoom = await controller.getMaxZoomLevel();
      final originalZoom =
          (originalState['zoomFactor'] as num?)?.toDouble() ?? minZoom;
      final oneX = 1.0.clamp(minZoom, deviceMaxZoom).toDouble();
      final tenX = 10.0.clamp(minZoom, deviceMaxZoom).toDouble();

      await controller.setFlashMode(FlashMode.off);
      await _invokeMap(
        'setContinuousAutoExposure',
        {'deviceUniqueId': deviceUniqueId},
      );
      await controller.setZoomLevel(oneX);
      await Future.delayed(_zoomSettle);

      await controller.startVideoRecording();
      recordingStarted = true;
      final stopwatch = Stopwatch()..start();
      final phases = <Map<String, dynamic>>[];

      Future<void> recordPhase({
        required String id,
        required double zoom,
        required String exposureMode,
        Map<String, dynamic>? exposureState,
      }) async {
        final startMs = stopwatch.elapsedMilliseconds;
        await Future.delayed(_phaseDuration);
        phases.add({
          'id': id,
          'startMs': startMs,
          'endMs': stopwatch.elapsedMilliseconds,
          'requestedZoom': zoom,
          'exposureMode': exposureMode,
          if (exposureState != null) 'exposureState': exposureState,
        });
      }

      final normal1xState = await _invokeMap(
        'snapshotCameraState',
        {'deviceUniqueId': deviceUniqueId},
      );
      await recordPhase(
        id: 'NORMAL_1X',
        zoom: oneX,
        exposureMode: 'CONTINUOUS_AUTO',
        exposureState: normal1xState,
      );

      final short1xState = await _invokeMap(
        'applyShortExposure',
        {
          'deviceUniqueId': deviceUniqueId,
          'targetDurationSeconds': _shortExposureSeconds,
        },
      );
      await Future.delayed(_exposureSettle);
      await recordPhase(
        id: 'SHORT_1X',
        zoom: oneX,
        exposureMode: 'CUSTOM_SHORT',
        exposureState: short1xState,
      );

      await _invokeMap(
        'setContinuousAutoExposure',
        {'deviceUniqueId': deviceUniqueId},
      );
      await controller.setZoomLevel(tenX);
      await Future.delayed(_zoomSettle);
      final normal10xState = await _invokeMap(
        'snapshotCameraState',
        {'deviceUniqueId': deviceUniqueId},
      );
      await recordPhase(
        id: 'NORMAL_10X',
        zoom: tenX,
        exposureMode: 'CONTINUOUS_AUTO',
        exposureState: normal10xState,
      );

      final short10xState = await _invokeMap(
        'applyShortExposure',
        {
          'deviceUniqueId': deviceUniqueId,
          'targetDurationSeconds': _shortExposureSeconds,
        },
      );
      await Future.delayed(_exposureSettle);
      await recordPhase(
        id: 'SHORT_10X',
        zoom: tenX,
        exposureMode: 'CUSTOM_SHORT',
        exposureState: short10xState,
      );

      final capture = await controller.stopVideoRecording();
      recordingStarted = false;
      stopwatch.stop();
      temporaryVideoPath = capture.path;

      await _restoreCameraState(
        controller,
        deviceUniqueId: deviceUniqueId,
        originalState: originalState,
        originalZoom: originalZoom,
        minZoom: minZoom,
        maxZoom: deviceMaxZoom,
      );

      return {
        'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_CAPTURE_V1',
        'analysisStatus': 'CAPTURED_NOT_ANALYZED',
        'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
        'path': temporaryVideoPath,
        'deviceUniqueId': deviceUniqueId,
        'originalCameraState': originalState,
        'targetZoom': tenX,
        'targetShortExposureSeconds': _shortExposureSeconds,
        'captureDurationMs': stopwatch.elapsedMilliseconds,
        'phases': phases,
        'spatialPolicy': const {
          'gridRows': 3,
          'gridColumns': 3,
          'requiredDisplayCoverageCells': 9,
          'allowedRealityEscapeCells': 0,
          'decisionEnabled': false,
          'note':
              'The 9/9 rule is recorded now, but no production threshold is applied until calibrated on physical HCVPACK data.',
        },
      };
    } catch (error) {
      if (recordingStarted && controller.value.isRecordingVideo) {
        try {
          final capture = await controller.stopVideoRecording();
          temporaryVideoPath ??= capture.path;
        } catch (_) {}
      }
      if (temporaryVideoPath != null) {
        await _deletePath(temporaryVideoPath);
      }
      if (originalState != null) {
        try {
          final minZoom = await controller.getMinZoomLevel();
          final maxZoom = await controller.getMaxZoomLevel();
          await _restoreCameraState(
            controller,
            deviceUniqueId: deviceUniqueId,
            originalState: originalState,
            originalZoom:
                (originalState['zoomFactor'] as num?)?.toDouble() ?? minZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
          );
        } catch (_) {}
      }
      return _unavailable(
        'ACTIVE_SHADOW_CAPTURE_FAILED',
        error: error,
      );
    }
  }

  Future<Map<String, dynamic>> analyzeCapture(
    Map<String, dynamic>? capture,
  ) async {
    if (capture == null) {
      return _analysisUnavailable('SHADOW_CAPTURE_MISSING');
    }
    final path = capture['path']?.toString();
    if (path == null || path.isEmpty || !await File(path).exists()) {
      return _analysisUnavailable('SHADOW_VIDEO_NOT_FOUND');
    }

    final rawPhases = capture['phases'];
    if (rawPhases is! List || rawPhases.isEmpty) {
      return _analysisUnavailable('SHADOW_PHASE_METADATA_MISSING');
    }

    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempDir.path,
        'hcv_microtexture_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    try {
      await workDir.create(recursive: true);
      final phaseResults = <String, Map<String, dynamic>>{};

      for (var index = 0; index < rawPhases.length; index++) {
        final raw = rawPhases[index];
        if (raw is! Map) continue;
        final phase = Map<String, dynamic>.from(raw);
        final id = phase['id']?.toString() ?? 'PHASE_$index';
        final startMs = (phase['startMs'] as num?)?.toInt();
        final endMs = (phase['endMs'] as num?)?.toInt();
        if (startMs == null || endMs == null || endMs <= startMs) continue;

        final phaseDir = Directory(p.join(workDir.path, id.toLowerCase()));
        await phaseDir.create(recursive: true);
        final frames = await _extractPhaseFrames(
          path,
          phaseDir,
          startMs: startMs,
          endMs: endMs,
        );
        phaseResults[id] = {
          ...phase,
          ..._analyzeFrames(frames),
        };
      }

      final normal1x = phaseResults['NORMAL_1X'];
      final short1x = phaseResults['SHORT_1X'];
      final normal10x = phaseResults['NORMAL_10X'];
      final short10x = phaseResults['SHORT_10X'];

      double? ratio(Map<String, dynamic>? value) =>
          (value?['structuredTemporalAxisRatio'] as num?)?.toDouble();

      return {
        'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_ANALYSIS_V1',
        'analysisStatus': phaseResults.isEmpty ? 'NOT_ANALYZED' : 'ANALYZED',
        'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
        'productionDecisionChanged': false,
        'phaseResults': phaseResults,
        'comparisons': {
          'shortExposureGain1x': _safeGain(ratio(short1x), ratio(normal1x)),
          'shortExposureGain10x':
              _safeGain(ratio(short10x), ratio(normal10x)),
          'zoomGainNormal': _safeGain(ratio(normal10x), ratio(normal1x)),
          'zoomGainShort': _safeGain(ratio(short10x), ratio(short1x)),
        },
        'spatialPolicy': capture['spatialPolicy'],
        'note':
            'Raw 1x/10x and normal/short-exposure physical metrics only. No threshold or fusion rule is applied in shadow mode.',
      };
    } catch (error) {
      return _analysisUnavailable(
        'SHADOW_ANALYSIS_FAILED',
        error: error,
      );
    } finally {
      try {
        if (await workDir.exists()) {
          await workDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<bool> discardCapture(Map<String, dynamic>? capture) async {
    final path = capture?['path']?.toString();
    if (path == null || path.isEmpty) return true;
    return _deletePath(path);
  }

  Future<List<img.Image>> _extractPhaseFrames(
    String videoPath,
    Directory phaseDir, {
    required int startMs,
    required int endMs,
  }) async {
    final startSeconds = startMs / 1000.0;
    final durationSeconds = max(0.10, (endMs - startMs) / 1000.0);
    final pattern = p.join(phaseDir.path, 'frame_%03d.png');
    final command = "-y -ss ${startSeconds.toStringAsFixed(4)} -i '$videoPath' "
        "-t ${durationSeconds.toStringAsFixed(4)} -vf \"fps=15\" "
        "-frames:v 6 '$pattern'";
    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();
    if (code == null || !ReturnCode.isSuccess(code)) return const [];

    final files = phaseDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final images = <img.Image>[];
    for (final file in files) {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded != null) images.add(decoded);
    }
    return images;
  }

  Map<String, dynamic> _analyzeFrames(List<img.Image> frames) {
    if (frames.length < 3) {
      return const {
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'NOT_ENOUGH_NATIVE_FRAMES',
      };
    }

    final cellMetrics = <Map<String, dynamic>>[];
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final metrics = _analyzeCell(frames, row: row, column: column);
        cellMetrics.add({
          'row': row,
          'column': column,
          ...metrics,
        });
      }
    }

    final valid = cellMetrics
        .where((cell) => cell['structuredTemporalAxisRatio'] is num)
        .toList();
    final structured = valid
        .map((cell) =>
            (cell['structuredTemporalAxisRatio'] as num).toDouble())
        .toList()
      ..sort();
    final fineChroma = valid
        .map((cell) => (cell['fineChromaLumaRatio'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final lattice = valid
        .map((cell) => (cell['flatFieldLatticeScore'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    return {
      'analysisStatus': structured.length == 9 ? 'ANALYZED' : 'PARTIAL',
      'framesAnalyzed': frames.length,
      'gridRows': 3,
      'gridColumns': 3,
      'cellsAnalyzed': structured.length,
      'requiredDisplayCoverageCells': 9,
      'allowedRealityEscapeCells': 0,
      'coverageDecisionEnabled': false,
      'structuredTemporalAxisRatio': _mean(structured),
      'minimumCellStructuredTemporalAxisRatio':
          structured.isEmpty ? null : structured.first,
      'medianCellStructuredTemporalAxisRatio': _median(structured),
      'maximumCellStructuredTemporalAxisRatio':
          structured.isEmpty ? null : structured.last,
      'fineChromaLumaRatio': _mean(fineChroma),
      'flatFieldLatticeScore': _mean(lattice),
      'cells': cellMetrics,
    };
  }

  Map<String, dynamic> _analyzeCell(
    List<img.Image> frames, {
    required int row,
    required int column,
  }) {
    final axisRatios = <double>[];
    final rowCoherence = <double>[];
    final columnCoherence = <double>[];

    for (var index = 1; index < frames.length; index++) {
      final pair = _temporalPairMetrics(
        frames[index - 1],
        frames[index],
        row: row,
        column: column,
      );
      axisRatios.add(pair.axisRatio);
      rowCoherence.add(pair.rowCoherence);
      columnCoherence.add(pair.columnCoherence);
    }

    final spatial = _spatialMicrotexture(frames.last, row: row, column: column);
    return {
      'structuredTemporalAxisRatio': _mean(axisRatios),
      'rowTemporalCoherence': _mean(rowCoherence),
      'columnTemporalCoherence': _mean(columnCoherence),
      'fineChromaLumaRatio': spatial.fineChromaLumaRatio,
      'chromaAnisotropy': spatial.chromaAnisotropy,
      'flatFieldLatticeScore': spatial.latticeScore,
      'highFrequencyLumaEnergy': spatial.highFrequencyLumaEnergy,
    };
  }

  _TemporalPairMetrics _temporalPairMetrics(
    img.Image previous,
    img.Image current, {
    required int row,
    required int column,
  }) {
    final width = min(previous.width, current.width);
    final height = min(previous.height, current.height);
    final x0 = (width * column / 3).floor();
    final x1 = (width * (column + 1) / 3).floor();
    final y0 = (height * row / 3).floor();
    final y1 = (height * (row + 1) / 3).floor();
    const step = 4;

    var globalSum = 0.0;
    var sampleCount = 0;
    for (var y = y0; y < y1; y += step) {
      for (var x = x0; x < x1; x += step) {
        globalSum += _luma(current.getPixel(x, y)) -
            _luma(previous.getPixel(x, y));
        sampleCount++;
      }
    }
    if (sampleCount == 0) return const _TemporalPairMetrics.zero();
    final globalDelta = globalSum / sampleCount;

    final rows = <double>[];
    final columns = <double>[];
    var residualEnergy = 0.0;
    var residualCount = 0;

    for (var y = y0; y < y1; y += step) {
      var sum = 0.0;
      var count = 0;
      for (var x = x0; x < x1; x += step) {
        final residual = _luma(current.getPixel(x, y)) -
            _luma(previous.getPixel(x, y)) -
            globalDelta;
        sum += residual;
        residualEnergy += residual * residual;
        residualCount++;
        count++;
      }
      if (count > 0) rows.add(sum / count);
    }

    for (var x = x0; x < x1; x += step) {
      var sum = 0.0;
      var count = 0;
      for (var y = y0; y < y1; y += step) {
        final residual = _luma(current.getPixel(x, y)) -
            _luma(previous.getPixel(x, y)) -
            globalDelta;
        sum += residual;
        count++;
      }
      if (count > 0) columns.add(sum / count);
    }

    final residualRms =
        sqrt(residualEnergy / max(1, residualCount)).clamp(0.0, 1.0);
    final rowRms = _rms(rows);
    final columnRms = _rms(columns);
    final axisRms = sqrt(rowRms * rowRms + columnRms * columnRms);
    final denominator = max(1e-6, residualRms);

    return _TemporalPairMetrics(
      axisRatio: axisRms / denominator,
      rowCoherence: rowRms / denominator,
      columnCoherence: columnRms / denominator,
    );
  }

  _SpatialMicrotexture _spatialMicrotexture(
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
    var chromaHorizontal = 0.0;
    var chromaVertical = 0.0;
    var samples = 0;
    final chromaSeries = <double>[];

    for (var y = y0; y < y1 - step; y += step) {
      for (var x = x0; x < x1 - step; x += step) {
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + step, y);
        final down = image.getPixel(x, y + step);
        final l = _luma(center);
        final lr = _luma(right);
        final ld = _luma(down);
        final c = _chroma(center);
        final cr = _chroma(right);
        final cd = _chroma(down);

        lumaEnergy += (l - lr).abs() + (l - ld).abs();
        chromaHorizontal += (c - cr).abs();
        chromaVertical += (c - cd).abs();
        chromaSeries.add(c);
        samples++;
      }
    }

    if (samples == 0) return const _SpatialMicrotexture.zero();
    final normalizedLuma = lumaEnergy / (2 * samples);
    final normalizedChroma =
        (chromaHorizontal + chromaVertical) / (2 * samples);
    final anisotropy = max(chromaHorizontal, chromaVertical) /
        max(1e-6, min(chromaHorizontal, chromaVertical));

    return _SpatialMicrotexture(
      highFrequencyLumaEnergy: normalizedLuma,
      fineChromaLumaRatio: normalizedChroma / max(1e-6, normalizedLuma),
      chromaAnisotropy: anisotropy,
      latticeScore: _shortLagAutocorrelation(chromaSeries),
    );
  }

  double _shortLagAutocorrelation(List<double> values) {
    if (values.length < 32) return 0.0;
    final mean = _mean(values) ?? 0.0;
    var variance = 0.0;
    for (final value in values) {
      final centered = value - mean;
      variance += centered * centered;
    }
    if (variance <= 1e-9) return 0.0;

    var best = 0.0;
    for (var lag = 1; lag <= 8; lag++) {
      var covariance = 0.0;
      for (var i = lag; i < values.length; i++) {
        covariance += (values[i] - mean) * (values[i - lag] - mean);
      }
      final correlation = covariance / variance;
      if (correlation > best) best = correlation;
    }
    return best.clamp(0.0, 1.0);
  }

  double _luma(img.Pixel pixel) {
    return (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b) / 255.0;
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
    for (final value in values) {
      total += value * value;
    }
    return sqrt(total / values.length);
  }

  double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _median(List<double> sortedValues) {
    if (sortedValues.isEmpty) return null;
    final middle = sortedValues.length ~/ 2;
    if (sortedValues.length.isOdd) return sortedValues[middle];
    return (sortedValues[middle - 1] + sortedValues[middle]) / 2.0;
  }

  double? _safeGain(double? numerator, double? denominator) {
    if (numerator == null || denominator == null || denominator.abs() < 1e-9) {
      return null;
    }
    return numerator / denominator;
  }

  Future<Map<String, dynamic>?> _invokeMap(
    String method,
    Map<String, dynamic> arguments,
  ) async {
    final value = await _cameraProbeChannel.invokeMapMethod<String, dynamic>(
      method,
      arguments,
    );
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  Future<void> _restoreCameraState(
    CameraController controller, {
    required String deviceUniqueId,
    required Map<String, dynamic> originalState,
    required double originalZoom,
    required double minZoom,
    required double maxZoom,
  }) async {
    try {
      await _cameraProbeChannel.invokeMethod<void>(
        'restoreCameraState',
        {
          'deviceUniqueId': deviceUniqueId,
          'state': originalState,
        },
      );
    } catch (_) {}

    try {
      await controller.setZoomLevel(
        originalZoom.clamp(minZoom, maxZoom).toDouble(),
      );
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 260));
  }

  Future<bool> _deletePath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return true;
      await file.delete();
      return !await file.exists();
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _unavailable(
    String reason, {
    Object? error,
  }) {
    return {
      'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_CAPTURE_V1',
      'analysisStatus': 'NOT_CAPTURED',
      'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
      'reason': reason,
      if (error != null) 'error': error.toString(),
    };
  }

  Map<String, dynamic> _analysisUnavailable(
    String reason, {
    Object? error,
  }) {
    return {
      'type': 'SIGILLUM_DISPLAY_MICROTEXTURE_SHADOW_ANALYSIS_V1',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
      'productionDecisionChanged': false,
      'reason': reason,
      if (error != null) 'error': error.toString(),
    };
  }
}

class _TemporalPairMetrics {
  const _TemporalPairMetrics({
    required this.axisRatio,
    required this.rowCoherence,
    required this.columnCoherence,
  });

  const _TemporalPairMetrics.zero()
      : axisRatio = 0.0,
        rowCoherence = 0.0,
        columnCoherence = 0.0;

  final double axisRatio;
  final double rowCoherence;
  final double columnCoherence;
}

class _SpatialMicrotexture {
  const _SpatialMicrotexture({
    required this.highFrequencyLumaEnergy,
    required this.fineChromaLumaRatio,
    required this.chromaAnisotropy,
    required this.latticeScore,
  });

  const _SpatialMicrotexture.zero()
      : highFrequencyLumaEnergy = 0.0,
        fineChromaLumaRatio = 0.0,
        chromaAnisotropy = 0.0,
        latticeScore = 0.0;

  final double highFrequencyLumaEnergy;
  final double fineChromaLumaRatio;
  final double chromaAnisotropy;
  final double latticeScore;
}
