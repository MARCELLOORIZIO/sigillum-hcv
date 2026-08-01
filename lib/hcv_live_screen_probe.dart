import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';

class HCVLiveScreenProbe {
  static const int _warmupFrames = 3;
  static const int _gridColumns = 12;
  static const int _gridRows = 16;

  Future<Map<String, dynamic>> analyzePreview(
    CameraController controller, {
    Duration duration = const Duration(milliseconds: 2400),
    int maxFrames = 48,
    double? restoreZoomLevel,
    bool useOpticalProbeZoom = true,
  }) async {
    if (!controller.value.isInitialized) {
      return _notAnalyzed('CAMERA_NOT_READY');
    }
    if (controller.value.isRecordingVideo) {
      return _notAnalyzed('CAMERA_RECORDING');
    }
    if (controller.value.isStreamingImages) {
      return _notAnalyzed('STREAM_ALREADY_ACTIVE');
    }

    final baseline = <_FrameSample>[];
    final probe = <_FrameSample>[];
    final minZoom = await controller.getMinZoomLevel();
    final maxZoom = await controller.getMaxZoomLevel();
    final zoomToRestore = (restoreZoomLevel ?? minZoom)
        .clamp(minZoom, maxZoom)
        .toDouble();
    var zoomApplied = false;

    try {
      final perPhase = max(12, maxFrames ~/ (useOpticalProbeZoom ? 2 : 1));
      final perPhaseDuration = Duration(
        milliseconds: max(
          850,
          duration.inMilliseconds ~/ (useOpticalProbeZoom ? 2 : 1),
        ),
      );

      await _collectPhase(
        controller,
        output: baseline,
        phase: 0,
        targetFrames: perPhase,
        duration: perPhaseDuration,
      );

      if (useOpticalProbeZoom) {
        final probeZoom = min(maxZoom, max(minZoom, zoomToRestore + 0.55));
        if (probeZoom > zoomToRestore + 0.1) {
          await controller.setZoomLevel(probeZoom);
          zoomApplied = true;
          await Future.delayed(const Duration(milliseconds: 400));
        }
        await _collectPhase(
          controller,
          output: probe,
          phase: 1,
          targetFrames: perPhase,
          duration: perPhaseDuration,
        );
      }
    } catch (error) {
      return _notAnalyzed(
        'LIVE_PROBE_FAILED',
        frames: baseline.length + probe.length,
        error: error.toString(),
      );
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        if (controller.value.isInitialized) {
          await controller.setZoomLevel(zoomToRestore);
          await Future.delayed(const Duration(milliseconds: 550));
        }
      } catch (_) {}
    }

    if (baseline.length < 10 || (useOpticalProbeZoom && probe.length < 10)) {
      return _notAnalyzed(
        'NOT_ENOUGH_PREVIEW_FRAMES',
        frames: baseline.length + probe.length,
        extra: {
          'baselineFrames': baseline.length,
          'probeFrames': probe.length,
        },
      );
    }

    return _analyze(
      baseline: baseline,
      probe: probe,
      zoomApplied: zoomApplied,
    );
  }

  Future<void> _collectPhase(
    CameraController controller, {
    required List<_FrameSample> output,
    required int phase,
    required int targetFrames,
    required Duration duration,
  }) async {
    final completed = Completer<void>();
    final watch = Stopwatch()..start();
    var seen = 0;

    await controller.startImageStream((image) {
      if (completed.isCompleted) return;
      seen++;
      if (seen <= _warmupFrames) return;
      final sample = _sampleFrame(image, phase, watch.elapsedMicroseconds);
      if (sample != null) output.add(sample);
      if (output.length >= targetFrames && !completed.isCompleted) {
        completed.complete();
      }
    });

    try {
      await Future.any([completed.future, Future.delayed(duration)]);
    } finally {
      watch.stop();
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    }
  }

  Map<String, dynamic> _analyze({
    required List<_FrameSample> baseline,
    required List<_FrameSample> probe,
    required bool zoomApplied,
  }) {
    final baselineMetrics = _phaseMetrics(baseline);
    final probeMetrics = probe.isEmpty
        ? baselineMetrics
        : _phaseMetrics(probe);
    final minimumFrames = min(
      baseline.length,
      probe.isEmpty ? baseline.length : probe.length,
    );
    final minimumFps = min(baselineMetrics.fps, probeMetrics.fps);
    final meanLuma = (baselineMetrics.meanLuma + probeMetrics.meanLuma) / 2;
    final saturationPenalty = meanLuma < 0.04 || meanLuma > 0.96
        ? 1.0
        : meanLuma < 0.08 || meanLuma > 0.92
            ? 0.5
            : 0.0;
    final quality = ((minimumFrames / 16).clamp(0.0, 1.0) * 0.38 +
            (minimumFps / 10).clamp(0.0, 1.0) * 0.32 +
            min(
                  baselineMetrics.exposureStability,
                  probeMetrics.exposureStability,
                ) *
                0.20 +
            (1 - saturationPenalty) * 0.10)
        .clamp(0.0, 1.0)
        .toDouble();

    if (quality < 0.52) {
      return _notAnalyzed(
        'INSUFFICIENT_ANALYSIS_QUALITY',
        frames: baseline.length + probe.length,
        extra: {
          'analysisQuality': _round(quality),
          'baselineFrames': baseline.length,
          'probeFrames': probe.length,
          'baselineFps': _round(baselineMetrics.fps),
          'probeFps': _round(probeMetrics.fps),
          'baselineMetrics': baselineMetrics.toJson(),
          'probeMetrics': probeMetrics.toJson(),
        },
      );
    }

    final localFlicker = max(
      baselineMetrics.localFlicker,
      probeMetrics.localFlicker,
    );
    final globalFlicker = max(
      baselineMetrics.globalFlicker,
      probeMetrics.globalFlicker,
    );
    final refreshBand = max(
      baselineMetrics.refreshBand,
      probeMetrics.refreshBand,
    );
    final bandTemporal = max(
      baselineMetrics.bandTemporal,
      probeMetrics.bandTemporal,
    );
    final stripe = max(baselineMetrics.stripe, probeMetrics.stripe);
    final grid = max(baselineMetrics.grid, probeMetrics.grid);
    final moire = max(baselineMetrics.moire, probeMetrics.moire);
    final persistence = probe.isEmpty
        ? 0.0
        : _profileSimilarity(
            baselineMetrics.medianRowProfile,
            probeMetrics.medianRowProfile,
          );

    final temporalEvidence =
        (localFlicker >= 0.24 && refreshBand >= 0.075) ||
        (localFlicker >= 0.31 && bandTemporal >= 0.035);
    final structuralEvidence = grid >= 0.36 || moire >= 0.28;
    final stripeEvidence = stripe >= 0.20;
    final persistentEvidence = persistence >= 0.58;
    final moderate = temporalEvidence &&
        stripeEvidence &&
        (structuralEvidence || persistentEvidence);
    final strong = quality >= 0.72 &&
        localFlicker >= 0.34 &&
        refreshBand >= 0.12 &&
        stripeEvidence &&
        structuralEvidence &&
        persistentEvidence;

    var score = 0;
    if (temporalEvidence) score += 28;
    if (stripeEvidence) score += 16;
    if (structuralEvidence) score += 18;
    if (persistentEvidence) score += 13;
    if (localFlicker >= 0.42) score += 10;
    if (refreshBand >= 0.18) score += 10;
    score = score.clamp(0, 100).toInt();
    if (strong) score = max(score, 70);
    if (!strong && moderate) score = max(score, 45);
    if (!moderate) score = min(score, 30);

    final decision = strong
        ? 'STRONG_DISPLAY_RISK'
        : moderate
            ? 'NON_CONCLUSIVE'
            : 'NO_DISPLAY_EVIDENCE';

    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V2',
      'analysisStatus': 'ANALYZED',
      'analysisQuality': _round(quality),
      'analysisQualityStatus': quality >= 0.72 ? 'GOOD' : 'DEGRADED',
      'framesAnalyzed': baseline.length + probe.length,
      'baselineFrames': baseline.length,
      'probeFrames': probe.length,
      'baselineFps': _round(baselineMetrics.fps),
      'probeFps': _round(probeMetrics.fps),
      'zoomApplied': zoomApplied,
      'screenReplayRisk': score >= 70
          ? 'HIGH'
          : score >= 45
              ? 'MEDIUM'
              : 'LOW',
      'screenReplayRiskScore': score,
      'displayRiskDecision': decision,
      'globalFlickerScore': _round(globalFlicker),
      'localTemporalFlickerScore': _round(localFlicker),
      'refreshBandScore': _round(refreshBand),
      'fineStripeScore': _round(stripe),
      'fineGridScore': _round(grid),
      'moireFrequencyScore': _round(moire),
      'persistentPatternScore': _round(persistence),
      'bandTemporalScore': _round(bandTemporal),
      'stableExposureScore': _round(min(
        baselineMetrics.exposureStability,
        probeMetrics.exposureStability,
      )),
      'baselineMetrics': baselineMetrics.toJson(),
      'probeMetrics': probeMetrics.toJson(),
      'signals': {
        'livePreviewAnalyzed': true,
        'temporalEvidence': temporalEvidence,
        'stripeEvidence': stripeEvidence,
        'spatialEvidence': structuralEvidence,
        'crossPhasePersistence': persistentEvidence,
        'corroboratedModerateTrace': moderate,
        'confirmedDisplayTrace': strong,
        'strongRefreshTrace': refreshBand >= 0.18,
        'opticalCorroboratedTrace': moderate,
        'moireFrequencyTrace': moire >= 0.34 && temporalEvidence,
        'dynamicScreenChallengeTrace': persistentEvidence,
        'uncorroboratedDisplayPattern': structuralEvidence && !temporalEvidence,
      },
      'note':
          'Baseline and zoom-probe phases are analyzed separately. Insufficient acquisition quality returns NOT_ANALYZED, not absence of display evidence.',
    };
  }

  _PhaseMetrics _phaseMetrics(List<_FrameSample> samples) {
    final cellSeries = List.generate(
      _gridColumns * _gridRows,
      (index) => samples.map((sample) => sample.cells[index]).toList(),
    );
    final localFlicker = cellSeries
        .map(_temporalVariation)
        .reduce(max)
        .clamp(0.0, 1.0)
        .toDouble();
    final globalSeries = samples.map((sample) => sample.meanLuma).toList();
    final rowProfiles = samples.map((sample) => sample.rowProfile).toList();
    final medianRows = List<double>.generate(
      _gridRows,
      (row) => _median(rowProfiles.map((profile) => profile[row]).toList()),
    );
    return _PhaseMetrics(
      meanLuma: _median(globalSeries),
      fps: _fps(samples),
      globalFlicker: _temporalVariation(globalSeries),
      localFlicker: localFlicker,
      refreshBand: _percentile(
        samples.map((sample) => sample.rowContrast).toList(),
        0.75,
      ),
      bandTemporal: _rowTemporalVariation(rowProfiles),
      stripe: _percentile(
        samples.map((sample) => sample.stripeScore).toList(),
        0.75,
      ),
      grid: _percentile(
        samples.map((sample) => sample.gridScore).toList(),
        0.75,
      ),
      moire: _percentile(
        samples.map((sample) => sample.moireScore).toList(),
        0.75,
      ),
      exposureStability: (1 - _meanAbsoluteDelta(globalSeries) * 6)
          .clamp(0.0, 1.0)
          .toDouble(),
      medianRowProfile: medianRows,
    );
  }

  _FrameSample? _sampleFrame(CameraImage image, int phase, int micros) {
    if (image.planes.isEmpty || image.width <= 0 || image.height <= 0) {
      return null;
    }
    final plane = image.planes.first;
    final bytes = plane.bytes;
    if (bytes.isEmpty || plane.bytesPerRow <= 0) return null;
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    final pixelStride = plane.bytesPerPixel ?? 1;
    final cells = <double>[];
    final rows = List<double>.filled(_gridRows, 0);

    for (var gy = 0; gy < _gridRows; gy++) {
      final y = (((gy + 0.5) * image.height) / _gridRows)
          .floor()
          .clamp(0, image.height - 1)
          .toInt();
      var rowTotal = 0.0;
      for (var gx = 0; gx < _gridColumns; gx++) {
        final x = (((gx + 0.5) * image.width) / _gridColumns)
            .floor()
            .clamp(0, image.width - 1)
            .toInt();
        final index = y * plane.bytesPerRow + x * pixelStride;
        if (index >= bytes.length) return null;
        final value = _luma(bytes, index, isBgra);
        cells.add(value);
        rowTotal += value;
      }
      rows[gy] = rowTotal / _gridColumns;
    }

    final mean = cells.reduce((a, b) => a + b) / cells.length;
    final rowContrast = _standardDeviation(rows);
    var horizontalGradient = 0.0;
    var verticalGradient = 0.0;
    var secondDifference = 0.0;
    var horizontalCount = 0;
    var verticalCount = 0;

    for (var y = 0; y < _gridRows; y++) {
      for (var x = 0; x < _gridColumns; x++) {
        final index = y * _gridColumns + x;
        if (x > 0) {
          horizontalGradient += (cells[index] - cells[index - 1]).abs();
          horizontalCount++;
        }
        if (y > 0) {
          verticalGradient +=
              (cells[index] - cells[index - _gridColumns]).abs();
          verticalCount++;
        }
        if (y > 1) {
          secondDifference +=
              (cells[index] -
                      2 * cells[index - _gridColumns] +
                      cells[index - 2 * _gridColumns])
                  .abs();
        }
      }
    }

    final horizontal = horizontalGradient / max(horizontalCount, 1);
    final vertical = verticalGradient / max(verticalCount, 1);
    final stripe = (rowContrast * 2.8 + vertical * 1.8)
        .clamp(0.0, 1.0)
        .toDouble();
    final grid = ((horizontal + vertical) * 2.4)
        .clamp(0.0, 1.0)
        .toDouble();
    final moire = (secondDifference /
            max((_gridRows - 2) * _gridColumns, 1) *
            4.0)
        .clamp(0.0, 1.0)
        .toDouble();

    return _FrameSample(
      phase: phase,
      capturedMicros: micros,
      meanLuma: mean,
      cells: cells,
      rowProfile: rows,
      rowContrast: rowContrast,
      stripeScore: stripe,
      gridScore: grid,
      moireScore: moire,
    );
  }

  double _luma(List<int> bytes, int index, bool isBgra) {
    if (isBgra && index + 2 < bytes.length) {
      return ((0.114 * bytes[index]) +
              (0.587 * bytes[index + 1]) +
              (0.299 * bytes[index + 2])) /
          255.0;
    }
    return bytes[index] / 255.0;
  }

  double _fps(List<_FrameSample> samples) {
    if (samples.length < 2) return 0;
    final elapsed = samples.last.capturedMicros - samples.first.capturedMicros;
    if (elapsed <= 0) return 0;
    return (samples.length - 1) * 1000000 / elapsed;
  }

  double _temporalVariation(List<double> values) {
    if (values.length < 4) return 0;
    final median = _median(values);
    final mad = _median(
      values.map((value) => (value - median).abs()).toList(),
    );
    final delta = _meanAbsoluteDelta(values);
    return (mad * 8 + delta * 5).clamp(0.0, 1.0).toDouble();
  }

  double _rowTemporalVariation(List<List<double>> profiles) {
    if (profiles.length < 2) return 0;
    var total = 0.0;
    var count = 0;
    for (var frame = 1; frame < profiles.length; frame++) {
      for (var row = 0; row < _gridRows; row++) {
        total += (profiles[frame][row] - profiles[frame - 1][row]).abs();
        count++;
      }
    }
    return (total / max(count, 1) * 5).clamp(0.0, 1.0).toDouble();
  }

  double _profileSimilarity(List<double> first, List<double> second) {
    if (first.length != second.length || first.isEmpty) return 0;
    final firstMean = first.reduce((a, b) => a + b) / first.length;
    final secondMean = second.reduce((a, b) => a + b) / second.length;
    var numerator = 0.0;
    var firstEnergy = 0.0;
    var secondEnergy = 0.0;
    for (var index = 0; index < first.length; index++) {
      final a = first[index] - firstMean;
      final b = second[index] - secondMean;
      numerator += a * b;
      firstEnergy += a * a;
      secondEnergy += b * b;
    }
    if (firstEnergy <= 0 || secondEnergy <= 0) return 0;
    return ((numerator / sqrt(firstEnergy * secondEnergy)) + 1) / 2;
  }

  double _meanAbsoluteDelta(List<double> values) {
    if (values.length < 2) return 0;
    var total = 0.0;
    for (var index = 1; index < values.length; index++) {
      total += (values[index] - values[index - 1]).abs();
    }
    return total / (values.length - 1);
  }

  double _standardDeviation(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }

  double _median(List<double> values) => _percentile(values, 0.5);

  double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final position =
        (sorted.length - 1) * percentile.clamp(0.0, 1.0).toDouble();
    final low = position.floor();
    final high = position.ceil();
    if (low == high) return sorted[low];
    final weight = position - low;
    return (sorted[low] * (1 - weight) + sorted[high] * weight)
        .toDouble();
  }

  Map<String, dynamic> _notAnalyzed(
    String reason, {
    int frames = 0,
    String? error,
    Map<String, dynamic>? extra,
  }) {
    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V2',
      'analysisStatus': 'NOT_ANALYZED',
      'analysisQualityStatus': 'INSUFFICIENT',
      'displayRiskDecision': 'NOT_ANALYZED',
      'framesAnalyzed': frames,
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'reason': reason,
      if (error != null && error.isNotEmpty) 'error': error,
      if (extra != null) ...extra,
    };
  }

  double _round(double value) => double.parse(value.toStringAsFixed(4));
}

class _FrameSample {
  const _FrameSample({
    required this.phase,
    required this.capturedMicros,
    required this.meanLuma,
    required this.cells,
    required this.rowProfile,
    required this.rowContrast,
    required this.stripeScore,
    required this.gridScore,
    required this.moireScore,
  });

  final int phase;
  final int capturedMicros;
  final double meanLuma;
  final List<double> cells;
  final List<double> rowProfile;
  final double rowContrast;
  final double stripeScore;
  final double gridScore;
  final double moireScore;
}

class _PhaseMetrics {
  const _PhaseMetrics({
    required this.meanLuma,
    required this.fps,
    required this.globalFlicker,
    required this.localFlicker,
    required this.refreshBand,
    required this.bandTemporal,
    required this.stripe,
    required this.grid,
    required this.moire,
    required this.exposureStability,
    required this.medianRowProfile,
  });

  final double meanLuma;
  final double fps;
  final double globalFlicker;
  final double localFlicker;
  final double refreshBand;
  final double bandTemporal;
  final double stripe;
  final double grid;
  final double moire;
  final double exposureStability;
  final List<double> medianRowProfile;

  Map<String, dynamic> toJson() => {
        'meanLuma': _rounded(meanLuma),
        'fps': _rounded(fps),
        'globalFlickerScore': _rounded(globalFlicker),
        'localTemporalFlickerScore': _rounded(localFlicker),
        'refreshBandScore': _rounded(refreshBand),
        'bandTemporalScore': _rounded(bandTemporal),
        'fineStripeScore': _rounded(stripe),
        'fineGridScore': _rounded(grid),
        'moireFrequencyScore': _rounded(moire),
        'stableExposureScore': _rounded(exposureStability),
      };

  static double _rounded(double value) =>
      double.parse(value.toStringAsFixed(4));
}
