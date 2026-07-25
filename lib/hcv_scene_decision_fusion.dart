import 'dart:math';

import 'hcv_active_display_classifier.dart';
import 'hcv_scene_geometry_classifier.dart';

class HCVSceneDecision {
  const HCVSceneDecision({
    required this.decision,
    required this.risk,
    required this.score,
    required this.displayProbability,
    required this.sceneClass,
    required this.displayEvidence,
    required this.realityEvidence,
    required this.indeterminate,
    required this.reasons,
  });

  final String decision;
  final String risk;
  final int score;
  final double displayProbability;
  final String sceneClass;
  final bool displayEvidence;
  final bool realityEvidence;
  final bool indeterminate;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
        'decision': decision,
        'risk': risk,
        'score': score,
        'displayProbability': double.parse(
          displayProbability.clamp(0.0, 1.0).toStringAsFixed(4),
        ),
        'sceneClass': sceneClass,
        'displayEvidence': displayEvidence,
        'realityEvidence': realityEvidence,
        'indeterminate': indeterminate,
        'reasons': reasons,
      };
}

class HCVSceneDecisionFusion {
  const HCVSceneDecisionFusion._();

  static HCVSceneDecision fuse({
    required HCVActiveDisplayClassification illumination,
    required HCVSceneGeometryClassification geometry,
  }) {
    final rawDisplayEvidence = illumination.reasons.contains(
      'EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH',
    );
    final flashRealityEvidence = illumination.reasons.contains(
      'DIFFUSE_REFLECTED_SCENE_RESPONSE',
    );
    final strongGeometryReality = geometry.realityEvidence &&
        geometry.flowReliability >= 0.58 &&
        geometry.depthDispersion >= 0.34;

    var decision = illumination.decision;
    var risk = illumination.risk;
    var score = illumination.score;
    var probability = illumination.displayProbability;
    final reasons = <String>[
      ...illumination.reasons,
      ...geometry.reasons,
    ];

    if (strongGeometryReality) {
      decision = 'NO_DISPLAY_EVIDENCE';
      risk = 'LOW';
      score = 20;
      probability = min(illumination.displayProbability, 0.25).toDouble();
      reasons.add('GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS');
    } else if (geometry.realityEvidence && rawDisplayEvidence) {
      decision = 'NON_CONCLUSIVE';
      risk = 'MEDIUM';
      score = 45;
      reasons.add('ILLUMINATION_AND_GEOMETRY_EVIDENCE_CONFLICT');
    } else if (geometry.planarEvidence && rawDisplayEvidence) {
      decision = 'NON_CONCLUSIVE';
      risk = 'MEDIUM';
      score = max(45, illumination.score).toInt();
      probability = max(illumination.displayProbability, 0.55).toDouble();
      reasons.add('PLANAR_GEOMETRY_CORROBORATES_DISPLAY_HYPOTHESIS');
    }

    final realityEvidence = flashRealityEvidence || strongGeometryReality;
    final displayEvidence = rawDisplayEvidence && !strongGeometryReality;
    final indeterminate = decision == 'NON_CONCLUSIVE' &&
        !displayEvidence &&
        !realityEvidence;
    final sceneClass = realityEvidence && !displayEvidence
        ? 'REALITY'
        : geometry.planarEvidence && displayEvidence
            ? 'DISPLAY_SUSPECTED'
            : 'UNKNOWN';

    return HCVSceneDecision(
      decision: decision,
      risk: risk,
      score: score,
      displayProbability: probability,
      sceneClass: sceneClass,
      displayEvidence: displayEvidence,
      realityEvidence: realityEvidence,
      indeterminate: indeterminate,
      reasons: reasons,
    );
  }
}
