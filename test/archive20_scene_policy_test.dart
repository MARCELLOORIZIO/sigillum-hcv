import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('archive 20 reality-like electronic cues need geometry resolution', () {
    const illumination = HCVActiveDisplayClassification(
      decision: 'NON_CONCLUSIVE',
      risk: 'MEDIUM',
      score: 45,
      displayProbability: 0.62,
      illuminationResponseScore: 0.44,
      emissiveIndependenceScore: 0.56,
      electronicCueScore: 0.60,
      reasons: <String>[
        'EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH',
        'ELECTRONIC_DISPLAY_CUES_PRESENT',
        'TORCH_RESPONSE_CONCENTRATED_AS_GLARE',
      ],
    );

    const geometry = HCVSceneGeometryClassification(
      sceneClass: 'REALITY',
      realityEvidence: true,
      planarEvidence: false,
      motionMagnitude: 0.45,
      flowReliability: 0.75,
      directionCoherence: 0.62,
      depthDispersion: 0.45,
      planarCoherence: 0.26,
      matchedRegions: 9,
      reasons: <String>[
        'MULTI_DEPTH_PARALLAX_DETECTED',
      ],
    );

    final decision = HCVSceneDecisionFusion.fuse(
      illumination: illumination,
      geometry: geometry,
    );

    expect(decision.sceneClass, 'REALITY');
    expect(decision.decision, 'NO_DISPLAY_EVIDENCE');
    expect(decision.displayEvidence, isFalse);
    expect(decision.realityEvidence, isTrue);
  });
}
