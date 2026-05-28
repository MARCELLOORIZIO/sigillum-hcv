import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';

class HCVLiveScreenProbe {
  Future<Map<String, dynamic>> analyzePreview(
    CameraController controller, {
    Duration duration = const Duration(milliseconds: 1600),
    int maxFrames = 45,
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
    final done = Completer<void>();

    try {
      await controller.startImageStream((image) {
        if (frameStats.length >= maxFrames) {
          if (!done.isCompleted) done.complete();
          return;
        }

        final stats = _readFrameStats(image);
        if (stats != null) {
          frameStats.add(stats);
        }

        if (frameStats.length >= maxFrames && !done.isCompleted) {
          done.complete();
        }
      });

      await Future.any([
        done.future,
        Future.delayed(duration),
      ]);
    } catch (_) {
      return _unknown('LIVE_PROBE_FAILED');
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
    }

    if (frameStats.length < 8) {
      return _unknown('NOT_ENOUGH_PREVIEW_FRAMES');
    }

    return _analyze(frameStats);
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
    final bandTemporalScore = _bandTemporalScore(frames);
    final stableExposureScore = 1.0 - _seriesDelta(meanSeries).clamp(0.0, 1.0);

    final strongRefreshTrace =
        refreshBandScore > 0.18 || bandTemporalScore > 0.10;
    final pairedFlickerTrace = localFlickerScore > 0.18 &&
        (refreshBandScore > 0.08 || bandTemporalScore > 0.06);

    var riskScore = 0;
    if (strongRefreshTrace) riskScore += 35;
    if (pairedFlickerTrace) riskScore += 45;
    if (globalFlickerScore > 0.16 && strongRefreshTrace) riskScore += 10;
    if (stableExposureScore > 0.94 && pairedFlickerTrace) riskScore += 5;
    riskScore = riskScore.clamp(0, 100).toInt();

    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'framesAnalyzed': frames.length,
      'screenReplayRisk': _riskLabel(riskScore),
      'screenReplayRiskScore': riskScore,
      'globalFlickerScore': _round(globalFlickerScore),
      'localTemporalFlickerScore': _round(localFlickerScore.toDouble()),
      'refreshBandScore': _round(refreshBandScore),
      'bandTemporalScore': _round(bandTemporalScore),
      'stableExposureScore': _round(stableExposureScore),
      'signals': {
        'livePreviewAnalyzed': true,
        'strongRefreshTrace': strongRefreshTrace,
        'pairedFlickerTrace': pairedFlickerTrace,
        'globalFlicker': globalFlickerScore > 0.16,
        'localRefreshFlicker': localFlickerScore > 0.18,
        'horizontalRefreshBands': refreshBandScore > 0.12,
        'movingRefreshBands': bandTemporalScore > 0.10,
      },
      'note':
          'Live preview screen probe measured before capture. It is evidence of display flicker/bands, not absolute proof.',
    };
  }

  _FrameStats? _readFrameStats(CameraImage image) {
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
    var total = 0.0;
    var count = 0;

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
      meanLuma: total / count,
      tileMeans: tileMeans,
      bandMeans: bandMeans,
      bandContrast: _profileContrast(bandMeans),
    );
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

  Map<String, dynamic> _unknown(String reason) {
    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'reason': reason,
    };
  }

  String _riskLabel(int riskScore) {
    return riskScore >= 60
        ? 'HIGH'
        : riskScore >= 35
            ? 'MEDIUM'
            : 'LOW';
  }

  double _round(double value) => double.parse(value.toStringAsFixed(4));
}

class _FrameStats {
  final double meanLuma;
  final List<double> tileMeans;
  final List<double> bandMeans;
  final double bandContrast;

  _FrameStats({
    required this.meanLuma,
    required this.tileMeans,
    required this.bandMeans,
    required this.bandContrast,
  });
}
