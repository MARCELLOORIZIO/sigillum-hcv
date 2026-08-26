import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_planar_motion_model.dart';

void main() {
  test('perspective change on one plane remains planar', () {
    final samples = <HCVPlanarFlowSample>[];
    for (var row = 0; row < 4; row++) {
      final y = -1.0 + row * (2.0 / 3.0);
      for (var column = 0; column < 5; column++) {
        final x = -1.0 + column * 0.5;
        samples.add(
          HCVPlanarFlowSample(
            x: x,
            y: y,
            dx: 2.0 + 0.35 * x + 0.15 * y,
            dy: 0.4 - 0.10 * x + 0.20 * y,
            quality: 0.90,
            boundaryHit: false,
          ),
        );
      }
    }

    final result = HCVPlanarMotionModel.fit(
      samples,
      maxShift: 5,
      expectedRegions: 20,
    );
    expect(result.motionMagnitude, greaterThan(0.16));
    expect(result.flowReliability, greaterThan(0.70));
    expect(result.depthDispersion, lessThan(0.20));
    expect(result.planarCoherence, greaterThan(0.58));
  });

  test('independent depth layers remain non-planar', () {
    final samples = <HCVPlanarFlowSample>[];
    for (var row = 0; row < 4; row++) {
      final y = -1.0 + row * (2.0 / 3.0);
      for (var column = 0; column < 5; column++) {
        final x = -1.0 + column * 0.5;
        final dx = column == 0 || column == 4
            ? 3.30
            : column == 1 || column == 3
            ? 1.60
            : 2.20;
        samples.add(
          HCVPlanarFlowSample(
            x: x,
            y: y,
            dx: dx,
            dy: 0.30 + 0.10 * y,
            quality: 0.90,
            boundaryHit: false,
          ),
        );
      }
    }

    final result = HCVPlanarMotionModel.fit(
      samples,
      maxShift: 5,
      expectedRegions: 20,
    );
    expect(result.depthDispersion, greaterThan(0.28));
    expect(result.planarCoherence, lessThan(0.58));
  });
}
