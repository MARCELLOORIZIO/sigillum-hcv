import 'dart:math';

class HCVProjectiveFlowSample {
  const HCVProjectiveFlowSample({
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
    required this.dx,
    required this.dy,
    required this.quality,
    required this.boundaryHit,
  });

  final double x;
  final double y;
  final double targetX;
  final double targetY;
  final double dx;
  final double dy;
  final double quality;
  final bool boundaryHit;
}

class HCVProjectiveMotionFit {
  const HCVProjectiveMotionFit({
    required this.motionMagnitude,
    required this.flowReliability,
    required this.directionCoherence,
    required this.depthDispersion,
    required this.planarCoherence,
    required this.matchedRegions,
    required this.inlierRegions,
    required this.dominantPlaneRatio,
    required this.boundarySaturation,
  });

  const HCVProjectiveMotionFit.empty()
    : motionMagnitude = 0.0,
      flowReliability = 0.0,
      directionCoherence = 0.0,
      depthDispersion = 0.0,
      planarCoherence = 0.0,
      matchedRegions = 0,
      inlierRegions = 0,
      dominantPlaneRatio = 0.0,
      boundarySaturation = 0.0;

  final double motionMagnitude;
  final double flowReliability;
  final double directionCoherence;
  final double depthDispersion;
  final double planarCoherence;
  final int matchedRegions;
  final int inlierRegions;
  final double dominantPlaneRatio;
  final double boundarySaturation;
}

class HCVProjectiveMotionModel {
  const HCVProjectiveMotionModel._();

  static const double _inlierThresholdCells = 0.92;
  static const int _maxCandidateModels = 180;

  static HCVProjectiveMotionFit fit(
    List<HCVProjectiveFlowSample> samples, {
    required double maxShift,
    required int expectedRegions,
    required double xScale,
    required double yScale,
  }) {
    if (samples.length < 5 ||
        maxShift <= 0.0 ||
        expectedRegions <= 0 ||
        xScale <= 0.0 ||
        yScale <= 0.0) {
      return const HCVProjectiveMotionFit.empty();
    }

    _ProjectiveTransform? bestModel;
    List<bool>? bestMask;
    var bestScore = double.negativeInfinity;

    for (final indices in _candidateQuads(samples)) {
      final weights = List<double>.filled(samples.length, 0.0);
      for (final index in indices) {
        weights[index] = max(0.05, samples[index].quality).toDouble();
      }
      final model = _fitProjective(samples, weights);
      if (model == null) continue;

      final residuals = _residuals(
        samples,
        model,
        xScale: xScale,
        yScale: yScale,
      );
      final mask = List<bool>.generate(
        samples.length,
        (index) => residuals[index] <= _inlierThresholdCells,
      );

      var inlierCount = 0;
      var inlierWeight = 0.0;
      var weightedResidual = 0.0;
      for (var index = 0; index < samples.length; index++) {
        if (!mask[index]) continue;
        final quality = max(0.05, samples[index].quality).toDouble();
        inlierCount++;
        inlierWeight += quality;
        weightedResidual += residuals[index] * quality;
      }
      if (inlierCount < 5 || inlierWeight <= 0.0) continue;

      final meanResidual = weightedResidual / inlierWeight;
      final spatialCoverage = _spatialCoverage(samples, mask);
      final score =
          inlierWeight +
          inlierCount * 0.01 +
          spatialCoverage * 0.60 -
          meanResidual * 0.35;
      if (score > bestScore) {
        bestScore = score;
        bestModel = model;
        bestMask = mask;
      }
    }

    if (bestModel == null || bestMask == null) {
      return const HCVProjectiveMotionFit.empty();
    }

    var model = bestModel;
    var mask = bestMask;
    for (var iteration = 0; iteration < 3; iteration++) {
      final weights = List<double>.generate(
        samples.length,
        (index) =>
            mask[index] ? max(0.05, samples[index].quality).toDouble() : 0.0,
      );
      final refined = _fitProjective(samples, weights);
      if (refined == null) break;
      final residuals = _residuals(
        samples,
        refined,
        xScale: xScale,
        yScale: yScale,
      );
      final nextMask = List<bool>.generate(
        samples.length,
        (index) => residuals[index] <= _inlierThresholdCells,
      );
      if (nextMask.where((value) => value).length < 5) break;
      model = refined;
      mask = nextMask;
    }

    final residuals = _residuals(
      samples,
      model,
      xScale: xScale,
      yScale: yScale,
    );
    mask = List<bool>.generate(
      samples.length,
      (index) => residuals[index] <= _inlierThresholdCells,
    );

    final inliers = <HCVProjectiveFlowSample>[];
    final inlierResiduals = <double>[];
    var totalWeight = 0.0;
    var inlierWeight = 0.0;
    var qualityTotal = 0.0;
    var saturationWeight = 0.0;

    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final quality = max(0.05, sample.quality).toDouble();
      totalWeight += quality;
      qualityTotal += sample.quality.clamp(0.0, 1.0).toDouble();
      if (sample.boundaryHit) saturationWeight += quality;
      if (!mask[index]) continue;
      inlierWeight += quality;
      inliers.add(sample);
      inlierResiduals.add(residuals[index]);
    }

    if (inliers.length < 5 || totalWeight <= 0.0) {
      return const HCVProjectiveMotionFit.empty();
    }

    final dominantPlaneRatio = (inlierWeight / totalWeight)
        .clamp(0.0, 1.0)
        .toDouble();
    final boundarySaturation = (saturationWeight / totalWeight)
        .clamp(0.0, 1.0)
        .toDouble();
    final globalDx = _median(inliers.map((sample) => sample.dx).toList());
    final globalDy = _median(inliers.map((sample) => sample.dy).toList());
    final globalMagnitude = sqrt(globalDx * globalDx + globalDy * globalDy);
    final motionMagnitude = (globalMagnitude / maxShift)
        .clamp(0.0, 1.0)
        .toDouble();

    final meanQuality = (qualityTotal / samples.length)
        .clamp(0.0, 1.0)
        .toDouble();
    final coverage = (samples.length / expectedRegions)
        .clamp(0.0, 1.0)
        .toDouble();
    final spatialCoverage = _spatialCoverage(samples, mask);
    final flowReliability =
        ((meanQuality * 0.34 +
                    coverage * 0.18 +
                    dominantPlaneRatio * 0.30 +
                    spatialCoverage * 0.18) *
                (1.0 - boundarySaturation * 0.72))
            .clamp(0.0, 1.0)
            .toDouble();

    var directionTotal = 0.0;
    for (final sample in inliers) {
      final magnitude = sqrt(sample.dx * sample.dx + sample.dy * sample.dy);
      if (globalMagnitude < 0.25 || magnitude < 0.25) {
        directionTotal += 0.5;
      } else {
        final cosine =
            ((sample.dx * globalDx + sample.dy * globalDy) /
                    (magnitude * globalMagnitude))
                .clamp(-1.0, 1.0)
                .toDouble();
        directionTotal += (cosine + 1.0) / 2.0;
      }
    }
    final directionCoherence = (directionTotal / inliers.length)
        .clamp(0.0, 1.0)
        .toDouble();

    final planeResidual = _percentile(inlierResiduals, 0.80);
    final residualReference = max(0.70, min(globalMagnitude, 2.4)).toDouble();
    final normalizedPlaneResidual = (planeResidual / residualReference)
        .clamp(0.0, 1.0)
        .toDouble();
    final missingConsensusPenalty = dominantPlaneRatio >= 0.75
        ? 0.0
        : ((0.75 - dominantPlaneRatio) * 7.0).clamp(0.0, 1.0).toDouble();
    final depthDispersion = max(
      normalizedPlaneResidual,
      missingConsensusPenalty,
    ).clamp(0.0, 1.0).toDouble();
    final planarCoherence =
        (flowReliability *
                directionCoherence *
                (1.0 - depthDispersion) *
                (0.72 + dominantPlaneRatio * 0.28))
            .clamp(0.0, 1.0)
            .toDouble();

    return HCVProjectiveMotionFit(
      motionMagnitude: motionMagnitude,
      flowReliability: flowReliability,
      directionCoherence: directionCoherence,
      depthDispersion: depthDispersion,
      planarCoherence: planarCoherence,
      matchedRegions: samples.length,
      inlierRegions: inliers.length,
      dominantPlaneRatio: dominantPlaneRatio,
      boundarySaturation: boundarySaturation,
    );
  }

  static List<List<int>> _candidateQuads(
    List<HCVProjectiveFlowSample> samples,
  ) {
    final candidates = <List<int>>[];
    final seen = <String>{};
    var seed = samples.length * 7919 + 17;
    var attempts = 0;

    while (candidates.length < _maxCandidateModels && attempts < 1600) {
      attempts++;
      final indices = <int>{};
      while (indices.length < 4) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        indices.add(seed % samples.length);
      }
      final ordered = indices.toList()..sort();
      final key = ordered.join(',');
      if (!seen.add(key)) continue;
      if (!_isStableQuad(ordered.map((index) => samples[index]).toList())) {
        continue;
      }
      candidates.add(ordered);
    }

    if (candidates.isEmpty && samples.length >= 4) {
      final fallback = <int>[0, 1, samples.length - 2, samples.length - 1];
      if (_isStableQuad(fallback.map((index) => samples[index]).toList())) {
        candidates.add(fallback);
      }
    }
    return candidates;
  }

  static bool _isStableQuad(List<HCVProjectiveFlowSample> points) {
    if (points.length != 4) return false;
    final minX = points.map((point) => point.x).reduce(min);
    final maxX = points.map((point) => point.x).reduce(max);
    final minY = points.map((point) => point.y).reduce(min);
    final maxY = points.map((point) => point.y).reduce(max);
    if ((maxX - minX) * (maxY - minY) < 0.28) return false;

    var maxArea = 0.0;
    for (var a = 0; a < points.length - 2; a++) {
      for (var b = a + 1; b < points.length - 1; b++) {
        for (var c = b + 1; c < points.length; c++) {
          final area =
              ((points[b].x - points[a].x) * (points[c].y - points[a].y) -
                      (points[b].y - points[a].y) * (points[c].x - points[a].x))
                  .abs();
          maxArea = max(maxArea, area);
        }
      }
    }
    return maxArea >= 0.08;
  }

  static _ProjectiveTransform? _fitProjective(
    List<HCVProjectiveFlowSample> samples,
    List<double> weights,
  ) {
    if (samples.length != weights.length) return null;
    final normal = List<List<double>>.generate(
      8,
      (_) => List<double>.filled(8, 0.0),
    );
    final target = List<double>.filled(8, 0.0);
    var useful = 0;

    void addEquation(List<double> row, double value, double weight) {
      for (var r = 0; r < 8; r++) {
        target[r] += weight * row[r] * value;
        for (var c = 0; c < 8; c++) {
          normal[r][c] += weight * row[r] * row[c];
        }
      }
    }

    for (var index = 0; index < samples.length; index++) {
      final weight = weights[index];
      if (weight <= 0.0) continue;
      useful++;
      final sample = samples[index];
      final x = sample.x;
      final y = sample.y;
      final tx = sample.targetX;
      final ty = sample.targetY;
      addEquation(
        <double>[x, y, 1.0, 0.0, 0.0, 0.0, -tx * x, -tx * y],
        tx,
        weight,
      );
      addEquation(
        <double>[0.0, 0.0, 0.0, x, y, 1.0, -ty * x, -ty * y],
        ty,
        weight,
      );
    }
    if (useful < 4) return null;
    for (var index = 0; index < 8; index++) {
      normal[index][index] += 0.0000005;
    }

    final solved = _solveLinear(normal, target);
    return solved == null ? null : _ProjectiveTransform(solved);
  }

  static List<double> _residuals(
    List<HCVProjectiveFlowSample> samples,
    _ProjectiveTransform model, {
    required double xScale,
    required double yScale,
  }) {
    return samples.map((sample) {
      final predicted = model.transform(sample.x, sample.y);
      if (predicted == null) return double.infinity;
      final errorX = (predicted.$1 - sample.targetX) * xScale;
      final errorY = (predicted.$2 - sample.targetY) * yScale;
      return sqrt(errorX * errorX + errorY * errorY);
    }).toList();
  }

  static double _spatialCoverage(
    List<HCVProjectiveFlowSample> samples,
    List<bool> mask,
  ) {
    final selected = <HCVProjectiveFlowSample>[];
    for (var index = 0; index < samples.length; index++) {
      if (index < mask.length && mask[index]) selected.add(samples[index]);
    }
    if (selected.length < 4) return 0.0;
    final minX = selected.map((point) => point.x).reduce(min);
    final maxX = selected.map((point) => point.x).reduce(max);
    final minY = selected.map((point) => point.y).reduce(min);
    final maxY = selected.map((point) => point.y).reduce(max);
    return (((maxX - minX) * (maxY - minY)) / 4.0).clamp(0.0, 1.0).toDouble();
  }

  static List<double>? _solveLinear(
    List<List<double>> matrix,
    List<double> target,
  ) {
    final size = target.length;
    final values = List<List<double>>.generate(
      size,
      (row) => <double>[...matrix[row], target[row]],
    );

    for (var column = 0; column < size; column++) {
      var pivot = column;
      for (var row = column + 1; row < size; row++) {
        if (values[row][column].abs() > values[pivot][column].abs()) {
          pivot = row;
        }
      }
      if (values[pivot][column].abs() < 0.0000000001) return null;
      if (pivot != column) {
        final temporary = values[column];
        values[column] = values[pivot];
        values[pivot] = temporary;
      }

      final divisor = values[column][column];
      for (var item = column; item <= size; item++) {
        values[column][item] /= divisor;
      }
      for (var row = 0; row < size; row++) {
        if (row == column) continue;
        final factor = values[row][column];
        if (factor.abs() < 0.0000000001) continue;
        for (var item = column; item <= size; item++) {
          values[row][item] -= factor * values[column][item];
        }
      }
    }

    return List<double>.generate(size, (index) => values[index][size]);
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = <double>[...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  static double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    final sorted = <double>[...values]..sort();
    final position =
        (sorted.length - 1) * percentile.clamp(0.0, 1.0).toDouble();
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final weight = position - lower;
    return sorted[lower] * (1.0 - weight) + sorted[upper] * weight;
  }
}

class _ProjectiveTransform {
  const _ProjectiveTransform(this.values);

  final List<double> values;

  (double, double)? transform(double x, double y) {
    final denominator = values[6] * x + values[7] * y + 1.0;
    if (denominator.abs() < 0.000001) return null;
    final targetX = (values[0] * x + values[1] * y + values[2]) / denominator;
    final targetY = (values[3] * x + values[4] * y + values[5]) / denominator;
    if (!targetX.isFinite || !targetY.isFinite) return null;
    return (targetX, targetY);
  }
}
