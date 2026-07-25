import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('scene geometry exposes only stable scene values', () {
    final reality = HCVSceneGeometryClassifier.classify(
      motionMagnitude: 0.4,
      flowReliability: 0.7,
      directionCoherence: 0.6,
      depthDispersion: 0.4,
      planarCoherence: 0.2,
      matchedRegions: 8,
    );
    expect(<String>{'REALITY', 'PLANAR', 'UNKNOWN'}, contains(reality.sceneClass));
  });
}
