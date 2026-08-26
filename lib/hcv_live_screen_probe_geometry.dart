part of 'hcv_live_screen_probe.dart';

HCVSceneGeometryClassification _analyzeGeometry(List<_FrameStats> frames) {
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
  final candidates = <_ProjectiveGeometryCandidate>[];

  List<int> selectedIndices(List<_FrameStats> phaseFrames) {
    if (phaseFrames.isEmpty) return const <int>[];
    return <int>{
      0,
      phaseFrames.length ~/ 4,
      phaseFrames.length ~/ 2,
      (phaseFrames.length * 3) ~/ 4,
      phaseFrames.length - 1,
    }.toList()..sort();
  }

  void consider(
    _FrameStats before,
    _FrameStats after, {
    required bool crossOffPhase,
  }) {
    final fit = _measureProjectiveGeometryPair(before, after);
    if (fit.matchedRegions < 5 ||
        fit.flowReliability < 0.23 ||
        fit.motionMagnitude < 0.035) {
      return;
    }

    final motionUsability = fit.motionMagnitude < 0.10
        ? fit.motionMagnitude / 0.10
        : fit.motionMagnitude > 0.92
        ? ((1.0 - fit.motionMagnitude) / 0.08).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final geometrySignal = max(
      fit.planarCoherence,
      min(0.82, fit.depthDispersion),
    );
    final score =
        fit.flowReliability * 0.48 +
        motionUsability * 0.27 +
        geometrySignal * 0.20 +
        fit.dominantPlaneRatio * 0.12 -
        fit.boundarySaturation * 0.25 -
        (crossOffPhase ? 0.015 : 0.0);
    candidates.add(_ProjectiveGeometryCandidate(fit, score));
  }

  void addWithinPhasePairs(List<_FrameStats> phaseFrames) {
    final indices = selectedIndices(phaseFrames);
    for (var gap = 1; gap <= 2; gap++) {
      for (var index = 0; index + gap < indices.length; index++) {
        consider(
          phaseFrames[indices[index]],
          phaseFrames[indices[index + gap]],
          crossOffPhase: false,
        );
      }
    }
  }

  addWithinPhasePairs(baseline);
  addWithinPhasePairs(recovery);

  // Both groups are captured with the torch OFF. The user's lateral movement
  // can occur mainly while the torch phase is running, so excluding these
  // pairs loses the only useful viewpoint change. Photometric normalization in
  // the matcher removes the exposure difference between baseline and recovery.
  if (baseline.isNotEmpty && recovery.isNotEmpty) {
    final baselineIndices = selectedIndices(baseline);
    final recoveryIndices = selectedIndices(recovery);
    final crossPairs = <List<int>>[
      <int>[baselineIndices.first, recoveryIndices.last],
      <int>[baselineIndices.last, recoveryIndices.first],
      <int>[
        baselineIndices[baselineIndices.length ~/ 2],
        recoveryIndices[recoveryIndices.length ~/ 2],
      ],
      <int>[
        baselineIndices[min(1, baselineIndices.length - 1)],
        recoveryIndices[max(0, recoveryIndices.length - 2)],
      ],
    ];
    for (final pair in crossPairs) {
      consider(baseline[pair[0]], recovery[pair[1]], crossOffPhase: true);
    }
  }

  if (candidates.isEmpty) {
    return HCVSceneGeometryClassifier.classify(
      motionMagnitude: 0,
      flowReliability: 0,
      directionCoherence: 0,
      depthDispersion: 0,
      planarCoherence: 0,
      matchedRegions: 0,
    );
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  final fit = candidates.first.fit;
  return HCVSceneGeometryClassifier.classify(
    motionMagnitude: fit.motionMagnitude,
    flowReliability: fit.flowReliability,
    directionCoherence: fit.directionCoherence,
    depthDispersion: fit.depthDispersion,
    planarCoherence: fit.planarCoherence,
    matchedRegions: fit.matchedRegions,
  );
}

HCVProjectiveMotionFit _measureProjectiveGeometryPair(
  _FrameStats before,
  _FrameStats after,
) {
  if (before.geometryWidth != after.geometryWidth ||
      before.geometryHeight != after.geometryHeight ||
      before.geometryLuma.length != after.geometryLuma.length ||
      before.geometryLuma.isEmpty) {
    return const HCVProjectiveMotionFit.empty();
  }

  final width = before.geometryWidth;
  final height = before.geometryHeight;
  const regionsX = 5;
  const regionsY = 4;
  const patchRadius = 2;
  const maxShift = 6;
  const localSearchRadius = 3;
  final global = _estimateProjectiveGlobalShift(before, after, maxShift);
  final samples = <HCVProjectiveFlowSample>[];
  final xScale = max(1.0, (width - 1) / 2.0).toDouble();
  final yScale = max(1.0, (height - 1) / 2.0).toDouble();

  for (var regionY = 0; regionY < regionsY; regionY++) {
    for (var regionX = 0; regionX < regionsX; regionX++) {
      final margin = patchRadius + maxShift;
      final usableWidth = max(1, width - margin * 2);
      final usableHeight = max(1, height - margin * 2);
      final centerX =
          margin + (((regionX + 0.5) * usableWidth) / regionsX).floor();
      final centerY =
          margin + (((regionY + 0.5) * usableHeight) / regionsY).floor();

      final sourcePatch = _readProjectivePatch(
        before.geometryLuma,
        width,
        centerX,
        centerY,
        patchRadius,
      );
      final texture = _geometryStandardDeviation(sourcePatch);
      if (texture < 0.010) continue;

      var bestError = double.infinity;
      var secondError = double.infinity;
      var bestDx = global.dx;
      var bestDy = global.dy;
      final minimumDx = max(-maxShift, global.dx - localSearchRadius);
      final maximumDx = min(maxShift, global.dx + localSearchRadius);
      final minimumDy = max(-maxShift, global.dy - localSearchRadius);
      final maximumDy = min(maxShift, global.dy + localSearchRadius);

      for (var dy = minimumDy; dy <= maximumDy; dy++) {
        for (var dx = minimumDx; dx <= maximumDx; dx++) {
          final targetPatch = _readProjectivePatch(
            after.geometryLuma,
            width,
            centerX + dx,
            centerY + dy,
            patchRadius,
          );
          final error = _zeroMeanNormalizedPatchError(sourcePatch, targetPatch);
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

      final fit = (1.0 - bestError / 0.95).clamp(0.0, 1.0).toDouble();
      final uniqueness = secondError.isFinite && secondError > 0
          ? ((secondError - bestError) / secondError * 3.2)
                .clamp(0.0, 1.0)
                .toDouble()
          : 0.0;
      final quality = fit * 0.70 + uniqueness * 0.20 + global.quality * 0.10;
      if (quality < 0.30) continue;

      final normalizedX = (centerX - (width - 1) / 2.0) / xScale;
      final normalizedY = (centerY - (height - 1) / 2.0) / yScale;
      samples.add(
        HCVProjectiveFlowSample(
          x: normalizedX,
          y: normalizedY,
          targetX: normalizedX + bestDx / xScale,
          targetY: normalizedY + bestDy / yScale,
          dx: bestDx.toDouble(),
          dy: bestDy.toDouble(),
          quality: quality,
          boundaryHit: bestDx.abs() >= maxShift || bestDy.abs() >= maxShift,
        ),
      );
    }
  }

  return HCVProjectiveMotionModel.fit(
    samples,
    maxShift: maxShift.toDouble(),
    expectedRegions: regionsX * regionsY,
    xScale: xScale,
    yScale: yScale,
  );
}

_ProjectiveGlobalShift _estimateProjectiveGlobalShift(
  _FrameStats before,
  _FrameStats after,
  int maxShift,
) {
  var bestError = double.infinity;
  var secondError = double.infinity;
  var bestDx = 0;
  var bestDy = 0;

  for (var dy = -maxShift; dy <= maxShift; dy++) {
    for (var dx = -maxShift; dx <= maxShift; dx++) {
      final error = _zeroMeanNormalizedGridShiftError(
        before.geometryLuma,
        after.geometryLuma,
        before.geometryWidth,
        before.geometryHeight,
        dx,
        dy,
      );
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

  final fit = (1.0 - bestError / 0.95).clamp(0.0, 1.0).toDouble();
  final uniqueness = secondError.isFinite && secondError > 0
      ? ((secondError - bestError) / secondError * 4.0)
            .clamp(0.0, 1.0)
            .toDouble()
      : 0.0;
  return _ProjectiveGlobalShift(
    dx: bestDx,
    dy: bestDy,
    quality: fit * 0.82 + uniqueness * 0.18,
  );
}

double _zeroMeanNormalizedGridShiftError(
  List<double> before,
  List<double> after,
  int width,
  int height,
  int dx,
  int dy,
) {
  final a = <double>[];
  final b = <double>[];
  final startX = max(0, -dx);
  final endX = min(width, width - dx);
  final startY = max(0, -dy);
  final endY = min(height, height - dy);
  for (var y = startY; y < endY; y++) {
    for (var x = startX; x < endX; x++) {
      a.add(before[y * width + x]);
      b.add(after[(y + dy) * width + x + dx]);
    }
  }
  if (a.length < 20) return 2.0;
  return _zeroMeanNormalizedPatchError(a, b);
}

List<double> _readProjectivePatch(
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

double _zeroMeanNormalizedPatchError(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 2.0;
  final meanA = a.fold<double>(0, (sum, value) => sum + value) / a.length;
  final meanB = b.fold<double>(0, (sum, value) => sum + value) / b.length;
  final stdA = max(0.008, _geometryStandardDeviation(a));
  final stdB = max(0.008, _geometryStandardDeviation(b));
  var error = 0.0;
  for (var index = 0; index < a.length; index++) {
    final normalizedA = (a[index] - meanA) / stdA;
    final normalizedB = (b[index] - meanB) / stdB;
    error += (normalizedA - normalizedB).abs();
  }
  return error / a.length;
}

double _geometryStandardDeviation(List<double> values) {
  if (values.isEmpty) return 0.0;
  final mean =
      values.fold<double>(0.0, (sum, value) => sum + value) / values.length;
  final variance =
      values
          .map((value) => pow(value - mean, 2).toDouble())
          .fold<double>(0.0, (sum, value) => sum + value) /
      values.length;
  return sqrt(variance);
}

class _ProjectiveGeometryCandidate {
  const _ProjectiveGeometryCandidate(this.fit, this.score);

  final HCVProjectiveMotionFit fit;
  final double score;
}

class _ProjectiveGlobalShift {
  const _ProjectiveGlobalShift({
    required this.dx,
    required this.dy,
    required this.quality,
  });

  final int dx;
  final int dy;
  final double quality;
}
