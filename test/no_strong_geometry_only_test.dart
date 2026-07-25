import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('geometry cannot create a strong display verdict by itself', () {
    const illumination = HCVActiveDisplayClassification(
      decision: 'NO_DISPLAY_EVIDENCE',
      risk: 'LOW',
      score: 20,
      displayProbability: 0.20,
      illuminationResponseScore: 0.60,
      emissiveIndependenceScore: 0.40,
      electronicCueScore: 0.30,
      reasons: <String>[],
    );
    const geometry = HCVSceneGeometryClassification(
      sceneClass: 'PLANAR',
      realityEvidence: false,
      planarEvidence: true,
      motionMagnitude: 0.50,
      flowReliability: 0.90,
      directionCoherence: 0.95,
      depthDispersion: 0.03,
      planarCoherence: 0.88,
      matchedRegions: 12,
      reasons: <String>[],
    );

    final decision = HCVSceneDecisionFusion.fuse(
      illumination: illumination,
      geometry: geometry,
    );

    expect(decision.decision, isNot('STRONG_DISPLAY_RISK'));
    expect(decision.displayEvidence, isFalse);
  });
}
