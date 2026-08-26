import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_projective_motion_model.dart';

HCVProjectiveFlowSample sampleFromTransform(
  double x,
  double y, {
  double extraDx = 0,
  double extraDy = 0,
}) {
  const xScale = 16.0;
  const yScale = 12.0;
  final denominator = 1.0 + 0.055 * x - 0.025 * y;
  final targetX =
      (1.025 * x + 0.018 * y + 0.095) / denominator + extraDx / xScale;
  final targetY =
      (-0.012 * x + 1.015 * y + 0.025) / denominator + extraDy / yScale;
  return HCVProjectiveFlowSample(
    x: x,
    y: y,
    targetX: targetX,
    targetY: targetY,
    dx: (targetX - x) * xScale,
    dy: (targetY - y) * yScale,
    quality: 0.92,
    boundaryHit: false,
  );
}

List<HCVProjectiveFlowSample> gridSamples({
  bool splitDepth = false,
  bool dynamicOutliers = false,
}) {
  final samples = <HCVProjectiveFlowSample>[];
  for (var row = 0; row < 4; row++) {
    for (var column = 0; column < 5; column++) {
      final x = -0.8 + column * 0.4;
      final y = -0.75 + row * 0.5;
      final index = row * 5 + column;
      final split = splitDepth && column >= 3;
      final outlier = dynamicOutliers && <int>{2, 7, 12, 17}.contains(index);
      samples.add(
        sampleFromTransform(
          x,
          y,
          extraDx: split
              ? 1.8
              : outlier
              ? sin(index.toDouble()) * 2.1
              : 0,
          extraDy: split
              ? -0.9
              : outlier
              ? cos(index.toDouble()) * 1.7
              : 0,
        ),
      );
    }
  }
  return samples;
}

void main() {
  test('projective monitor plane remains planar from another angle', () {
    final fit = HCVProjectiveMotionModel.fit(
      gridSamples(),
      maxShift: 6,
      expectedRegions: 20,
      xScale: 16,
      yScale: 12,
    );

    expect(fit.matchedRegions, 20);
    expect(fit.dominantPlaneRatio, greaterThan(0.9));
    expect(fit.depthDispersion, lessThan(0.24));
    expect(fit.planarCoherence, greaterThan(0.58));
  });

  test('independent depth layer is not accepted as one plane', () {
    final fit = HCVProjectiveMotionModel.fit(
      gridSamples(splitDepth: true),
      maxShift: 6,
      expectedRegions: 20,
      xScale: 16,
      yScale: 12,
    );

    expect(fit.depthDispersion >= 0.28 || fit.planarCoherence < 0.58, isTrue);
  });

  test('a few changing monitor regions remain projective outliers', () {
    final fit = HCVProjectiveMotionModel.fit(
      gridSamples(dynamicOutliers: true),
      maxShift: 6,
      expectedRegions: 20,
      xScale: 16,
      yScale: 12,
    );

    expect(fit.dominantPlaneRatio, greaterThanOrEqualTo(0.75));
    expect(fit.planarCoherence, greaterThan(0.50));
  });
}
