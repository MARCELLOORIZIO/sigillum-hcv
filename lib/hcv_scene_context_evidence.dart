class HCVSceneContextEvidence {
  const HCVSceneContextEvidence({
    required this.sceneClass,
    required this.positiveRealityContext,
    required this.planarOnly,
    required this.analysisStatus,
    required this.reasons,
  });

  static const String type = 'SIGILLUM_SCENE_CONTEXT_EVIDENCE_V1';

  final String sceneClass;
  final bool positiveRealityContext;
  final bool planarOnly;
  final String analysisStatus;
  final List<String> reasons;

  factory HCVSceneContextEvidence.unknown([String reason = 'SCENE_CONTEXT_UNKNOWN']) {
    return HCVSceneContextEvidence(
      sceneClass: 'SCENE_CONTEXT_UNKNOWN',
      positiveRealityContext: false,
      planarOnly: false,
      analysisStatus: 'NOT_ANALYZED',
      reasons: <String>[reason],
    );
  }

  factory HCVSceneContextEvidence.fromLiveProbe(Map<String, dynamic>? probe) {
    if (probe == null || probe['analysisStatus'] != 'ANALYZED') {
      return HCVSceneContextEvidence.unknown('LIVE_GEOMETRY_NOT_AVAILABLE');
    }

    final rawSignals = probe['signals'];
    final signals = rawSignals is Map
        ? Map<String, dynamic>.from(rawSignals)
        : const <String, dynamic>{};
    final rawGeometry = probe['geometryChallenge'];
    final geometry = rawGeometry is Map
        ? Map<String, dynamic>.from(rawGeometry)
        : const <String, dynamic>{};

    final geometricReality = signals['geometricRealityEvidence'] == true ||
        geometry['realityEvidence'] == true ||
        geometry['sceneClass'] == 'REALITY';
    final planar = signals['planarSceneEvidence'] == true ||
        geometry['planarEvidence'] == true ||
        geometry['sceneClass'] == 'PLANAR';

    if (geometricReality) {
      return const HCVSceneContextEvidence(
        sceneClass: 'REAL_SCENE_3D',
        positiveRealityContext: true,
        planarOnly: false,
        analysisStatus: 'ANALYZED',
        reasons: <String>[
          'POSITIVE_GEOMETRIC_REALITY_CONTEXT',
          'MULTI_DEPTH_OR_NON_PLANAR_MOTION_EVIDENCE',
        ],
      );
    }

    if (planar) {
      return const HCVSceneContextEvidence(
        sceneClass: 'PLANAR_SCENE',
        positiveRealityContext: false,
        planarOnly: true,
        analysisStatus: 'ANALYZED',
        reasons: <String>[
          'PLANARITY_IS_CONTEXT_ONLY',
          'PLANARITY_IS_NOT_DISPLAY_PROOF',
          'PLANARITY_IS_NOT_POSITIVE_REALITY_PROOF',
        ],
      );
    }

    return const HCVSceneContextEvidence(
      sceneClass: 'SCENE_CONTEXT_UNKNOWN',
      positiveRealityContext: false,
      planarOnly: false,
      analysisStatus: 'ANALYZED',
      reasons: <String>['GEOMETRY_ANALYZED_BUT_CONTEXT_UNRESOLVED'],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'analysisStatus': analysisStatus,
        'sceneClass': sceneClass,
        'positiveRealityContext': positiveRealityContext,
        'planarOnly': planarOnly,
        'reasons': reasons,
      };
}
