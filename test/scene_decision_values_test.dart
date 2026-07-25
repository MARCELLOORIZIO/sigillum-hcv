import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';

void main() {
  test('physical scene decision uses stable external labels', () {
    const decision = HCVSceneDecision(
      decision: 'NON_CONCLUSIVE',
      risk: 'MEDIUM',
      score: 45,
      displayProbability: 0.5,
      sceneClass: 'DISPLAY_SUSPECTED',
      displayEvidence: true,
      realityEvidence: false,
      indeterminate: false,
      reasons: <String>[],
    );
    expect(<String>{'REALITY', 'DISPLAY_SUSPECTED', 'UNKNOWN'},
        contains(decision.sceneClass));
  });
}
