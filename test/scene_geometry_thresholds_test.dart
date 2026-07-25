import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('borderline geometry remains unresolved', () {
    final result = HCVSceneGeometryClassifier.classify(
      motionMagnitude: 0.15,
      flowReliability: 0.45,
      directionCoherence: 0.70,
      depthDispersion: 0.27,
      planarCoherence: 0.69,
      matchedRegions: 4,
    );

    expect(result.sceneClass, 'UNKNOWN');
    expect(result.realityEvidence, isFalse);
    expect(result.planarEvidence, isFalse);
  });
}
