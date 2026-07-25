import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';

import 'hcv_active_display_classifier.dart';

class HCVLiveScreenProbe {
  Future<Map<String, dynamic>> analyzePreview(
    CameraController controller, {
    Duration duration = const Duration(milliseconds: 3000),
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
    final phaseTimeout = Duration(
      milliseconds: max(750, duration.inMilliseconds ~/ 3),
    );

    var exposureLocked = false;
    var focusLocked = false;
    var torchChallengeCompleted = false;
    String? challengeError;
    var processing = false;
    var activePhase = 0;
    var discardUntil = DateTime.fromMillisecondsSinceEpoch(0);

    List<_FrameStats> targetForPhase() {
      switch (activePhase) {
        case 1:
          return torchFrames;
        case 2:
          return recoveryFrames;
        default:
          return baselineFrames;
      }
    }

    Future<void> waitForPhase(List<_FrameStats> target) async {
      final deadline = DateTime.now().add(phaseTimeout);
      while (target.length < phaseFrames && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    try {
      await controller.setFlashMode(FlashMode.off);
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 450));

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
      await Future.delayed(const Duration(milliseconds: 220));

      await controller.startImageStream((image) {
        if (processing || DateTime.now().isBefore(discardUntil)) return;
        final target = targetForPhase();
        if (target.length >= phaseFrames) return;

        processing = true;
        try {
          final stats = _readFrameStats(image, activePhase);
          if (stats != null && target.length < phaseFrames) {
            target.add(stats);
          }
        } finally {
          processing = false;
        }
      });

      activePhase = 0;
      discardUntil = DateTime.now().add(const Duration(milliseconds: 120));
      await waitForPhase(baselineFrames);

      await controller.setFlashMode(FlashMode.torch);
      activePhase = 1;
      discardUntil = DateTime.now().add(const Duration(milliseconds: 320));
      await Future.delayed(const Duration(milliseconds: 320));
      await waitForPhase(torchFrames);
      torchChallengeCompleted = torchFrames.length >= 6;

      await controller.setFlashMode(FlashMode.off);
      activePhase = 2;
      discardUntil = DateTime.now().add(const Duration(milliseconds: 320));
      await Future.delayed(const Duration(milliseconds: 320));
      await waitForPhase(recoveryFrames);
    } catch (e) {
      challengeError = 'ACTIVE_PROBE_FAILED: $e';
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
      await Future.delayed(const Duration(milliseconds: 500));
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
    final baseline = _phaseRepresentative(baselineFrames);
    final torch = _phaseRepresentative(torchFrames);
    final recovery = _phaseRepresentative(recoveryFrames);
    final flash = _flashResponseProfile(baseline, torch, recovery);

    final active = HCVActiveDisplayClassifier.classify(
      framesAnalyzed: allFrames.length,
      exposureLocked: exposureLocked,
      torchChallengeCompleted: torchChallengeCompleted,
      baselineMeanLuma: baseline?.meanLuma ?? 0,
      torchMeanLuma: torch?.meanLuma ?? 0,
      recoveryMeanLuma: recovery?.meanLuma ?? 0,
      responsiveTileFraction: flash.responsiveTileFraction,
      flashLiftRatio: flash.globalLiftRatio,
      flashResponseEntropy: flash.responseEntropy,
      flashHotspotConcentration: flash.hotspotConcentration,
      localFlicker: passive.localFlicker,
      refreshBand: passive.refreshBand,
      fineStripe: passive.fineStripe,
      fineGrid: passive.fineGrid,
      moire: passive.moire,
    );

    final persistentPattern = _persistentPattern(baseline, recovery);
    final activeDisplayEvidence =
        active.reasons.contains('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH');
    final reflectedRealityEvidence =
        active.reasons.contains('DIFFUSE_REFLECTED_SCENE_RESPONSE');
    final indeterminate =
        active.reasons.contains('ACTIVE_CHALLENGE_INDETERMINATE') ||
            active.reasons.contains('ACTIVE_ILLUMINATION_CHALLENGE_NOT_VALID') ||
            active.reasons.contains('FLASH_AND_ELECTRONIC_EVIDENCE_CONFLICT');

    final compactReason = <String>[
      'ACTIVE_V3',
      ...active.reasons,
      'LOCK=${exposureLocked ? 1 : 0}',
      'LIFT=${_round(flash.globalLiftRatio)}',
      'COV=${_round(flash.responsiveTileFraction)}',
      'ENT=${_round(flash.responseEntropy)}',
      'HOT=${_round(flash.hotspotConcentration)}',
      if (challengeError != null) challengeError!,
    ].join('|');

    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 3,
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
      'reason': compactReason,
      'illuminationChallenge': {
        'completed': torchChallengeCompleted,
        'continuousStream': true,
        'exposureLocked': exposureLocked,
        'focusLocked': focusLocked,
        'baselineFrames': baselineFrames.length,
        'torchFrames': torchFrames.length,
        'recoveryFrames': recoveryFrames.length,
        'baselineMeanLuma': _round(baseline?.meanLuma ?? 0),
        'torchMeanLuma': _round(torch?.meanLuma ?? 0),
        'recoveryMeanLuma': _round(recovery?.meanLuma ?? 0),
        'globalLiftRatio': _round(flash.globalLiftRatio),
        'responsiveTileFraction': _round(flash.responsiveTileFraction),
        'responseEntropy': _round(flash.responseEntropy),
        'hotspotConcentration': _round(flash.hotspotConcentration),
        'illuminationResponseScore':
            _round(active.illuminationResponseScore),
        'emissiveIndependenceScore':
            _round(active.emissiveIndependenceScore),
        if (challengeError != null) 'error': challengeError,
      },
      'signals': {
        'livePreviewAnalyzed': true,
        'activeIlluminationChallenge': torchChallengeCompleted,
        'activeIlluminationContinuousStream': true,
        'activeIlluminationDisplayEvidence': activeDisplayEvidence,
        'reflectedRealityEvidence': reflectedRealityEvidence,
        'activeChallengeIndeterminate': indeterminate,
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
        'pairedFlickerTrace':
            passive.localFlicker > 0.18 && passive.refreshBand > 0.14,
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
          'Active display probe V3: one continuous image stream measures OFF/ON/OFF torch response. Diffuse scene illumination is separated from concentrated glass glare and electronic display structure.',
    };
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

    double medianMetric(double Function(_FrameStats frame) read) =>
        _median(frames.map(read).toList());

    final refreshBand = medianMetric((frame) => frame.bandContrast);
    final fineStripe = medianMetric((frame) => frame.fineStripeScore);
    final fineGrid = medianMetric((frame) => frame.fineGridScore);
    final moire = medianMetric((frame) => frame.moireFrequencyScore);
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
      if (row >= bytes.length) break;
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

  _FrameStats? _phaseRepresentative(List<_FrameStats> frames) {
    if (frames.isEmpty) return null;

    double medianMetric(double Function(_FrameStats frame) read) =>
        _median(frames.map(read).toList());

    final tileMeans = List<double>.generate(
      frames.first.tileMeans.length,
      (index) => _median(
        frames.map((frame) => frame.tileMeans[index]).toList(),
      ),
    );
    final bandMeans = List<double>.generate(
      frames.first.bandMeans.length,
      (index) => _median(
        frames.map((frame) => frame.bandMeans[index]).toList(),
      ),
    );

    return _FrameStats(
      phase: frames.first.phase,
      meanLuma: medianMetric((frame) => frame.meanLuma),
      tileMeans: tileMeans,
      bandMeans: bandMeans,
      bandContrast: medianMetric((frame) => frame.bandContrast),
      fineStripeScore: medianMetric((frame) => frame.fineStripeScore),
      fineGridScore: medianMetric((frame) => frame.fineGridScore),
      moireFrequencyScore:
          medianMetric((frame) => frame.moireFrequencyScore),
    );
  }

  _FlashResponseProfile _flashResponseProfile(
    _FrameStats? baseline,
    _FrameStats? torch,
    _FrameStats? recovery,
  ) {
    if (baseline == null || torch == null || recovery == null) {
      return const _FlashResponseProfile.empty();
    }

    final count = min(
      baseline.tileMeans.length,
      min(torch.tileMeans.length, recovery.tileMeans.length),
    );
    if (count == 0) return const _FlashResponseProfile.empty();

    final positiveLifts = <double>[];
    var responsive = 0;
    for (var i = 0; i < count; i++) {
      final reference = (baseline.tileMeans[i] + recovery.tileMeans[i]) / 2;
      final lift = max(0.0, torch.tileMeans[i] - reference);
      final liftRatio = lift / max(0.05, reference);
      positiveLifts.add(lift);
      if (lift >= 0.012 && liftRatio >= 0.065) responsive++;
    }

    final totalLift = positiveLifts.fold<double>(0, (a, b) => a + b);
    final sorted = [...positiveLifts]..sort((a, b) => b.compareTo(a));
    final topTwoLift = sorted.take(min(2, sorted.length)).fold<double>(
          0,
          (a, b) => a + b,
        );
    final hotspotConcentration =
        totalLift <= 0.000001 ? 1.0 : topTwoLift / totalLift;

    var entropy = 0.0;
    if (totalLift > 0.000001) {
      for (final lift in positiveLifts) {
        if (lift <= 0) continue;
        final p = lift / totalLift;
        entropy -= p * log(p);
      }
      entropy = entropy / log(count);
    }

    final baselineReference =
        (baseline.meanLuma + recovery.meanLuma) / 2;
    final globalLift = max(0.0, torch.meanLuma - baselineReference);
    final globalLiftRatio =
        (globalLift / max(0.05, baselineReference)).clamp(0.0, 1.0);

    return _FlashResponseProfile(
      globalLiftRatio: globalLiftRatio.toDouble(),
      responsiveTileFraction: responsive / count,
      responseEntropy: entropy.clamp(0.0, 1.0).toDouble(),
      hotspotConcentration:
          hotspotConcentration.clamp(0.0, 1.0).toDouble(),
    );
  }

  double _persistentPattern(
    _FrameStats? baseline,
    _FrameStats? recovery,
  ) {
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
    final band = _median(frames.map((frame) => frame.bandContrast).toList());
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
    final totalEnergy =
        centered.map((value) => value * value).reduce((a, b) => a + b);
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
      strongest = max(
        strongest,
        (real * real + imaginary * imaginary) / centered.length,
      );
    }

    final dominance = strongest / totalEnergy;
    final contrast = sqrt(totalEnergy / centered.length);
    return (dominance * 1.8 + contrast * 2.4)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  Map<String, dynamic> _unknown(
    String reason, {
    int framesAnalyzed = 0,
    String? error,
  }) {
    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 3,
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

class _FlashResponseProfile {
  const _FlashResponseProfile({
    required this.globalLiftRatio,
    required this.responsiveTileFraction,
    required this.responseEntropy,
    required this.hotspotConcentration,
  });

  const _FlashResponseProfile.empty()
      : globalLiftRatio = 0,
        responsiveTileFraction = 0,
        responseEntropy = 0,
        hotspotConcentration = 1;

  final double globalLiftRatio;
  final double responsiveTileFraction;
  final double responseEntropy;
  final double hotspotConcentration;
}
