/// Orthogonal PHOTO framing report. Never overrides provenance, integrity,
/// or the established physical recapture-risk decision.
///
/// A visible monitor is a physical object, not proof of full-frame recapture.
/// Conversely, a frame-filling screen-like image is only a suspicion until
/// independent physical capture evidence corroborates it.
class HCVPhotoObjectFramingPolicy {
  const HCVPhotoObjectFramingPolicy._();

  static const objectInScene = 'SCENE_WITH_IDENTIFIABLE_DISPLAY_OBJECT';
  static const possibleFullFrame = 'POSSIBLE_DECEPTIVE_FULL_FRAME_DISPLAY';
  static const physicalScene = 'PHYSICAL_SURFACE_OR_SCENE';
  static const unresolved = 'UNDETERMINED';

  static Map<String, dynamic> evaluate({
    required Map<String, dynamic>? semanticPhoto,
    required Map<String, dynamic>? photoFramingEvidence,
    required Map<String, dynamic>? legacyDisplayRisk,
  }) {
    final semanticAnalyzed = semanticPhoto != null &&
        semanticPhoto['analysisStatus'] == 'ANALYZED' &&
        semanticPhoto['decisionRole'] == 'DIAGNOSTIC_ONLY';
    final predicted = semanticAnalyzed
        ? semanticPhoto['predictedClass']?.toString()
        : null;
    final embeddedCorroborated = photoFramingEvidence != null &&
        photoFramingEvidence['analysisStatus'] == 'ANALYZED' &&
        photoFramingEvidence['sceneFraming'] == 'DISPLAY_IN_REAL_SCENE' &&
        photoFramingEvidence['positiveEmbeddedRealityEvidence'] == true;
    final priorDecision = legacyDisplayRisk?['decision']?.toString();
    final strongLegacy = priorDecision == 'STRONG_DISPLAY_RISK';

    String framing = unresolved;
    String reason = 'FRAMING_EVIDENCE_INSUFFICIENT';
    if (embeddedCorroborated &&
        predicted == 'POSSIBLE_FULL_FRAME_DISPLAY') {
      reason = 'EMBEDDED_GEOMETRY_CONFLICTS_WITH_SEMANTIC_FULL_FRAME';
    } else if (embeddedCorroborated && !strongLegacy) {
      framing = objectInScene;
      reason = 'INDEPENDENT_EMBEDDED_REAL_SCENE_GEOMETRY';
    } else if (embeddedCorroborated && strongLegacy) {
      reason = 'EMBEDDED_GEOMETRY_CONFLICTS_WITH_PHYSICAL_DISPLAY_RISK';
    } else if (predicted == 'POSSIBLE_FULL_FRAME_DISPLAY') {
      framing = possibleFullFrame;
      reason = 'SEMANTIC_FULL_FRAME_APPEARANCE_ONLY';
    } else if (predicted == 'PHYSICAL_SURFACE_OR_SCENE' &&
        !strongLegacy) {
      framing = physicalScene;
      reason = 'SEMANTIC_PHYSICAL_SCENE_ONLY';
    } else if (predicted == 'DISPLAY_IN_REAL_SCENE') {
      // The model sees a display, not necessarily a recognizable device.
      // Do not infer the bezel, stand or independent scene geometry.
      reason = 'SEMANTIC_DISPLAY_WITHOUT_VERIFIED_OBJECT_FRAMING';
    }
    return <String, dynamic>{
      'type': 'SIGILLUM_PHOTO_OBJECT_FRAMING_V1',
      'analysisStatus': semanticAnalyzed || embeddedCorroborated
          ? 'ANALYZED'
          : 'NOT_DETERMINED',
      'decisionRole': 'DIAGNOSTIC_ONLY',
      'framing': framing,
      'reason': reason,
      'screenObjectVisible': embeddedCorroborated ? true : null,
      'physicalRecaptureProven': false,
      'legacyDisplayRiskDecisionUnchanged': priorDecision,
      'semanticPhotoModelSha256': semanticPhoto?['modelSha256'],
    };
  }
}
