import 'dart:math';

class HCVPlanarFlowSample {
  const HCVPlanarFlowSample({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.quality,
    required this.boundaryHit,
  });

  final double x;
  final double y;
  final double dx;
  final double dy;
  final double quality;
  final bool boundaryHit;
}

class HCVPlanarMotionFit {
  const HCVPlanarMotionFit({
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

  const HCVPlanarMotionFit.empty()
      : motionMagnitude = 0,
        flowReliability = 0,
        directionCoherence = 0,
        depthDispersion = 0,
        planarCoherence = 0,
        matchedRegions = 0,
        inlierRegions = 0,
        dominantPlaneRatio = 0,
        boundarySaturation = 0;

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

class HCVPlanarMotionModel {
  const HCVPlanarMotionModel._();

  static HCVPlanarMotionFit fit(
    List<HCVPlanarFlowSample> samples, {
    required double maxShift,
    required int expectedRegions,
  }) {
    if (samples.length < 4 || maxShift <= 0 || expectedRegions <= 0) {
      return const HCVPlanarMotionFit.empty();
    }

    const inlierThreshold = 0.80;
    _AffineMotion? bestModel;
    List<bool>? bestInliers;
    var bestScore = double.negativeInfinity;

    for (var first = 0; first < samples.length - 2; first++) {
      for (var second = first + 1; second < samples.length - 1; second++) {
        for (var third = second + 1; third < samples.length; third++) {
          final a = samples[first];
          final b = samples[second];
          final c = samples[third];
          final area = ((b.x - a.x) * (c.y - a.y) -
                  (b.y - a.y) * (c.x - a.x))
              .abs();
          if (area < 0.025) continue;

          final weights = List<double>.filled(samples.length, 0);
          weights[first] = max(0.05, a.quality);
          weights[second] = max(0.05, b.quality);
          weights[third] = max(0.05, c.quality);
          final model = _fitAffine(samples, weights);
          if (model == null) continue;

          final residuals = _residuals(samples, model);
          final inliers = List<bool>.generate(
            samples.length,
            (index) => residuals[index] <= inlierThreshold,
          );
          var inlierWeight = 0.0;
          var weightedResidual = 0.0;
          var inlierCount = 0;
          for (var index = 0; index < samples.length; index++) {
            if (!inliers[index]) continue;
            final quality = max(0.05, samples[index].quality);
            inlierWeight += quality;
            weightedResidual += residuals[index] * quality;
            inlierCount++;
          }
          if (inlierCount < 4) continue;

          final meanResidual = weightedResidual / max(0.000001, inlierWeight);
          final score = inlierWeight - meanResidual * 0.06 + inlierCount * 0.001;
          if (score > bestScore) {
            bestScore = score;
            bestModel = model;
            bestInliers = inliers;
          }
        }
      }
    }

    if (bestModel == null || bestInliers == null) {
      return const HCVPlanarMotionFit.empty();
    }

    var inliers = bestInliers;
    var model = bestModel;
    for (var iteration = 0; iteration < 2; iteration++) {
      final weights = List<double>.generate(
        samples.length,
        (index) => inliers[index] ? max(0.05, samples[index].quality) : 0,
      );
      final refined = _fitAffine(samples, weights);
      if (refined == null) break;
      model = refined;
      final residuals = _residuals(samples, model);
      inliers = List<bool>.generate(
        samples.length,
        (index) => residuals[index] <= inlierThreshold,
      );
      if (inliers.where((value) => value).length < 4) break;
    }

    final residuals = _residuals(samples, model);
    inliers = List<bool>.generate(
      samples.length,
      (index) => residuals[index] <= inlierThreshold,
    );
    final inlierSamples = <HCVPlanarFlowSample>[];
    final inlierResiduals = <double>[];
    var totalWeight = 0.0;
    var inlierWeight = 0.0;
    var saturationWeight = 0.0;
    var qualityTotal = 0.0;
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final quality = max(0.05, sample.quality);
      totalWeight += quality;
      qualityTotal += sample.quality.clamp(0.0, 1.0);
      if (sample.boundaryHit) saturationWeight += quality;
      if (inliers[index]) {
        inlierWeight += quality;
        inlierSamples.add(sample);
        inlierResiduals.add(residuals[index]);
      }
    }
    if (inlierSamples.length < 4 || totalWeight <= 0) {
      return const HCVPlanarMotionFit.empty();
    }

    final dominantPlaneRatio =
        (inlierWeight / totalWeight).clamp(0.0, 1.0).toDouble();
    final boundarySaturation =
        (saturationWeight / totalWeight).clamp(0.0, 1.0).toDouble();
    final globalDx = _median(inlierSamples.map((sample) => sample.dx).toList());
    final globalDy = _median(inlierSamples.map((sample) => sample.dy).toList());
    final globalMagnitude = sqrt(globalDx * globalDx + globalDy * globalDy);
    final motionMagnitude =
        (globalMagnitude / maxShift).clamp(0.0, 1.0).toDouble();

    final meanQuality =
        (qualityTotal / samples.length).clamp(0.0, 1.0).toDouble();
    final coverage =
        (samples.length / expectedRegions).clamp(0.0, 1.0).toDouble();
    final flowReliability = ((meanQuality * 0.45 +
                coverage * 0.20 +
                dominantPlaneRatio * 0.35) *
            (1.0 - boundarySaturation * 0.75))
        .clamp(0.0, 1.0)
        .toDouble();

    var directionTotal = 0.0;
    for (final sample in inlierSamples) {
      final magnitude = sqrt(sample.dx * sample.dx + sample.dy * sample.dy);
      if (globalMagnitude < 0.25 || magnitude < 0.25) {
        directionTotal += 0.5;
      } else {
        final cosine = ((sample.dx * globalDx + sample.dy * globalDy) /
                (magnitude * globalMagnitude))
            .clamp(-1.0, 1.0)
            .toDouble();
        directionTotal += (cosine + 1.0) / 2.0;
      }
    }
    final directionCoherence =
        (directionTotal / inlierSamples.length).clamp(0.0, 1.0).toDouble();

    final planeResidual = _percentile(inlierResiduals, 0.75);
    final normalizedPlaneResidual =
        (planeResidual / max(0.75, min(globalMagnitude, 2.0)))
            .clamp(0.0, 1.0)
            .toDouble();
    final missingConsensusPenalty = dominantPlaneRatio >= 0.72
        ? 0.0
        : ((0.72 - dominantPlaneRatio) * 4.0)
            .clamp(0.0, 1.0)
            .toDouble();
    final depthDispersion =
        max(normalizedPlaneResidual, missingConsensusPenalty)
            .clamp(0.0, 1.0)
            .toDouble();
    final planarCoherence =
        (flowReliability * directionCoherence * (1.0 - depthDispersion))
            .clamp(0.0, 1.0)
            .toDouble();

    return HCVPlanarMotionFit(
      motionMagnitude: motionMagnitude,
      flowReliability: flowReliability,
      directionCoherence: directionCoherence,
      depthDispersion: depthDispersion,
      planarCoherence: planarCoherence,
      matchedRegions: samples.length,
      inlierRegions: inlierSamples.length,
      dominantPlaneRatio: dominantPlaneRatio,
      boundarySaturation: boundarySaturation,
    );
  }

  static _AffineMotion? _fitAffine(
    List<HCVPlanarFlowSample> samples,
    List<double> weights,
  ) {
    if (samples.length != weights.length) return null;
    final normal = List<List<double>>.generate(
      3,
      (_) => List<double>.filled(3, 0),
    );
    final targetX = List<double>.filled(3, 0);
    final targetY = List<double>.filled(3, 0);
    var useful = 0;

    for (var index = 0; index < samples.length; index++) {
      final weight = weights[index];
      if (weight <= 0) continue;
      useful++;
      final sample = samples[index];
      final row = <double>[1.0, sample.x, sample.y];
      for (var r = 0; r < 3; r++) {
        targetX[r] += weight * row[r] * sample.dx;
        targetY[r] += weight * row[r] * sample.dy;
        for (var c = 0; c < 3; c++) {
          normal[r][c] += weight * row[r] * row[c];
        }
      }
    }
    if (useful < 3) return null;
    for (var index = 0; index < 3; index++) {
      normal[index][index] += 0.00001;
    }

    final coefficientsX = _solve3x3(normal, targetX);
    final coefficientsY = _solve3x3(normal, targetY);
    if (coefficientsX == null || coefficientsY == null) return null;
    return _AffineMotion(coefficientsX, coefficientsY);
  }

  static List<double> _residuals(
    List<HCVPlanarFlowSample> samples,
    _AffineMotion model,
  ) {
    return samples.map((sample) {
      final predictedX = model.x[0] + model.x[1] * sample.x + model.x[2] * sample.y;
      final predictedY = model.y[0] + model.y[1] * sample.x + model.y[2] * sample.y;
      final errorX = sample.dx - predictedX;
      final errorY = sample.dy - predictedY;
      return sqrt(errorX * errorX + errorY * errorY);
    }).toList();
  }

  static List<double>? _solve3x3(
    List<List<double>> matrix,
    List<double> target,
  ) {
    final augmented = List<List<double>>.generate(
      3,
      (row) => <double>[...matrix[row], target[row]],
    );

    for (var column = 0; column < 3; column++) {
      var pivot = column;
      for (var row = column + 1; row < 3; row++) {
        if (augmented[row][column].abs() >
            augmented[pivot][column].abs()) {
          pivot = row;
        }
      }
      if (augmented[pivot][column].abs() < 0.0000001) return null;
      if (pivot != column) {
        final swap = augmented[column];
        augmented[column] = augmented[pivot];
        augmented[pivot] = swap;
      }

      final divisor = augmented[column][column];
      for (var item = column; item < 4; item++) {
        augmented[column][item] /= divisor;
      }
      for (var row = 0; row < 3; row++) {
        if (row == column) continue;
        final factor = augmented[row][column];
        for (var item = column; item < 4; item++) {
          augmented[row][item] -= factor * augmented[column][item];
        }
      }
    }

    return <double>[
      augmented[0][3],
      augmented[1][3],
      augmented[2][3],
    ];
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  static double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final position =
        (sorted.length - 1) * percentile.clamp(0.0, 1.0).toDouble();
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final weight = position - lower;
    return sorted[lower] * (1.0 - weight) + sorted[upper] * weight;
  }
}

class _AffineMotion {
  const _AffineMotion(this.x, this.y);

  final List<double> x;
  final List<double> y;
}
