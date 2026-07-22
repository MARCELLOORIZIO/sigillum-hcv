import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';

class HCVLiveScreenProbe {
  Future<Map<String, dynamic>> analyzePreview(
    CameraController controller, {
    Duration duration = const Duration(milliseconds: 1600),
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

    final frameStats = <_FrameStats>[];
    double? zoomToRestore = restoreZoomLevel;

    try {
      if (useOpticalProbeZoom) {
        final minZoom = await controller.getMinZoomLevel();
        final maxZoom = await controller.getMaxZoomLevel();
        zoomToRestore ??= minZoom;
        final baselineFrames = max(8, maxFrames ~/ 2);
        final probeFrames = max(8, maxFrames - baselineFrames);
        final phaseDuration = Duration(
          milliseconds: max(450, duration.inMilliseconds ~/ 2),
        );

        await _collectFrameStats(
          controller,
          frameStats,
          maxFrames: baselineFrames,
          duration: phaseDuration,
          phase: 0,
        );

        final baselineZoom = zoomToRestore;
        final probeZoom = min(maxZoom, max(minZoom, baselineZoom + 0.55));

        if (probeZoom > baselineZoom + 0.1) {
          await controller.setZoomLevel(probeZoom);
          await Future.delayed(const Duration(milliseconds: 180));
        }

        await _collectFrameStats(
          controller,
          frameStats,
          maxFrames: probeFrames,
          duration: phaseDuration,
          phase: 1,
        );
      } else {
        await _collectFrameStats(
          controller,
          frameStats,
          maxFrames: maxFrames,
          duration: duration,
          phase: 0,
        );
      }
    } catch (e) {
      return _unknown(
        'LIVE_PROBE_FAILED',
        framesAnalyzed: frameStats.length,
        error: e.toString(),
      );
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}

      try {
        if (zoomToRestore != null && controller.value.isInitialized) {
          await controller.setZoomLevel(zoomToRestore);
        }
      } catch (_) {}
    }

    if (frameStats.length < 8) {
      return _unknown(
        'NOT_ENOUGH_PREVIEW_FRAMES',
        framesAnalyzed: frameStats.length,
      );
    }

    return _analyze(frameStats);
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

    await controller.startImageStream((image) {
      if (collected >= maxFrames) {
        if (!done.isCompleted) done.complete();
        return;
      }

      final stats = _readFrameStats(image, phase);
      if (stats != null) {
        output.add(stats);
        collected++;
      }

      if (collected >= maxFrames && !done.isCompleted) {
        done.complete();
      }
    });

    try {
      await Future.any([
        done.future,
        Future.delayed(duration),
      ]);
    } finally {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    }
  }

  Map<String, dynamic> _analyze(List<_FrameStats> frames) {
    final meanSeries = frames.map((f) => f.meanLuma).toList();
    final tileSeries = <List<double>>[];

    for (var tile = 0; tile < frames.first.tileMeans.length; tile++) {
      tileSeries.add(frames.map((f) => f.tileMeans[tile]).toList());
    }

    final globalFlickerScore = _temporalPulseScore(meanSeries);
    final localFlickerScore =
        tileSeries.map(_temporalPulseScore).reduce(max).clamp(0.0, 1.0);
    final refreshBandScore =
        frames.map((f) => f.bandContrast).reduce((a, b) => a + b) /
            frames.length;
    final fineStripeScore =
        frames.map((f) => f.fineStripeScore).reduce((a, b) => a + b) /
            frames.length;
    final fineGridScore =
        frames.map((f) => f.fineGridScore).reduce((a, b) => a + b) /
            frames.length;
    final moireFrequencyScore =
        frames.map((f) => f.moireFrequencyScore).reduce((a, b) => a + b) /
            frames.length;
    final challenge = _dynamicChallenge(frames);
    final dynamicChallengeScore = challenge['dynamicChallengeScore'] as double;
    final persistentPatternScore =
        challenge['persistentPatternScore'] as double;
    final bandTemporalScore = _bandTemporalScore(frames);
    final electronicLightScore = _electronicLightScore(frames);
    final stableExposureScore = 1.0 - _seriesDelta(meanSeries).clamp(0.0, 1.0);

    final periodicLightTrace = electronicLightScore > 0.48;
    final movingRefreshTrace = bandTemporalScore > 0.04;
    final strongRefreshTrace =
        refreshBandScore > 0.22 || bandTemporalScore > 0.10;
    final displayBandTrace = localFlickerScore > 0.34 &&
        refreshBandScore > 0.18 &&
        movingRefreshTrace;
    final opticalStripeTrace = fineStripeScore > 0.30 &&
        fineGridScore > 0.24 &&
        (refreshBandScore > 0.14 || localFlickerScore > 0.34);
    final refreshCorroboration =
        strongRefreshTrace || movingRefreshTrace || periodicLightTrace;
    final moireFrequencyTrace =
        moireFrequencyScore > 0.42 && refreshCorroboration;
    final globalDisplayPulse = globalFlickerScore > 0.16 &&
        localFlickerScore > 0.38 &&
        refreshCorroboration;
    final pairedFlickerTrace = localFlickerScore > 0.18 &&
        (refreshBandScore > 0.14 || bandTemporalScore > 0.06);
    final uncorroboratedDisplayPattern = !refreshCorroboration &&
        (refreshBandScore > 0.07 ||
            fineGridScore > 0.70 ||
            moireFrequencyScore > 0.28 ||
            (globalFlickerScore > 0.22 && localFlickerScore > 0.38));
    final dynamicScreenChallengeTrace = persistentPatternScore > 0.58 &&
        dynamicChallengeScore < 0.18 &&
        (moireFrequencyScore > 0.30 || fineGridScore > 0.70);
    final closeDisplaySpatialTrace = dynamicScreenChallengeTrace &&
        fineGridScore > 0.85 &&
        fineStripeScore < 0.42 &&
        persistentPatternScore > 0.85 &&
        dynamicChallengeScore < 0.18;
    final confirmedDisplayTrace = strongRefreshTrace ||
        displayBandTrace ||
        globalDisplayPulse ||
        periodicLightTrace;
    final opticalCorroboratedTrace =
        opticalStripeTrace && (strongRefreshTrace || displayBandTrace);
    final emissiveTemporalTrace = frames.length >= 24 &&
        localFlickerScore >= 0.55 &&
        refreshBandScore >= 0.12 &&
        (fineGridScore >= 0.80 || moireFrequencyScore >= 0.45);

    var riskScore = 0;
    if (confirmedDisplayTrace) riskScore += 50;
    if (periodicLightTrace) riskScore += 20;
    if (!confirmedDisplayTrace && closeDisplaySpatialTrace) riskScore += 20;
    if (strongRefreshTrace) riskScore += 15;
    if (opticalCorroboratedTrace) riskScore += 15;
    if (moireFrequencyTrace && confirmedDisplayTrace) riskScore += 10;
    if (!confirmedDisplayTrace && pairedFlickerTrace) riskScore += 15;
    if (!confirmedDisplayTrace && uncorroboratedDisplayPattern) riskScore += 20;
    if (dynamicScreenChallengeTrace && moireFrequencyScore > 0.42) {
      riskScore += 35;
    }
    if (globalFlickerScore > 0.16 && confirmedDisplayTrace) riskScore += 10;
    if (stableExposureScore > 0.94 && confirmedDisplayTrace) riskScore += 5;
    if (!confirmedDisplayTrace && emissiveTemporalTrace) {
      riskScore = max(riskScore, 45);
    }
    if (!confirmedDisplayTrace &&
        !emissiveTemporalTrace &&
        !(dynamicScreenChallengeTrace && moireFrequencyScore > 0.42)) {
      riskScore = min(riskScore, 30);
    }
    riskScore = riskScore.clamp(0, 100).toInt();
    final displayRiskDecision = _displayRiskDecision(
      riskScore: riskScore,
      confirmedDisplayTrace: confirmedDisplayTrace,
      emissiveTemporalTrace: emissiveTemporalTrace,
    );

    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frames.length,
      'screenReplayRisk': _riskLabel(riskScore),
      'screenReplayRiskScore': riskScore,
      'displayRiskDecision': displayRiskDecision,
      'globalFlickerScore': _round(globalFlickerScore),
      'localTemporalFlickerScore': _round(localFlickerScore.toDouble()),
      'refreshBandScore': _round(refreshBandScore),
      'fineStripeScore': _round(fineStripeScore),
      'fineGridScore': _round(fineGridScore),
      'moireFrequencyScore': _round(moireFrequencyScore),
      'dynamicChallengeScore': _round(dynamicChallengeScore),
      'persistentPatternScore': _round(persistentPatternScore),
      'bandTemporalScore': _round(bandTemporalScore),
      'electronicLightScore': _round(electronicLightScore),
      'stableExposureScore': _round(stableExposureScore),
      'signals': {
        'livePreviewAnalyzed': true,
        'strongRefreshTrace': strongRefreshTrace,
        'displayBandTrace': displayBandTrace,
        'opticalStripeTrace': opticalStripeTrace,
        'opticalCorroboratedTrace': opticalCorroboratedTrace,
        'moireFrequencyTrace': moireFrequencyTrace,
        'globalDisplayPulse': globalDisplayPulse,
        'confirmedDisplayTrace': confirmedDisplayTrace,
        'emissiveTemporalTrace': emissiveTemporalTrace,
        'periodicLightTrace': periodicLightTrace,
        'closeDisplaySpatialTrace': closeDisplaySpatialTrace,
        'pairedFlickerTrace': pairedFlickerTrace,
        'uncorroboratedDisplayPattern': uncorroboratedDisplayPattern,
        'dynamicScreenChallengeTrace': dynamicScreenChallengeTrace,
        'globalFlicker': globalFlickerScore > 0.16,
        'localRefreshFlicker': localFlickerScore > 0.18,
        'horizontalRefreshBands': refreshBandScore > 0.12,
        'movingRefreshBands': movingRefreshTrace,
      },
      'note':
          'Live preview screen probe measured before capture. It is evidence of display flicker/bands, not absolute proof.',
    };
  }

  Map<String, double> _dynamicChallenge(List<_FrameStats> frames) {
    final baseline = frames.where((f) => f.phase == 0).toList();
    final challenged = frames.where((f) => f.phase == 1).toList();

    if (baseline.length < 4 || challenged.length < 4) {
      return {
        'dynamicChallengeScore': 0,
        'persistentPatternScore': 0,
      };
    }

    final before = _phaseAverages(baseline);
    final after = _phaseAverages(challenged);
    final response = ((before.meanLuma - after.meanLuma).abs() * 1.4) +
        ((before.fineGridScore - after.fineGridScore).abs() * 0.7) +
        ((before.moireFrequencyScore - after.moireFrequencyScore).abs() * 0.9) +
        ((before.bandContrast - after.bandContrast).abs() * 0.7);
    final moireShift =
        (before.moireFrequencyScore - after.moireFrequencyScore).abs();
    final persistentPattern = min(before.fineGridScore, after.fineGridScore) *
        (1.0 - min(1.0, moireShift));

    return {
      'dynamicChallengeScore': response.clamp(0.0, 1.0).toDouble(),
      'persistentPatternScore': persistentPattern.clamp(0.0, 1.0).toDouble(),
    };
  }

  _FrameStats _phaseAverages(List<_FrameStats> frames) {
    double average(double Function(_FrameStats frame) read) {
      return frames.map(read).reduce((a, b) => a + b) / frames.length;
    }

    return _FrameStats(
      phase: frames.first.phase,
      meanLuma: average((frame) => frame.meanLuma),
      tileMeans: frames.first.tileMeans,
      bandMeans: frames.first.bandMeans,
      bandContrast: average((frame) => frame.bandContrast),
      fineStripeScore: average((frame) => frame.fineStripeScore),
      fineGridScore: average((frame) => frame.fineGridScore),
      moireFrequencyScore: average((frame) => frame.moireFrequencyScore),
    );
  }

  _FrameStats? _readFrameStats(CameraImage image, int phase) {
    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;
    final bytes = plane.bytes;
    final width = image.width;
    final height = image.height;
    final rowStride = plane.bytesPerRow;
    final pixelStride = plane.bytesPerPixel ?? 1;
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;

    if (bytes.isEmpty || width <= 0 || height <= 0 || rowStride <= 0) {
      return null;
    }

    const tiles = 4;
    const bands = 12;
    final tileTotals = List<double>.filled(tiles * tiles, 0);
    final tileCounts = List<int>.filled(tiles * tiles, 0);
    final bandTotals = List<double>.filled(bands, 0);
    final bandCounts = List<int>.filled(bands, 0);
    final fineRows = <double>[];
    final fineCols = <double>[];
    var total = 0.0;
    var count = 0;
    final centerLeft = (width * 0.18).floor();
    final centerRight = (width * 0.82).floor();
    final centerTop = (height * 0.18).floor();
    final centerBottom = (height * 0.82).floor();

    for (var y = 0; y < height; y += 6) {
      final row = y * rowStride;
      if (row >= bytes.length) break;

      for (var x = 0; x < width; x += 6) {
        final index = row + (x * pixelStride);
        if (index >= bytes.length) break;

        final luma = isBgra && index + 2 < bytes.length
            ? ((0.114 * bytes[index]) +
                    (0.587 * bytes[index + 1]) +
                    (0.299 * bytes[index + 2])) /
                255.0
            : bytes[index] / 255.0;
        total += luma;
        count++;

        final tx = min(tiles - 1, (x * tiles / width).floor());
        final ty = min(tiles - 1, (y * tiles / height).floor());
        final tileIndex = ty * tiles + tx;
        tileTotals[tileIndex] += luma;
        tileCounts[tileIndex]++;

        final band = min(bands - 1, (y * bands / height).floor());
        bandTotals[band] += luma;
        bandCounts[band]++;
      }
    }

    for (var y = centerTop; y < centerBottom; y += 2) {
      final row = y * rowStride;
      if (row >= bytes.length) break;

      var rowTotal = 0.0;
      var rowCount = 0;

      for (var x = centerLeft; x < centerRight; x += 2) {
        final index = row + (x * pixelStride);
        if (index >= bytes.length) break;

        rowTotal += _readLuma(bytes, index, isBgra);
        rowCount++;
      }

      if (rowCount > 0) {
        fineRows.add(rowTotal / rowCount);
      }
    }

    for (var x = centerLeft; x < centerRight; x += 2) {
      var colTotal = 0.0;
      var colCount = 0;

      for (var y = centerTop; y < centerBottom; y += 2) {
        final index = (y * rowStride) + (x * pixelStride);
        if (index >= bytes.length) break;

        colTotal += _readLuma(bytes, index, isBgra);
        colCount++;
      }

      if (colCount > 0) {
        fineCols.add(colTotal / colCount);
      }
    }

    if (count == 0) return null;

    final tileMeans = <double>[];
    for (var i = 0; i < tileTotals.length; i++) {
      tileMeans.add(tileTotals[i] / max(tileCounts[i], 1));
    }

    final bandMeans = <double>[];
    for (var i = 0; i < bandTotals.length; i++) {
      bandMeans.add(bandTotals[i] / max(bandCounts[i], 1));
    }

    return _FrameStats(
      phase: phase,
      meanLuma: total / count,
      tileMeans: tileMeans,
      bandMeans: bandMeans,
      bandContrast: _profileContrast(bandMeans),
      fineStripeScore: _fineStripeScore(fineRows),
      fineGridScore:
          max(_fineStripeScore(fineRows), _fineStripeScore(fineCols)),
      moireFrequencyScore: max(
        _periodicFrequencyScore(fineRows),
        _periodicFrequencyScore(fineCols),
      ),
    );
  }

  double _readLuma(List<int> bytes, int index, bool isBgra) {
    if (isBgra && index + 2 < bytes.length) {
      return ((0.114 * bytes[index]) +
              (0.587 * bytes[index + 1]) +
              (0.299 * bytes[index + 2])) /
          255.0;
    }

    return bytes[index] / 255.0;
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

      total += delta / max(count, 1);
      pairs++;
    }

    return total / max(pairs, 1);
  }

  double _electronicLightScore(List<_FrameStats> frames) {
    if (frames.length < 12) return 0;

    final series = <List<double>>[
      frames.map((f) => f.meanLuma).toList(),
    ];

    for (var tile = 0; tile < frames.first.tileMeans.length; tile++) {
      series.add(frames.map((f) => f.tileMeans[tile]).toList());
    }

    for (var band = 0; band < frames.first.bandMeans.length; band++) {
      series.add(frames.map((f) => f.bandMeans[band]).toList());
    }

    return series.map(_periodicLightSeriesScore).reduce(max);
  }

  double _periodicLightSeriesScore(List<double> series) {
    if (series.length < 12) return 0;

    final mean = series.reduce((a, b) => a + b) / series.length;
    final start = series.first;
    final end = series.last;
    final detrended = <double>[];

    for (var i = 0; i < series.length; i++) {
      final trend = start + ((end - start) * i / max(series.length - 1, 1));
      detrended.add(series[i] - trend - mean + ((start + end) / 2));
    }

    final energy =
        detrended.map((v) => v * v).reduce((a, b) => a + b) / detrended.length;
    final rms = sqrt(energy);
    if (rms < 0.0045) return 0;

    var strongest = 0.0;
    var secondStrongest = 0.0;
    final upperBin = min(series.length ~/ 2, 12);

    for (var bin = 2; bin <= upperBin; bin++) {
      var real = 0.0;
      var imaginary = 0.0;

      for (var i = 0; i < detrended.length; i++) {
        final angle = 2 * pi * bin * i / detrended.length;
        real += detrended[i] * cos(angle);
        imaginary += detrended[i] * sin(angle);
      }

      final binEnergy =
          (real * real + imaginary * imaginary) / detrended.length;
      if (binEnergy > strongest) {
        secondStrongest = strongest;
        strongest = binEnergy;
      } else if (binEnergy > secondStrongest) {
        secondStrongest = binEnergy;
      }
    }

    final totalEnergy = energy * detrended.length;
    if (totalEnergy <= 0) return 0;

    final dominance = (strongest / totalEnergy).clamp(0.0, 1.0);
    final separation = strongest <= 0
        ? 0.0
        : (1.0 - (secondStrongest / strongest)).clamp(0.0, 1.0);
    final intervalRegularity = _zeroCrossingRegularity(detrended);
    final amplitudeScore = (rms * 18).clamp(0.0, 1.0);

    return ((dominance * 0.45) +
            (separation * 0.15) +
            (intervalRegularity * 0.25) +
            (amplitudeScore * 0.15))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _zeroCrossingRegularity(List<double> centered) {
    if (centered.length < 12) return 0;

    final crossings = <int>[];
    var previous = centered.first;

    for (var i = 1; i < centered.length; i++) {
      final current = centered[i];
      if ((previous < 0 && current >= 0) || (previous >= 0 && current < 0)) {
        crossings.add(i);
      }
      previous = current;
    }

    if (crossings.length < 4) return 0;

    final intervals = <double>[];
    for (var i = 1; i < crossings.length; i++) {
      intervals.add((crossings[i] - crossings[i - 1]).toDouble());
    }

    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    if (mean <= 0) return 0;

    final variance =
        intervals.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            intervals.length;
    final coefficient = sqrt(variance) / mean;
    final crossingDensity =
        (crossings.length / centered.length).clamp(0.0, 1.0);

    return ((1.0 - coefficient).clamp(0.0, 1.0) * 0.75) +
        (crossingDensity * 0.25);
  }

  double _fineStripeScore(List<double> profile) {
    if (profile.length < 12) return 0;

    final mean = profile.reduce((a, b) => a + b) / profile.length;
    final centered = profile.map((value) => value - mean).toList();
    final contrast =
        centered.map((value) => value.abs()).reduce((a, b) => a + b) /
            centered.length;

    if (contrast < 0.004) return 0;

    var alternating = 0.0;
    var transitions = 0;
    var gradientTotal = 0.0;

    for (var i = 1; i < centered.length; i++) {
      final gradient = centered[i] - centered[i - 1];
      gradientTotal += gradient.abs();

      if (centered[i].sign != centered[i - 1].sign) {
        transitions++;
      }

      if (i > 1) {
        final previousGradient = centered[i - 1] - centered[i - 2];
        if (gradient.sign != previousGradient.sign) {
          alternating++;
        }
      }
    }

    final transitionRatio = transitions / (centered.length - 1);
    final alternatingRatio = alternating / max(centered.length - 2, 1);
    final gradientStrength = gradientTotal / (centered.length - 1);

    return ((contrast * 2.8) +
            (gradientStrength * 1.8) +
            (transitionRatio * 0.12) +
            (alternatingRatio * 0.10))
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

      final energy = (real * real + imaginary * imaginary) / centered.length;
      strongest = max(strongest, energy);
    }

    final dominance = strongest / totalEnergy;
    final contrast = sqrt(totalEnergy / centered.length);

    return ((dominance * 1.8) + (contrast * 2.4)).clamp(0.0, 1.0).toDouble();
  }

  double _temporalPulseScore(List<double> series) {
    if (series.length < 6) return 0;

    final mean = series.reduce((a, b) => a + b) / series.length;
    final centered = series.map((value) => value - mean).toList();
    final energy =
        centered.map((value) => value.abs()).reduce((a, b) => a + b) /
            centered.length;

    if (energy < 0.006) return 0;

    var alternating = 0.0;
    var transitions = 0;

    for (var i = 1; i < centered.length; i++) {
      if (centered[i].sign != centered[i - 1].sign) {
        transitions++;
      }
      alternating += (centered[i] - centered[i - 1]).abs();
    }

    final transitionRatio = transitions / (centered.length - 1);
    final alternatingStrength = alternating / (centered.length - 1);

    return ((energy * 3.0) +
            (alternatingStrength * 2.5) +
            (transitionRatio * 0.35))
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

  static double _profileContrast(List<double> profile) {
    if (profile.isEmpty) return 0;

    final mean = profile.reduce((a, b) => a + b) / profile.length;
    final variance = profile
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        profile.length;

    return sqrt(variance).clamp(0.0, 1.0).toDouble();
  }

  Map<String, dynamic> _unknown(
    String reason, {
    int framesAnalyzed = 0,
    String? error,
  }) {
    return <String, dynamic>{
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'analysisStatus': 'NOT_ANALYZED',
      'displayRiskDecision': 'NOT_ANALYZED',
      'framesAnalyzed': framesAnalyzed,
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'reason': reason,
      if (error != null && error.isNotEmpty) 'error': error,
    };
  }

  String _riskLabel(int riskScore) {
    return riskScore >= 70
        ? 'HIGH'
        : riskScore >= 45
            ? 'MEDIUM'
            : 'LOW';
  }

  String _displayRiskDecision({
    required int riskScore,
    required bool confirmedDisplayTrace,
    required bool emissiveTemporalTrace,
  }) {
    final strongEvidence = confirmedDisplayTrace && riskScore >= 70;
    if (strongEvidence) return 'STRONG_DISPLAY_RISK';

    if (riskScore < 45) return 'NO_DISPLAY_EVIDENCE';

    if (emissiveTemporalTrace && riskScore >= 45) {
      return 'NON_CONCLUSIVE';
    }

    return 'NO_DISPLAY_EVIDENCE';
  }

  double _round(double value) => double.parse(value.toStringAsFixed(4));
}

class _FrameStats {
  final int phase;
  final double meanLuma;
  final List<double> tileMeans;
  final List<double> bandMeans;
  final double bandContrast;
  final double fineStripeScore;
  final double fineGridScore;
  final double moireFrequencyScore;

  _FrameStats({
    required this.phase,
    required this.meanLuma,
    required this.tileMeans,
    required this.bandMeans,
    required this.bandContrast,
    required this.fineStripeScore,
    required this.fineGridScore,
    required this.moireFrequencyScore,
  });
}
