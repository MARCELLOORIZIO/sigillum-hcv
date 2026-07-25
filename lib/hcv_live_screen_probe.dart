import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';

import 'hcv_active_display_classifier.dart';

class HCVLiveScreenProbe {
  Future<Map<String, dynamic>> analyzePreview(
    CameraController controller, {
    Duration duration = const Duration(milliseconds: 1800),
    int maxFrames = 45,
    double? restoreZoomLevel,
    bool useOpticalProbeZoom = true,
  }) async {
    if (!controller.value.isInitialized) {
      return _unknown('CAMERA_NOT_READY');
    }
    if (controller.value.isRecordingVideo) {
      return _unknown('CAMERA_RECORDING');
    }
    if (controller.value.isStreamingImages) {
      return _unknown('STREAM_ALREADY_ACTIVE');
    }

    final baselineFrames = <_FrameStats>[];
    final torchFrames = <_FrameStats>[];
    final recoveryFrames = <_FrameStats>[];
    final phaseFrames = max(8, maxFrames ~/ 3);
    final phaseDuration = Duration(
      milliseconds: max(550, duration.inMilliseconds ~/ 3),
    );

    var exposureLocked = false;
    var focusLocked = false;
    var torchChallengeCompleted = false;
    String? challengeError;

    try {
      await controller.setFlashMode(FlashMode.off);
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 350));

      try {
        await controller.setExposureMode(ExposureMode.locked);
        exposureLocked = true;
      } catch (_) {
        exposureLocked = false;
      }
      try {
        await controller.setFocusMode(FocusMode.locked);
        focusLocked = true;
      } catch (_) {
        focusLocked = false;
      }
      await Future.delayed(const Duration(milliseconds: 180));

      await _collectFrameStats(
        controller,
        baselineFrames,
        maxFrames: phaseFrames,
        duration: phaseDuration,
        phase: 0,
      );

      try {
        await controller.setFlashMode(FlashMode.torch);
        await Future.delayed(const Duration(milliseconds: 280));
        await _collectFrameStats(
          controller,
          torchFrames,
          maxFrames: phaseFrames,
          duration: phaseDuration,
          phase: 1,
        );
        torchChallengeCompleted = torchFrames.length >= 4;
      } catch (e) {
        challengeError = 'TORCH_CHALLENGE_FAILED: $e';
      } finally {
        try {
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 280));
      await _collectFrameStats(
        controller,
        recoveryFrames,
        maxFrames: phaseFrames,
        duration: phaseDuration,
        phase: 2,
      );
    } catch (e) {
      challengeError ??= 'ACTIVE_PROBE_FAILED: $e';
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        if (restoreZoomLevel != null && controller.value.isInitialized) {
          await controller.setZoomLevel(restoreZoomLevel);
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 450));
    }

    final allFrames = <_FrameStats>[
      ...baselineFrames,
      ...torchFrames,
      ...recoveryFrames,
    ];
    if (allFrames.length < 8) {
      return _unknown(
        'NOT_ENOUGH_PREVIEW_FRAMES',
        framesAnalyzed: allFrames.length,
        error: challengeError,
      );
    }

    final passiveFrames = <_FrameStats>[
      ...baselineFrames,
      ...recoveryFrames,
    ];
    final passive = _analyzePassive(
      passiveFrames.length >= 8 ? passiveFrames : allFrames,
    );
    final baseline = _phaseAverage(baselineFrames);
    final torch = _phaseAverage(torchFrames);
    final recovery = _phaseAverage(recoveryFrames);
    final responsiveTileFraction = _responsiveTileFraction(
      baseline,
      torch,
      recovery,
    );

    final active = HCVActiveDisplayClassifier.classify(
      framesAnalyzed: allFrames.length,
      exposureLocked: exposureLocked,
      torchChallengeCompleted: torchChallengeCompleted,
      baselineMeanLuma: baseline?.meanLuma ?? 0,
      torchMeanLuma: torch?.meanLuma ?? 0,
      recoveryMeanLuma: recovery?.meanLuma ?? 0,
      responsiveTileFraction: responsiveTileFraction,
      localFlicker: passive.localFlicker,
      refreshBand: passive.refreshBand,
      fineStripe: passive.fineStripe,
      fineGrid: passive.fineGrid,
      moire: passive.moire,
    );

    final torchLift = max(
      0.0,
      (torch?.meanLuma ?? 0) -
          (((baseline?.meanLuma ?? 0) + (recovery?.meanLuma ?? 0)) / 2),
    );
    final persistentPattern = _persistentPattern(baseline, recovery);
    final activeDisplayEvidence =
        active.reasons.contains('EMISSIVE_SCENE_RESISTS_TORCH');
    final reflectedRealityEvidence =
        active.reasons.contains('REFLECTED_SCENE_RESPONDS_TO_TORCH');

    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 2,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': allFrames.length,
      'screenReplayRisk': active.risk,
      'screenReplayRiskScore': active.score,
      'displayRiskDecision': active.decision,
      'displayProbability': _round(active.displayProbability),
      'globalFlickerScore': _round(passive.globalFlicker),
      'localTemporalFlickerScore': _round(passive.localFlicker),
      'refreshBandScore': _round(passive.refreshBand),
      'fineStripeScore': _round(passive.fineStripe),
      'fineGridScore': _round(passive.fineGrid),
      'moireFrequencyScore': _round(passive.moire),
      'dynamicChallengeScore': _round(active.illuminationResponseScore),
      'persistentPatternScore': _round(persistentPattern),
      'bandTemporalScore': _round(passive.bandTemporal),
      'electronicLightScore': _round(active.electronicCueScore),
      'stableExposureScore': _round(passive.stableExposure),
      'illuminationChallenge': {
        'completed': torchChallengeCompleted,
        'exposureLocked': exposureLocked,
        'focusLocked': focusLocked,
        'baselineMeanLuma': _round(baseline?.meanLuma ?? 0),
        'torchMeanLuma': _round(torch?.meanLuma ?? 0),
        'recoveryMeanLuma': _round(recovery?.meanLuma ?? 0),
        'torchLumaLift': _round(torchLift),
        'responsiveTileFraction': _round(responsiveTileFraction),
        'illuminationResponseScore':
            _round(active.illuminationResponseScore),
        'emissiveIndependenceScore':
            _round(active.emissiveIndependenceScore),
        if (challengeError != null) 'error': challengeError,
      },
      'signals': {
        'livePreviewAnalyzed': true,
        'activeIlluminationChallenge': torchChallengeCompleted,
        'activeIlluminationDisplayEvidence': activeDisplayEvidence,
        'reflectedRealityEvidence': reflectedRealityEvidence,
        'activeChallengeIndeterminate':
            active.reasons.contains('ACTIVE_CHALLENGE_INDETERMINATE'),
        'confirmedDisplayTrace': false,
        'periodicLightTrace': passive.electronicLight > 0.58,
        'strongRefreshTrace': passive.refreshBand > 0.22,
        'displayBandTrace':
            passive.localFlicker > 0.34 && passive.refreshBand > 0.18,
        'opticalStripeTrace': passive.fineStripe > 0.30,
        'opticalCorroboratedTrace': passive.fineStripe > 0.30 &&
            (passive.refreshBand > 0.14 || passive.localFlicker > 0.34),
        'moireFrequencyTrace': passive.moire > 0.42,
        'globalDisplayPulse': passive.globalFlicker > 0.16 &&
            passive.localFlicker > 0.38,
        'pairedFlickerTrace': passive.localFlicker > 0.18 &&
            passive.refreshBand > 0.14,
        'uncorroboratedDisplayPattern':
            !activeDisplayEvidence && !reflectedRealityEvidence,
        'dynamicScreenChallengeTrace': activeDisplayEvidence,
        'globalFlicker': passive.globalFlicker > 0.16,
        'localRefreshFlicker': passive.localFlicker > 0.18,
        'horizontalRefreshBands': passive.refreshBand > 0.12,
        'movingRefreshBands': passive.bandTemporal > 0.04,
      },
      'activeReasons': active.reasons,
      'note':
          'Active illumination probe measured before capture with locked exposure. Display evidence is based on emissive independence plus electronic cues; reflected-scene response supports reality.',
    };
  }

  Future<void> _collectFrameStats(
    CameraController controller,
    List<_FrameStats> output, {
    required int maxFrames,
    required Duration duration,
    required int phase,
  }) async {
    final done = Completer<void>();
    var collected = 0;
    var processing = false;

    await controller.startImageStream((image) {
      if (processing || collected >= maxFrames) {
        if (collected >= maxFrames && !done.isCompleted) done.complete();
        return;
      }
      processing = true;
      try {
        final stats = _readFrameStats(image, phase);
        if (stats != null) {
          output.add(stats);
          collected++;
        }
        if (collected >= maxFrames && !done.isCompleted) done.complete();
      } finally {
        processing = false;
      }
    });

    try {
      await Future.any([done.future, Future.delayed(duration)]);
    } finally {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    }
  }

  _PassiveMetrics _analyzePassive(List<_FrameStats> frames) {
    final meanSeries = frames.map((f) => f.meanLuma).toList();
    final tileSeries = <List<double>>[];
    for (var tile = 0; tile < frames.first.tileMeans.length; tile++) {
      tileSeries.add(frames.map((f) => f.tileMeans[tile]).toList());
    }

    final globalFlicker = _temporalPulseScore(meanSeries);
    final localFlicker = tileSeries
        .map(_temporalPulseScore)
        .reduce(max)
        .clamp(0.0, 1.0)
        .toDouble();
    double average(double Function(_FrameStats frame) read) =>
        frames.map(read).reduce((a, b) => a + b) / frames.length;

    final refreshBand = average((frame) => frame.bandContrast);
    final fineStripe = average((frame) => frame.fineStripeScore);
    final fineGrid = average((frame) => frame.fineGridScore);
    final moire = average((frame) => frame.moireFrequencyScore);
    final bandTemporal = _bandTemporalScore(frames);
    final electronicLight = _electronicLightScore(frames);
    final stableExposure =
        1.0 - _seriesDelta(meanSeries).clamp(0.0, 1.0).toDouble();

    return _PassiveMetrics(
      globalFlicker: globalFlicker,
      localFlicker: localFlicker,
      refreshBand: refreshBand,
      fineStripe: fineStripe,
      fineGrid: fineGrid,
      moire: moire,
      bandTemporal: bandTemporal,
      electronicLight: electronicLight,
      stableExposure: stableExposure,
    );
  }

  _FrameStats? _readFrameStats(CameraImage image, int phase) {
    if (image.planes.isEmpty || image.width <= 0 || image.height <= 0) {
      return null;
    }
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final pixelStride = plane.bytesPerPixel ?? 1;
    if (bytes.isEmpty || rowStride <= 0) return null;

    const tilesX = 4;
    const tilesY = 4;
    const bands = 12;
    final tileTotals = List<double>.filled(tilesX * tilesY, 0);
    final tileCounts = List<int>.filled(tilesX * tilesY, 0);
    final bandTotals = List<double>.filled(bands, 0);
    final bandCounts = List<int>.filled(bands, 0);
    final centerRows = <double>[];
    final centerCols = <double>[];
    var total = 0.0;
    var count = 0;

    for (var y = 0; y < image.height; y += 6) {
      final row = y * rowStride;
      if (row >= bytes.length) break;
      for (var x = 0; x < image.width; x += 6) {
        final index = row + x * pixelStride;
        if (index >= bytes.length) break;
        final luma = _readLuma(bytes, index, pixelStride);
        total += luma;
        count++;
        final tx = min(tilesX - 1, (x * tilesX / image.width).floor());
        final ty = min(tilesY - 1, (y * tilesY / image.height).floor());
        final tile = ty * tilesX + tx;
        tileTotals[tile] += luma;
        tileCounts[tile]++;
        final band = min(bands - 1, (y * bands / image.height).floor());
        bandTotals[band] += luma;
        bandCounts[band]++;
      }
    }
    if (count == 0) return null;

    final left = (image.width * 0.18).floor();
    final right = (image.width * 0.82).floor();
    final top = (image.height * 0.18).floor();
    final bottom = (image.height * 0.82).floor();
    for (var y = top; y < bottom; y += 2) {
      var sum = 0.0;
      var samples = 0;
      final row = y * rowStride;
      for (var x = left; x < right; x += 2) {
        final index = row + x * pixelStride;
        if (index >= bytes.length) break;
        sum += _readLuma(bytes, index, pixelStride);
        samples++;
      }
      if (samples > 0) centerRows.add(sum / samples);
    }
    for (var x = left; x < right; x += 2) {
      var sum = 0.0;
      var samples = 0;
      for (var y = top; y < bottom; y += 2) {
        final index = y * rowStride + x * pixelStride;
        if (index >= bytes.length) break;
        sum += _readLuma(bytes, index, pixelStride);
        samples++;
      }
      if (samples > 0) centerCols.add(sum / samples);
    }

    final tileMeans = List<double>.generate(
      tileTotals.length,
      (index) => tileTotals[index] / max(1, tileCounts[index]),
    );
    final bandMeans = List<double>.generate(
      bandTotals.length,
      (index) => bandTotals[index] / max(1, bandCounts[index]),
    );

    return _FrameStats(
      phase: phase,
      meanLuma: total / count,
      tileMeans: tileMeans,
      bandMeans: bandMeans,
      bandContrast: _profileContrast(bandMeans),
      fineStripeScore: _fineStripeScore(centerRows),
      fineGridScore:
          max(_fineStripeScore(centerRows), _fineStripeScore(centerCols)),
      moireFrequencyScore: max(
        _periodicFrequencyScore(centerRows),
        _periodicFrequencyScore(centerCols),
      ),
    );
  }

  double _readLuma(List<int> bytes, int index, int pixelStride) {
    if (pixelStride >= 4 && index + 2 < bytes.length) {
      return ((0.114 * bytes[index]) +
              (0.587 * bytes[index + 1]) +
              (0.299 * bytes[index + 2])) /
          255.0;
    }
    return bytes[index] / 255.0;
  }

  _FrameStats? _phaseAverage(List<_FrameStats> frames) {
    if (frames.isEmpty) return null;
    double average(double Function(_FrameStats frame) read) =>
        frames.map(read).reduce((a, b) => a + b) / frames.length;
    final tileMeans = List<double>.generate(
      frames.first.tileMeans.length,
      (index) => frames.map((frame) => frame.tileMeans[index]).reduce((a, b) => a + b) /
          frames.length,
    );
    return _FrameStats(
      phase: frames.first.phase,
      meanLuma: average((frame) => frame.meanLuma),
      tileMeans: tileMeans,
      bandMeans: frames.first.bandMeans,
      bandContrast: average((frame) => frame.bandContrast),
      fineStripeScore: average((frame) => frame.fineStripeScore),
      fineGridScore: average((frame) => frame.fineGridScore),
      moireFrequencyScore: average((frame) => frame.moireFrequencyScore),
    );
  }

  double _responsiveTileFraction(
    _FrameStats? baseline,
    _FrameStats? torch,
    _FrameStats? recovery,
  ) {
    if (baseline == null || torch == null || recovery == null) return 0;
    final count = min(
      baseline.tileMeans.length,
      min(torch.tileMeans.length, recovery.tileMeans.length),
    );
    if (count == 0) return 0;
    var responsive = 0;
    for (var i = 0; i < count; i++) {
      final reference = (baseline.tileMeans[i] + recovery.tileMeans[i]) / 2;
      final lift = torch.tileMeans[i] - reference;
      final threshold = max(0.025, reference * 0.08);
      if (lift >= threshold) responsive++;
    }
    return responsive / count;
  }

  double _persistentPattern(_FrameStats? baseline, _FrameStats? recovery) {
    if (baseline == null || recovery == null) return 0;
    final gridPersistence =
        1.0 - (baseline.fineGridScore - recovery.fineGridScore).abs();
    final moirePersistence =
        1.0 - (baseline.moireFrequencyScore - recovery.moireFrequencyScore).abs();
    return ((gridPersistence + moirePersistence) / 2)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _bandTemporalScore(List<_FrameStats> frames) {
    if (frames.length < 2) return 0;
    var total = 0.0;
    var pairs = 0;
    for (var i = 1; i < frames.length; i++) {
      final previous = frames[i - 1].bandMeans;
      final current = frames[i].bandMeans;
      final count = min(previous.length, current.length);
      var delta = 0.0;
      for (var j = 0; j < count; j++) {
        delta += (current[j] - previous[j]).abs();
      }
      total += delta / max(1, count);
      pairs++;
    }
    return (total / max(1, pairs)).clamp(0.0, 1.0).toDouble();
  }

  double _electronicLightScore(List<_FrameStats> frames) {
    if (frames.length < 8) return 0;
    final series = frames.map((frame) => frame.meanLuma).toList();
    final pulse = _temporalPulseScore(series);
    final band = frames.map((frame) => frame.bandContrast).reduce((a, b) => a + b) /
        frames.length;
    return (pulse * 0.55 + band * 1.8 * 0.45)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _temporalPulseScore(List<double> series) {
    if (series.length < 6) return 0;
    final mean = series.reduce((a, b) => a + b) / series.length;
    var energy = 0.0;
    var delta = 0.0;
    var crossings = 0;
    var previous = series.first - mean;
    for (var i = 0; i < series.length; i++) {
      final centered = series[i] - mean;
      energy += centered.abs();
      if (i > 0) {
        delta += (series[i] - series[i - 1]).abs();
        if (centered.sign != previous.sign) crossings++;
      }
      previous = centered;
    }
    return ((energy / series.length) * 3.0 +
            (delta / max(1, series.length - 1)) * 2.5 +
            (crossings / max(1, series.length - 1)) * 0.35)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _seriesDelta(List<double> series) {
    if (series.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < series.length; i++) {
      total += (series[i] - series[i - 1]).abs();
    }
    return total / (series.length - 1);
  }

  double _profileContrast(List<double> profile) {
    if (profile.isEmpty) return 0;
    final mean = profile.reduce((a, b) => a + b) / profile.length;
    final variance = profile
            .map((value) => pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        profile.length;
    return sqrt(variance).clamp(0.0, 1.0).toDouble();
  }

  double _fineStripeScore(List<double> profile) {
    if (profile.length < 12) return 0;
    final mean = profile.reduce((a, b) => a + b) / profile.length;
    final centered = profile.map((value) => value - mean).toList();
    var gradients = 0.0;
    var signChanges = 0;
    for (var i = 1; i < centered.length; i++) {
      gradients += (centered[i] - centered[i - 1]).abs();
      if (centered[i].sign != centered[i - 1].sign) signChanges++;
    }
    return ((gradients / (centered.length - 1)) * 2.8 +
            (signChanges / (centered.length - 1)) * 0.22)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _periodicFrequencyScore(List<double> profile) {
    if (profile.length < 24) return 0;
    final mean = profile.reduce((a, b) => a + b) / profile.length;
    final centered = profile.map((value) => value - mean).toList();
    final totalEnergy = centered.map((value) => value * value).reduce((a, b) => a + b);
    if (totalEnergy < 0.00008) return 0;
    var strongest = 0.0;
    final upperBin = min(profile.length ~/ 2, 18);
    for (var bin = 3; bin <= upperBin; bin++) {
      var real = 0.0;
      var imaginary = 0.0;
      for (var i = 0; i < centered.length; i++) {
        final angle = 2 * pi * bin * i / centered.length;
        real += centered[i] * cos(angle);
        imaginary += centered[i] * sin(angle);
      }
      strongest = max(strongest, (real * real + imaginary * imaginary) / centered.length);
    }
    final dominance = strongest / totalEnergy;
    final contrast = sqrt(totalEnergy / centered.length);
    return (dominance * 1.8 + contrast * 2.4)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  Map<String, dynamic> _unknown(
    String reason, {
    int framesAnalyzed = 0,
    String? error,
  }) {
    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 2,
      'analysisStatus': 'NOT_ANALYZED',
      'framesAnalyzed': framesAnalyzed,
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'displayRiskDecision': 'NOT_ANALYZED',
      'reason': reason,
      if (error != null && error.isNotEmpty) 'error': error,
    };
  }

  double _round(double value) =>
      double.parse(value.clamp(0.0, 1.0).toStringAsFixed(4));
}

class _FrameStats {
  const _FrameStats({
    required this.phase,
    required this.meanLuma,
    required this.tileMeans,
    required this.bandMeans,
    required this.bandContrast,
    required this.fineStripeScore,
    required this.fineGridScore,
    required this.moireFrequencyScore,
  });

  final int phase;
  final double meanLuma;
  final List<double> tileMeans;
  final List<double> bandMeans;
  final double bandContrast;
  final double fineStripeScore;
  final double fineGridScore;
  final double moireFrequencyScore;
}

class _PassiveMetrics {
  const _PassiveMetrics({
    required this.globalFlicker,
    required this.localFlicker,
    required this.refreshBand,
    required this.fineStripe,
    required this.fineGrid,
    required this.moire,
    required this.bandTemporal,
    required this.electronicLight,
    required this.stableExposure,
  });

  final double globalFlicker;
  final double localFlicker;
  final double refreshBand;
  final double fineStripe;
  final double fineGrid;
  final double moire;
  final double bandTemporal;
  final double electronicLight;
  final double stableExposure;
}
