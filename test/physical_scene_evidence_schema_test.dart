import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('geometry evidence serializes stable fields', () {
    const result = HCVSceneGeometryClassification(
      sceneClass: 'REALITY',
      realityEvidence: true,
      planarEvidence: false,
      motionMagnitude: 0.4,
      flowReliability: 0.7,
      directionCoherence: 0.6,
      depthDispersion: 0.4,
      planarCoherence: 0.2,
      matchedRegions: 8,
      reasons: <String>['MULTI_DEPTH_PARALLAX_DETECTED'],
    );

    final json = result.toJson();
    expect(json['sceneClass'], 'REALITY');
    expect(json['realityEvidence'], isTrue);
    expect(json['planarEvidence'], isFalse);
    expect(json['matchedRegions'], 8);
  });
}
