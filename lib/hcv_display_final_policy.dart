import 'dart:math';

import 'hcv_display_risk_fusion.dart';
import 'hcv_scene_context_evidence.dart';

/// Final SIGILLUM policy.
///
/// DISPLAY PHYSICS and SCENE CONTEXT remain independent until this single
/// decision point. UNKNOWN context is neutral and can never create REALITY.
class HCVDisplayFinalPolicy {
  const HCVDisplayFinalPolicy._();

  static HCVDisplayRiskResult resolve({
    required HCVDisplayRiskResult displayPhysics,
    required HCVSceneContextEvidence sceneContext,
  }) {
    if (sceneContext.isDisplayEmbeddedInReality) {
      final fullFramePhysicalDisplay =
          displayPhysics.strongSources.contains(
            'HFR_V3_FULL_FRAME_DISPLAY_PHYSICS',
          );
      if (fullFramePhysicalDisplay &&
          displayPhysics.decision == 'STRONG_DISPLAY_RISK') {
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
            'FULL_FRAME_DISPLAY_PHYSICS_VETOES_EMBEDDED_OVERRIDE_BUILD122',
          ],
        );
      }
      return HCVDisplayRiskResult(
        risk: 'LOW',
        score: min(displayPhysics.score, 20),
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: displayPhysics.evidenceSources,
        strongSources: displayPhysics.strongSources,
        reasons: <String>[
          ...displayPhysics.reasons.where(
            (reason) => reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED',
          ),
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

    return displayPhysics;
  }
}
