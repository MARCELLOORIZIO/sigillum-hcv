class HCVSceneContextEvidence {
  const HCVSceneContextEvidence({
    required this.contextClass,
    required this.analysisStatus,
    required this.positiveRealityEvidence,
    required this.reasons,
  });

  static const String displayDominant = 'DISPLAY_DOMINANT';
  static const String displayEmbeddedInReality =
      'DISPLAY_EMBEDDED_IN_REALITY';
  static const String sceneContextUnknown = 'SCENE_CONTEXT_UNKNOWN';

  final String contextClass;
  final String analysisStatus;
  final bool positiveRealityEvidence;
  final List<String> reasons;

  bool get isDisplayEmbeddedInReality =>
      contextClass == displayEmbeddedInReality && positiveRealityEvidence;

  bool get isDisplayDominant => contextClass == displayDominant;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'SIGILLUM_SCENE_CONTEXT_EVIDENCE_V1',
        'contextClass': contextClass,
        'analysisStatus': analysisStatus,
        'positiveRealityEvidence': positiveRealityEvidence,
        'reasons': reasons,
      };

  static HCVSceneContextEvidence unknown([String? reason]) =>
      HCVSceneContextEvidence(
        contextClass: sceneContextUnknown,
        analysisStatus: 'INDETERMINATE',
        positiveRealityEvidence: false,
        reasons: <String>[
          if (reason != null && reason.isNotEmpty) reason,
          'SCENE_CONTEXT_NOT_POSITIVELY_ESTABLISHED',
        ],
      );

  /// Converts only positive multi-depth geometry into scene-context reality.
  ///
  /// PLANAR is deliberately not mapped to DISPLAY_DOMINANT because paper,
  /// artwork, walls and physical screens can all be planar. UNKNOWN remains
  /// UNKNOWN. This keeps geometry as a positive-context sensor rather than an
  /// absence-of-display shortcut.
  static HCVSceneContextEvidence confirmedDominant({
    required List<String> reasons,
  }) =>
      HCVSceneContextEvidence(
        contextClass: displayDominant,
        analysisStatus: 'ANALYZED',
        positiveRealityEvidence: false,
        reasons: <String>[
          ...reasons,
          'DISPLAY_DOMINANT_CONTEXT_CORROBORATED',
        ],
      );

  static HCVSceneContextEvidence confirmedEmbedded({
    required List<String> reasons,
  }) =>
      HCVSceneContextEvidence(
        contextClass: displayEmbeddedInReality,
        analysisStatus: 'ANALYZED',
        positiveRealityEvidence: true,
        reasons: <String>[
          ...reasons,
          'DISPLAY_EMBEDDED_CONTEXT_CORROBORATED',
        ],
      );

  static HCVSceneContextEvidence fromGeometry(
    Map<String, dynamic>? geometry,
  ) {
    if (geometry == null) {
      return unknown('GEOMETRY_MISSING');
    }
    final sceneClass = geometry['sceneClass']?.toString() ?? 'UNKNOWN';
    final realityEvidence = geometry['realityEvidence'] == true;
    if (sceneClass == 'REALITY' && realityEvidence) {
      // Geometry is positive context evidence, but historical physical tests
      // showed that geometry alone can occasionally label a real display as
      // REALITY. Keep it as a candidate until an independent context family
      // corroborates that the display is embedded in the physical scene.
      return const HCVSceneContextEvidence(
        contextClass: sceneContextUnknown,
        analysisStatus: 'ANALYZED',
        positiveRealityEvidence: true,
        reasons: <String>[
          'POSITIVE_MULTI_DEPTH_SCENE_GEOMETRY',
          'GEOMETRY_REQUIRES_INDEPENDENT_CONTEXT_CORROBORATION',
        ],
      );
    }
    if (sceneClass == 'PLANAR') {
      return const HCVSceneContextEvidence(
        contextClass: sceneContextUnknown,
        analysisStatus: 'ANALYZED',
        positiveRealityEvidence: false,
        reasons: <String>[
          'PLANAR_GEOMETRY_IS_NOT_DISPLAY_DOMINANCE_PROOF',
          'SCENE_CONTEXT_NOT_POSITIVELY_ESTABLISHED',
        ],
      );
    }
    return unknown('GEOMETRY_CONTEXT_AMBIGUOUS');
  }
}
