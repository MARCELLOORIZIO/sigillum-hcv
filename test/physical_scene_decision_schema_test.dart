import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';

void main() {
  test('scene decision schema exposes class and evidence flags', () {
    const result = HCVSceneDecision(
      decision: 'NO_DISPLAY_EVIDENCE',
      risk: 'LOW',
      score: 20,
      displayProbability: 0.2,
      sceneClass: 'REALITY',
      displayEvidence: false,
      realityEvidence: true,
      indeterminate: false,
      reasons: <String>[],
    );

    final json = result.toJson();
    expect(json['sceneClass'], 'REALITY');
    expect(json['displayEvidence'], isFalse);
    expect(json['realityEvidence'], isTrue);
  });
}
