import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('monitor-like illumination plus planarity remains cautious', () {
    const illumination = HCVActiveDisplayClassification(
      decision: 'NON_CONCLUSIVE',
      risk: 'MEDIUM',
      score: 45,
      displayProbability: 0.68,
      illuminationResponseScore: 0.42,
      emissiveIndependenceScore: 0.58,
      electronicCueScore: 0.66,
      reasons: <String>[
        'EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH',
        'ELECTRONIC_DISPLAY_CUES_PRESENT',
      ],
    );

    const geometry = HCVSceneGeometryClassification(
      sceneClass: 'PLANAR',
      realityEvidence: false,
      planarEvidence: true,
      motionMagnitude: 0.39,
      flowReliability: 0.83,
      directionCoherence: 0.93,
      depthDispersion: 0.08,
      planarCoherence: 0.80,
      matchedRegions: 10,
      reasons: <String>[
        'COHERENT_PLANAR_MOTION_DETECTED',
      ],
    );

    final decision = HCVSceneDecisionFusion.fuse(
      illumination: illumination,
      geometry: geometry,
    );

    expect(decision.decision, 'NON_CONCLUSIVE');
    expect(decision.score, 45);
    expect(decision.sceneClass, 'DISPLAY_SUSPECTED');
    expect(decision.displayEvidence, isTrue);
  });
}
