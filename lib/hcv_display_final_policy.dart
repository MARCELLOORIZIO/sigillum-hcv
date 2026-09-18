import 'dart:math';

import 'hcv_display_risk_fusion.dart';
import 'hcv_scene_context_evidence.dart';

/// Final SIGILLUM policy. Display-physics evidence and scene context are kept
/// separate until this single decision point.
class HCVDisplayFinalPolicy {
  const HCVDisplayFinalPolicy._();

  static HCVDisplayRiskResult resolve({
    required HCVDisplayRiskResult displayPhysics,
    required HCVSceneContextResult sceneContext,
  }) {
    if (sceneContext.isEmbeddedInReality) {
      return HCVDisplayRiskResult(
        risk: 'LOW',
        score: min(displayPhysics.score, 20),
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: displayPhysics.evidenceSources,
        strongSources: displayPhysics.strongSources,
        reasons: <String>[
          ...displayPhysics.reasons,
          ...sceneContext.reasons,
          'DISPLAY_PHYSICS_SEPARATED_FROM_SCENE_CONTEXT',
          'DISPLAY_EMBEDDED_IN_REALITY_FINAL_POLICY',
        ],
      );
    }

    if (sceneContext.isDisplayDominant) {
      if (displayPhysics.decision == 'STRONG_DISPLAY_RISK') {
        return HCVDisplayRiskResult(
          risk: displayPhysics.risk,
          score: displayPhysics.score,
          decision: displayPhysics.decision,
          analysisStatus: displayPhysics.analysisStatus,
          evidenceSources: displayPhysics.evidenceSources,
          strongSources: displayPhysics.strongSources,
          reasons: <String>[
            ...displayPhysics.reasons,
            ...sceneContext.reasons,
            'DISPLAY_DOMINANT_FINAL_POLICY',
          ],
        );
      }
      return HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: max(displayPhysics.score, 45),
        decision: 'NON_CONCLUSIVE',
        analysisStatus: 'COMPLETE',
        evidenceSources: displayPhysics.evidenceSources,
        strongSources: displayPhysics.strongSources,
        reasons: <String>[
          ...displayPhysics.reasons,
          ...sceneContext.reasons,
          'DISPLAY_DOMINANT_WITHOUT_STRONG_DISPLAY_PHYSICS',
        ],
      );
    }

    // UNKNOWN is deliberately neutral: it can never create REALITY.
    return displayPhysics;
  }
}
