class HCVSceneContextResult {
  const HCVSceneContextResult({
    required this.context,
    required this.reasons,
  });

  static const String displayEmbeddedInReality = 'DISPLAY_EMBEDDED_IN_REALITY';
  static const String displayDominant = 'DISPLAY_DOMINANT';
  static const String unknown = 'SCENE_CONTEXT_UNKNOWN';

  final String context;
  final List<String> reasons;

  bool get isEmbeddedInReality => context == displayEmbeddedInReality;
  bool get isDisplayDominant => context == displayDominant;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'context': context,
        'reasons': reasons,
      };
}

/// Scene-context evidence is intentionally independent from display physics.
///
/// It must never infer REALITY from a missing/negative display signal. Only
/// positive geometric/physical reality evidence may classify a display as
/// embedded in a wider real scene. DISPLAY_DOMINANT is deliberately left
/// UNKNOWN until a validated dominance sensor exists.
class HCVSceneContextEvidence {
  const HCVSceneContextEvidence._();

  static HCVSceneContextResult assess({
    Map<String, dynamic>? liveScreenProbe,
    Map<String, dynamic>? temporalFrequencyProbe,
  }) {
    final reasons = <String>[];

    final geometryRaw = liveScreenProbe?['geometryChallenge'];
    final geometry = geometryRaw is Map
        ? Map<String, dynamic>.from(geometryRaw)
        : const <String, dynamic>{};
    final geometrySceneClass = geometry['sceneClass']?.toString() ??
        liveScreenProbe?['sceneClass']?.toString() ??
        'UNKNOWN';
    final geometryReality =
        geometry['realityEvidence'] == true || geometrySceneClass == 'REALITY';

    final liveReason = liveScreenProbe?['reason']?.toString() ?? '';
    final signedGeometricReality = geometryReality &&
        (geometry['realityEvidence'] == true ||
            liveReason.contains('MULTI_DEPTH_PARALLAX_DETECTED') ||
            liveReason.contains('NON_PLANAR_CAMERA_MOTION_RESPONSE') ||
            liveReason.contains(
              'GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS',
            ));

    if (signedGeometricReality) {
      reasons.add('POSITIVE_GEOMETRIC_REALITY_CONTEXT');
    }

    final v3Raw = temporalFrequencyProbe?['displayRealityEvidenceV3'];
    final v3 = v3Raw is Map
        ? Map<String, dynamic>.from(v3Raw)
        : const <String, dynamic>{};
    final positivePhysicalReality =
        v3['positivePhysicalRealityEvidence'] == true &&
            v3['fullFrameReality'] == true;
    if (positivePhysicalReality) {
      reasons.add('POSITIVE_PHYSICAL_REALITY_CONTEXT');
    }

    if (signedGeometricReality || positivePhysicalReality) {
      return HCVSceneContextResult(
        context: HCVSceneContextResult.displayEmbeddedInReality,
        reasons: reasons,
      );
    }

    // mixedSceneDetected, realityLikeCellCount, negative HFR, ML REALITY and
    // optical silence are intentionally NOT scene-context evidence.
    return const HCVSceneContextResult(
      context: HCVSceneContextResult.unknown,
      reasons: <String>['NO_POSITIVE_SCENE_CONTEXT_EVIDENCE'],
    );
  }
}
