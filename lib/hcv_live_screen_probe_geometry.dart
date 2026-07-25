part of 'hcv_live_screen_probe.dart';

HCVSceneGeometryClassification _analyzeGeometry(
  List<_FrameStats> frames,
) {
  if (frames.length < 4) {
    return HCVSceneGeometryClassifier.classify(
      motionMagnitude: 0,
      flowReliability: 0,
      directionCoherence: 0,
      depthDispersion: 0,
      planarCoherence: 0,
      matchedRegions: 0,
    );
  }

  final baseline = frames.where((frame) => frame.phase == 0).toList();
  final recovery = frames.where((frame) => frame.phase == 2).toList();
  final pairs = <List<_FrameStats>>[];

  void addPair(List<_FrameStats> phaseFrames) {
    if (phaseFrames.length >= 4) {
      pairs.add(<_FrameStats>[phaseFrames.first, phaseFrames.last]);
      pairs.add(<_FrameStats>[
        phaseFrames[phaseFrames.length ~/ 3],
        phaseFrames[(phaseFrames.length * 2 ~/ 3)
            .clamp(0, phaseFrames.length - 1)
            .toInt()],
      ]);
    }
  }

  addPair(baseline);
  addPair(recovery);
  if (baseline.isNotEmpty && recovery.isNotEmpty) {
    pairs.add(<_FrameStats>[baseline.first, recovery.last]);
    pairs.add(<_FrameStats>[baseline.last, recovery.first]);
  }

  _GeometryMetrics? best;
  var bestScore = -1.0;
  for (final pair in pairs) {
    final metrics = _measureGeometryPair(pair[0], pair[1]);
    final score = (metrics.motionMagnitude * 0.55 +
            metrics.flowReliability * 0.35 +
            min(0.30, metrics.depthDispersion) * 0.10)
        .toDouble();
    if (score > bestScore) {
      bestScore = score;
      best = metrics;
    }
  }

  final metrics = best ?? const _GeometryMetrics.empty();
  return HCVSceneGeometryClassifier.classify(
    motionMagnitude: metrics.motionMagnitude,
    flowReliability: metrics.flowReliability,
    directionCoherence: metrics.directionCoherence,
    depthDispersion: metrics.depthDispersion,
    planarCoherence: metrics.planarCoherence,
    matchedRegions: metrics.matchedRegions,
  );
}

_GeometryMetrics _measureGeometryPair(
  _FrameStats before,
  _FrameStats after,
) {
  if (before.geometryWidth != after.geometryWidth ||
      before.geometryHeight != after.geometryHeight ||
      before.geometryLuma.length != after.geometryLuma.length ||
      before.geometryLuma.isEmpty) {
    return const _GeometryMetrics.empty();
  }

  final width = before.geometryWidth;
  final height = before.geometryHeight;
  const regionsX = 4;
  const regionsY = 3;
  const patchRadius = 1;
  const maxShift = 3;
  final flows = <_FlowVector>[];

  for (var regionY = 0; regionY < regionsY; regionY++) {
    for (var regionX = 0; regionX < regionsX; regionX++) {
      final margin = patchRadius + maxShift;
      final usableWidth = max(1, width - margin * 2);
      final usableHeight = max(1, height - margin * 2);
      final centerX = margin +
          (((regionX + 0.5) * usableWidth) / regionsX).floor();
      final centerY = margin +
          (((regionY + 0.5) * usableHeight) / regionsY).floor();

      final sourcePatch = _readPatch(
        before.geometryLuma,
        width,
        centerX,
        centerY,
        patchRadius,
      );
      final texture = _standardDeviation(sourcePatch);
      if (texture < 0.018) continue;

      var bestError = double.infinity;
      var secondError = double.infinity;
      var bestDx = 0;
      var bestDy = 0;

      for (var dy = -maxShift; dy <= maxShift; dy++) {
        for (var dx = -maxShift; dx <= maxShift; dx++) {
          final targetPatch = _readPatch(
            after.geometryLuma,
            width,
            centerX + dx,
            centerY + dy,
            patchRadius,
          );
          final error = _normalizedPatchError(sourcePatch, targetPatch);
          if (error < bestError) {
            secondError = bestError;
            bestError = error;
            bestDx = dx;
            bestDy = dy;
          } else if (error < secondError) {
            secondError = error;
          }
        }
      }

      final fit = (1.0 - bestError / max(0.055, texture * 2.8))
          .clamp(0.0, 1.0)
          .toDouble();
      final uniqueness = secondError.isFinite && secondError > 0
          ? ((secondError - bestError) / secondError * 4.0)
              .clamp(0.0, 1.0)
              .toDouble()
          : 0.0;
      final quality = fit * 0.72 + uniqueness * 0.28;
      if (quality < 0.30) continue;

      flows.add(_FlowVector(
        dx: bestDx.toDouble(),
        dy: bestDy.toDouble(),
        quality: quality,
      ));
    }
  }

  if (flows.isEmpty) return const _GeometryMetrics.empty();

  final globalDx = _median(flows.map((flow) => flow.dx).toList());
  final globalDy = _median(flows.map((flow) => flow.dy).toList());
  final globalMagnitude = sqrt(globalDx * globalDx + globalDy * globalDy);
  final motionMagnitude =
      (globalMagnitude / maxShift).clamp(0.0, 1.0).toDouble();
  final meanQuality = flows
          .map((flow) => flow.quality)
          .fold<double>(0, (sum, value) => sum + value) /
      flows.length;
  final regionCoverage = (flows.length / (regionsX * regionsY))
      .clamp(0.0, 1.0)
      .toDouble();
  final flowReliability = (meanQuality * 0.72 + regionCoverage * 0.28)
      .clamp(0.0, 1.0)
      .toDouble();

  var directionTotal = 0.0;
  final residuals = <double>[];
  for (final flow in flows) {
    final magnitude = sqrt(flow.dx * flow.dx + flow.dy * flow.dy);
    if (globalMagnitude < 0.25 || magnitude < 0.25) {
      directionTotal += 0.5;
    } else {
      final cosine = ((flow.dx * globalDx + flow.dy * globalDy) /
              (magnitude * globalMagnitude))
          .clamp(-1.0, 1.0);
      directionTotal += ((cosine + 1.0) / 2.0).toDouble();
    }
    residuals.add(
      sqrt(pow(flow.dx - globalDx, 2) + pow(flow.dy - globalDy, 2)) /
          maxShift,
    );
  }

  final directionCoherence =
      (directionTotal / flows.length).clamp(0.0, 1.0).toDouble();
  final upperResidual = _percentile(residuals, 0.75);
  final depthDispersion = (upperResidual / max(0.18, motionMagnitude))
      .clamp(0.0, 1.0)
      .toDouble();
  final planarCoherence = (flowReliability *
          directionCoherence *
          (1.0 - depthDispersion))
      .clamp(0.0, 1.0)
      .toDouble();

  return _GeometryMetrics(
    motionMagnitude: motionMagnitude,
    flowReliability: flowReliability,
    directionCoherence: directionCoherence,
    depthDispersion: depthDispersion,
    planarCoherence: planarCoherence,
    matchedRegions: flows.length,
  );
}

List<double> _readPatch(
  List<double> grid,
  int width,
  int centerX,
  int centerY,
  int radius,
) {
  final values = <double>[];
  for (var y = centerY - radius; y <= centerY + radius; y++) {
    for (var x = centerX - radius; x <= centerX + radius; x++) {
      values.add(grid[y * width + x]);
    }
  }
  return values;
}

double _normalizedPatchError(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 1;
  final meanA = a.fold<double>(0, (sum, value) => sum + value) / a.length;
  final meanB = b.fold<double>(0, (sum, value) => sum + value) / b.length;
  var error = 0.0;
  for (var i = 0; i < a.length; i++) {
    error += ((a[i] - meanA) - (b[i] - meanB)).abs();
  }
  return error / a.length;
}

double _standardDeviation(List<double> values) {
  if (values.isEmpty) return 0;
  final mean = values.fold<double>(0, (sum, value) => sum + value) /
      values.length;
  final variance = values
          .map((value) => pow(value - mean, 2).toDouble())
          .fold<double>(0, (sum, value) => sum + value) /
      values.length;
  return sqrt(variance);
}
