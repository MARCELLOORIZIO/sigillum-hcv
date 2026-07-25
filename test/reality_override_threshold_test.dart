import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('reality override requires stronger than minimum geometry', () {
    final borderline = HCVSceneGeometryClassifier.classify(
      motionMagnitude: 0.20,
      flowReliability: 0.50,
      directionCoherence: 0.45,
      depthDispersion: 0.30,
      planarCoherence: 0.60,
      matchedRegions: 5,
    );
    expect(borderline.realityEvidence, isTrue);
    expect(borderline.flowReliability, lessThan(0.58));
    expect(borderline.depthDispersion, lessThan(0.34));
  });
}
