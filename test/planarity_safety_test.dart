import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('a wall, paper or painting cannot be labelled display from planarity', () {
    const illumination = HCVActiveDisplayClassification(
      decision: 'NO_DISPLAY_EVIDENCE',
      risk: 'LOW',
      score: 20,
      displayProbability: 0.15,
      illuminationResponseScore: 0.70,
      emissiveIndependenceScore: 0.30,
      electronicCueScore: 0.20,
      reasons: <String>[
        'DIFFUSE_REFLECTED_SCENE_RESPONSE',
        'LOW_ELECTRONIC_DISPLAY_STRUCTURE',
      ],
    );

    const geometry = HCVSceneGeometryClassification(
      sceneClass: 'PLANAR',
      realityEvidence: false,
      planarEvidence: true,
      motionMagnitude: 0.40,
      flowReliability: 0.82,
      directionCoherence: 0.92,
      depthDispersion: 0.07,
      planarCoherence: 0.82,
      matchedRegions: 10,
      reasons: <String>[
        'COHERENT_PLANAR_MOTION_DETECTED',
        'PLANARITY_IS_CORROBORATION_ONLY',
      ],
    );

    final decision = HCVSceneDecisionFusion.fuse(
      illumination: illumination,
      geometry: geometry,
    );

    expect(decision.decision, 'NO_DISPLAY_EVIDENCE');
    expect(decision.displayEvidence, isFalse);
    expect(decision.sceneClass, 'UNKNOWN');
  });
}
