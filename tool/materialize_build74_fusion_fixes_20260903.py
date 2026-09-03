from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one target, found {count}: {old[:80]!r}")
    p.write_text(text.replace(old, new, 1))


fusion = 'lib/hcv_display_risk_fusion.dart'
camera = 'lib/camera_page.dart'

# ---------------------------------------------------------------------------
# PHOTO: use screen-family probability across the 2-frame pre-capture probe +
# still image, and relax dual-REALITY only when all temporal frames agree.
# ---------------------------------------------------------------------------
replace_once(
    fusion,
    """  static bool _isCredibleRealityMl(
    Map<String, dynamic>? ml, {
    required double maxScreenProbability,
    required double minConfidence,
  }) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    return predictedClass.startsWith('REALITY_') &&
        score <= 2 &&
        screenProbability <= maxScreenProbability &&
        confidence >= minConfidence;
  }
""",
    """  static bool _isCredibleRealityMl(
    Map<String, dynamic>? ml, {
    required int maxScore,
    required double maxScreenProbability,
    required double minConfidence,
  }) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    return predictedClass.startsWith('REALITY_') &&
        score <= maxScore &&
        screenProbability <= maxScreenProbability &&
        confidence >= minConfidence;
  }

  static bool _hasPhotoTemporalScreenFamilyAgreement(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (frames < 2 || rawFrames is! List || rawFrames.length != frames) {
      return false;
    }
    final allScreen = rawFrames.every(
      (frame) =>
          frame is Map &&
          (frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_'),
    );
    return allScreen &&
        strong >= 2 &&
        medium >= 2 &&
        average >= 95.0 &&
        screenProbability >= 0.97;
  }

  static bool _hasPhotoStillScreenFamilyAgreement(Map<String, dynamic>? ml) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final signals = _signals(ml);
    final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final contentArea =
        (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
    return predictedClass.startsWith('SCREEN_') &&
        frames == 1 &&
        score >= 95 &&
        screenProbability >= 0.95 &&
        fullFrame >= 95 &&
        contentArea >= 90;
  }

  static bool _hasPhotoTemporalRealityAgreement(Map<String, dynamic>? ml) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrame =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (frames < 2 || rawFrames is! List || rawFrames.length != frames) {
      return false;
    }
    final allReality = rawFrames.every(
      (frame) =>
          frame is Map &&
          (frame['predictedClass']?.toString() ?? '').startsWith('REALITY_'),
    );
    return predictedClass.startsWith('REALITY_') &&
        allReality &&
        strong == 0 &&
        medium == 0 &&
        average <= 12.0 &&
        maxFrame <= 15 &&
        screenProbability <= 0.12;
  }
""",
)

replace_once(
    fusion,
    """    final photoTemporalMl =
        liveCaptureOnly ? _embeddedPhotoTemporalMl(live) : null;
    final photoDualRealityAgreement = liveCaptureOnly &&
        _isCredibleRealityMl(
          postCaptureMl,
          maxScreenProbability: 0.02,
          minConfidence: 0.40,
        ) &&
        _isCredibleRealityMl(
          photoTemporalMl,
          maxScreenProbability: 0.02,
          minConfidence: 0.60,
        );
    if (liveCaptureOnly) {
      final videoEquivalent = _embeddedVideoEquivalentResult(live);
      if (videoEquivalent != null &&
          spatialPostCaptureMl == null &&
          !photoDualRealityAgreement) {
        return videoEquivalent;
      }
    }
""",
    """    final photoTemporalMl =
        liveCaptureOnly ? _embeddedPhotoTemporalMl(live) : null;
    final photoStrongScreenFamilyAgreement = liveCaptureOnly &&
        _hasPhotoTemporalScreenFamilyAgreement(photoTemporalMl) &&
        _hasPhotoStillScreenFamilyAgreement(postCaptureMl);
    final photoDualRealityAgreement = liveCaptureOnly &&
        _isCredibleRealityMl(
          postCaptureMl,
          maxScore: 12,
          maxScreenProbability: 0.12,
          minConfidence: 0.30,
        ) &&
        _hasPhotoTemporalRealityAgreement(photoTemporalMl);
    if (liveCaptureOnly) {
      final videoEquivalent = _embeddedVideoEquivalentResult(live);
      if (videoEquivalent != null &&
          spatialPostCaptureMl == null &&
          !photoDualRealityAgreement &&
          !photoStrongScreenFamilyAgreement) {
        return videoEquivalent;
      }
    }
""",
)

# ---------------------------------------------------------------------------
# VIDEO: add realistic-content SCREEN persistence (75% with high family
# probability), and semantic REALITY override for PLANAR temporal false alarms.
# ---------------------------------------------------------------------------
replace_once(
    fusion,
    """  static bool hasPersistentSemanticRealityAcrossVideoFrames(
    Map<String, dynamic>? ml,
  ) {
""",
    """  static bool hasRealisticContentScreenPersistence(
    Map<String, dynamic>? ml, {
    required bool reflectedRealityEvidence,
  }) {
    if (ml == null || reflectedRealityEvidence) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final maxFrame =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (frames < 4 || rawFrames is! List || rawFrames.length != frames) {
      return false;
    }
    final screenFrames = rawFrames
        .where(
          (frame) =>
              frame is Map &&
              (frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_'),
        )
        .length;
    return predictedClass.startsWith('SCREEN_') &&
        screenFrames * 4 >= frames * 3 &&
        strong >= 2 &&
        medium >= 2 &&
        average >= 60.0 &&
        maxFrame >= 96 &&
        screenProbability >= 0.97;
  }

  static bool hasPlanarSemanticRealityWithoutHardDisplayEvidence(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrame =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (frames < 4 || rawFrames is! List || rawFrames.length != frames) {
      return false;
    }
    final realityFrames = rawFrames
        .where(
          (frame) =>
              frame is Map &&
              (frame['predictedClass']?.toString() ?? '').startsWith('REALITY_'),
        )
        .length;
    return realityFrames * 2 >= frames &&
        strong == 0 &&
        medium == 0 &&
        average <= 35.0 &&
        maxFrame <= 75 &&
        screenProbability <= 0.75;
  }

  static bool hasPersistentSemanticRealityAcrossVideoFrames(
    Map<String, dynamic>? ml,
  ) {
""",
)

# Hard display traces are intentionally stricter than horizontal bands / moire.
replace_once(
    fusion,
    """    final activeChallengeIndeterminate =
        liveSignals['activeChallengeIndeterminate'] == true;
    final activeProbeNonConclusive = activeProbeVersion != null &&
""",
    """    final activeChallengeIndeterminate =
        liveSignals['activeChallengeIndeterminate'] == true;
    final hardLiveDisplayTrace =
        liveSignals['confirmedDisplayTrace'] == true ||
            liveSignals['periodicLightTrace'] == true ||
            liveSignals['strongRefreshTrace'] == true ||
            liveSignals['displayBandTrace'] == true ||
            liveSignals['opticalStripeTrace'] == true ||
            liveSignals['opticalCorroboratedTrace'] == true;
    final activeProbeNonConclusive = activeProbeVersion != null &&
""",
)

# Record strong PHOTO family agreement in the evidence ledger.
replace_once(
    fusion,
    """    final evidenceSources = <String>{};
    final strongSources = <String>{};
    final reasons = <String>[];

    final liveScore = (live?['screenReplayRiskScore'] as num?)?.toInt();
""",
    """    final evidenceSources = <String>{};
    final strongSources = <String>{};
    final reasons = <String>[];
    if (photoStrongScreenFamilyAgreement) {
      evidenceSources.add('ML_SCREEN_CLASS');
      strongSources.add('ML_SCREEN_CLASS');
      reasons.add('PHOTO_TEMPORAL_AND_STILL_SCREEN_FAMILY_CONFIRMED');
    }

    final liveScore = (live?['screenReplayRiskScore'] as num?)?.toInt();
""",
)

# Add the realistic-content SCREEN and planar-REALITY candidate signals.
replace_once(
    fusion,
    """    final mlSemanticScreenPersistenceV2 = hasSemanticScreenPersistenceV2(
      ml,
      geometrySceneClass: geometrySceneClass,
      reflectedRealityEvidence: reflectedRealityEvidence,
    );
    if (mlSemanticScreenPersistenceV2) {
      evidenceSources.add('ML_SCREEN_CLASS');
      strongSources.add('ML_SCREEN_CLASS');
    }
    final mlGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'REALITY' &&
        (mlPersistentCorroboratedEvidence || mlSemanticScreenPersistenceV2);
""",
    """    final mlSemanticScreenPersistenceV2 = hasSemanticScreenPersistenceV2(
      ml,
      geometrySceneClass: geometrySceneClass,
      reflectedRealityEvidence: reflectedRealityEvidence,
    );
    final mlRealisticContentScreenPersistence =
        hasRealisticContentScreenPersistence(
      ml,
      reflectedRealityEvidence: reflectedRealityEvidence,
    );
    final mlPlanarSemanticReality =
        hasPlanarSemanticRealityWithoutHardDisplayEvidence(ml);
    if (mlSemanticScreenPersistenceV2 || mlRealisticContentScreenPersistence) {
      evidenceSources.add('ML_SCREEN_CLASS');
      strongSources.add('ML_SCREEN_CLASS');
    }
    final mlGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'REALITY' &&
        (mlPersistentCorroboratedEvidence ||
            mlSemanticScreenPersistenceV2 ||
            mlRealisticContentScreenPersistence);
""",
)

replace_once(
    fusion,
    """            mlMultiFrameScreenConsistency ||
            mlSemanticScreenPersistence ||
            mlSemanticScreenPersistenceV2);
    final mlPlanarGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'PLANAR' &&
        (mlPersistentVideoEvidence ||
            mlMultiFrameScreenConsistency ||
            mlSemanticScreenPersistence ||
            mlSemanticScreenPersistenceV2);
""",
    """            mlMultiFrameScreenConsistency ||
            mlSemanticScreenPersistence ||
            mlSemanticScreenPersistenceV2 ||
            mlRealisticContentScreenPersistence);
    final mlPlanarGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'PLANAR' &&
        (mlPersistentVideoEvidence ||
            mlMultiFrameScreenConsistency ||
            mlSemanticScreenPersistence ||
            mlSemanticScreenPersistenceV2 ||
            mlRealisticContentScreenPersistence);
""",
)

# A PLANAR scene may resolve to REALITY only when there is no hard/active/static
# display evidence; horizontal bands or moire alone are not hard evidence.
replace_once(
    fusion,
    """    final geometryRealityWithIndependentNonDisplay =
        geometrySceneClass == 'REALITY' &&
            weakScreenAcrossVideoFrames &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate;

    final strongDisplayFamilies = <String>{};
""",
    """    final geometryRealityWithIndependentNonDisplay =
        geometrySceneClass == 'REALITY' &&
            weakScreenAcrossVideoFrames &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate;
    final planarSemanticRealityWithoutHardDisplayEvidence =
        !liveCaptureOnly &&
            geometrySceneClass == 'PLANAR' &&
            mlPlanarSemanticReality &&
            !rawActiveDisplayEvidence &&
            !activeDisplayEvidence &&
            !hardLiveDisplayTrace &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate &&
            !mlStrong;

    final strongDisplayFamilies = <String>{};
""",
)

# SCREEN-family persistence must count as confirmed display evidence BEFORE a
# signed geometric REALITY shortcut can resolve the video to NO_DISPLAY.
replace_once(
    fusion,
    """    final confirmedDisplayEvidence =
        liveTemporal || activeDisplayEvidence || mlStrong;
""",
    """    final confirmedDisplayEvidence = liveTemporal ||
        activeDisplayEvidence ||
        mlStrong ||
        mlSemanticScreenPersistenceV2 ||
        mlRealisticContentScreenPersistence ||
        photoStrongScreenFamilyAgreement;
""",
)

# Decision precedence: strong PHOTO family agreement first; then strict triple
# REALITY agreement; then signed geometry and the existing decision tree.
replace_once(
    fusion,
    """    late final String decision;
    late final int score;
    if (signedGeometricReality && !confirmedDisplayEvidence) {
""",
    """    late final String decision;
    late final int score;
    if (photoStrongScreenFamilyAgreement && !reflectedRealityEvidence) {
      decision = 'STRONG_DISPLAY_RISK';
      final stillScore =
          (postCaptureMl?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      final temporalScore =
          (photoTemporalMl?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      score = max(max(rawScore, stillScore), temporalScore).clamp(85, 100).toInt();
    } else if (photoDualRealityAgreement &&
        !hardLiveDisplayTrace &&
        !passiveStructuralEvidence &&
        !passiveStrong &&
        !passiveModerate &&
        !mlStrong) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.remove('ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add(
          'PHOTO_DUAL_REALITY_ML_AGREEMENT_OVERRIDES_ACTIVE_ONLY_SIGNAL');
    } else if (signedGeometricReality && !confirmedDisplayEvidence) {
""",
)

# Put PLANAR semantic REALITY ahead of generic independent/evidence handling.
replace_once(
    fusion,
    """    } else if (hasIndependentCorroboration) {
      decision = 'STRONG_DISPLAY_RISK';
""",
    """    } else if (planarSemanticRealityWithoutHardDisplayEvidence) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add(
        'PLANAR_GEOMETRY_RESOLVED_BY_SEMANTIC_REALITY_WITHOUT_HARD_DISPLAY_EVIDENCE',
      );
    } else if (hasIndependentCorroboration) {
      decision = 'STRONG_DISPLAY_RISK';
""",
)

# Add the new SCREEN reason when the geometry override fires.
replace_once(
    fusion,
    """      if (mlSemanticScreenPersistenceV2) {
        reasons.add('ML_SCREEN_SEMANTIC_PERSISTENCE_V2_CONFIRMED');
      }
      if (mlDualRegionPhotoEvidence) {
""",
    """      if (mlSemanticScreenPersistenceV2) {
        reasons.add('ML_SCREEN_SEMANTIC_PERSISTENCE_V2_CONFIRMED');
      }
      if (mlRealisticContentScreenPersistence) {
        reasons.add('ML_SCREEN_REALISTIC_CONTENT_PERSISTENCE_CONFIRMED');
      }
      if (mlDualRegionPhotoEvidence) {
""",
)

# Preserve the new explicit VIDEO REALITY resolution in the camera wrapper.
replace_once(
    camera,
    """          normalResult.reasons.contains(
            'SHORT_VIDEO_GEOMETRIC_AND_SEMANTIC_REALITY_AGREE',
          ));
""",
    """          normalResult.reasons.contains(
            'SHORT_VIDEO_GEOMETRIC_AND_SEMANTIC_REALITY_AGREE',
          ) ||
          normalResult.reasons.contains(
            'PLANAR_GEOMETRY_RESOLVED_BY_SEMANTIC_REALITY_WITHOUT_HARD_DISPLAY_EVIDENCE',
          ));
""",
)

# ---------------------------------------------------------------------------
# Regression tests for the four physical build74 failures plus safety guards.
# ---------------------------------------------------------------------------
Path('test/build74_fusion_regression_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> _live({
  required String geometry,
  String sceneClass = 'UNKNOWN',
  String decision = 'NON_CONCLUSIVE',
  int score = 45,
  bool rawActive = false,
  bool active = false,
  bool reflected = false,
  bool planar = false,
  bool confirmed = false,
  bool periodic = false,
  bool strongRefresh = false,
  bool displayBand = false,
  bool opticalStripe = false,
  bool opticalCorroborated = false,
  bool horizontalBands = false,
  Map<String, dynamic>? temporalMl,
}) => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': score,
      'displayRiskDecision': decision,
      'sceneClass': sceneClass,
      'reason': geometry == 'REALITY'
          ? 'ACTIVE_V5|MULTI_DEPTH_PARALLAX_DETECTED|NON_PLANAR_CAMERA_MOTION_RESPONSE'
          : 'ACTIVE_V5|PLANARITY_IS_CORROBORATION_ONLY',
      'videoEquivalentAvailable': false,
      'localTemporalFlickerScore': 0.34,
      'refreshBandScore': 0.18,
      'fineStripeScore': 0.08,
      'fineGridScore': 0.70,
      'moireFrequencyScore': 0.40,
      'persistentPatternScore': 0.80,
      'dynamicChallengeScore': 0.30,
      'globalFlickerScore': 0.10,
      'geometryChallenge': {
        'sceneClass': geometry,
        'realityEvidence': geometry == 'REALITY',
        'planarEvidence': planar,
      },
      'signals': {
        'rawActiveDisplayEvidence': rawActive,
        'activeIlluminationDisplayEvidence': active,
        'reflectedRealityEvidence': reflected,
        'planarSceneEvidence': planar,
        'activeChallengeIndeterminate': false,
        'confirmedDisplayTrace': confirmed,
        'periodicLightTrace': periodic,
        'strongRefreshTrace': strongRefresh,
        'displayBandTrace': displayBand,
        'opticalStripeTrace': opticalStripe,
        'opticalCorroboratedTrace': opticalCorroborated,
        'pairedFlickerTrace': horizontalBands,
        'horizontalRefreshBands': horizontalBands,
        'uncorroboratedDisplayPattern': !confirmed,
      },
      if (temporalMl != null)
        'photoTemporalVideoProbe': {
          'mlScreenReplayAnalysis': temporalMl,
        },
    };

Map<String, dynamic> _passive({int score = 0, bool structural = false}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'screenReplayRiskScore': score,
      'signals': {
        'structuralDisplayTrace': structural,
        'confirmedDisplayTrace': structural,
        'strongDisplayTrace': structural && score >= 70,
      },
    };

Map<String, dynamic> _ml({
  required String predictedClass,
  required double confidence,
  required double screenProbability,
  required int score,
  required int frames,
  required int strong,
  required int medium,
  required double average,
  required int maxFrame,
  required List<String> frameClasses,
  int fullFrame = 0,
  int contentArea = 0,
}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'screenReplayRiskScore': score,
      'displayRiskDecision': score >= 88
          ? 'STRONG_DISPLAY_RISK'
          : score >= 45
              ? 'NON_CONCLUSIVE'
              : 'NO_DISPLAY_EVIDENCE',
      'predictedClass': predictedClass,
      'predictedClassConfidence': confidence,
      'screenProbability': screenProbability,
      'framesAnalyzed': frames,
      'strongScreenFrameCount': strong,
      'mediumScreenFrameCount': medium,
      'averageScreenReplayRiskScore': average,
      'maxFrameScreenReplayRiskScore': maxFrame,
      'signals': {
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
      'videoFrameAnalyses': [
        for (final frameClass in frameClasses)
          {'predictedClass': frameClass},
      ],
    };

void main() {
  test('build74 photo TV: 2-frame SCREEN family plus still beats false REALITY geometry', () {
    final temporal = _ml(
      predictedClass: 'SCREEN_MONITOR',
      confidence: 0.90,
      screenProbability: 0.9894,
      score: 99,
      frames: 2,
      strong: 2,
      medium: 2,
      average: 98.5,
      maxFrame: 99,
      frameClasses: const ['SCREEN_MONITOR', 'SCREEN_MONITOR'],
    );
    final still = _ml(
      predictedClass: 'SCREEN_MONITOR',
      confidence: 0.7372,
      screenProbability: 0.9747,
      score: 97,
      frames: 1,
      strong: 1,
      medium: 1,
      average: 97,
      maxFrame: 97,
      fullFrame: 97,
      contentArea: 98,
      frameClasses: const ['SCREEN_MONITOR'],
    );
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
      _live(
        geometry: 'REALITY',
        sceneClass: 'REALITY',
        decision: 'NO_DISPLAY_EVIDENCE',
        score: 20,
        temporalMl: temporal,
      ),
      still,
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons,
        contains('PHOTO_TEMPORAL_AND_STILL_SCREEN_FAMILY_CONFIRMED'));
  });

  test('build74 photo desk: triple semantic REALITY resolves PLANAR-only uncertainty', () {
    final temporal = _ml(
      predictedClass: 'REALITY_PAPER',
      confidence: 0.70,
      screenProbability: 0.1013,
      score: 10,
      frames: 2,
      strong: 0,
      medium: 0,
      average: 7.5,
      maxFrame: 10,
      frameClasses: const ['REALITY_PAPER', 'REALITY_PAPER'],
    );
    final still = _ml(
      predictedClass: 'REALITY_PAPER',
      confidence: 0.70,
      screenProbability: 0.0648,
      score: 6,
      frames: 1,
      strong: 0,
      medium: 0,
      average: 6,
      maxFrame: 6,
      fullFrame: 6,
      contentArea: 10,
      frameClasses: const ['REALITY_PAPER'],
    );
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
      _live(
        geometry: 'PLANAR',
        planar: true,
        temporalMl: temporal,
      ),
      still,
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('PHOTO_DUAL_REALITY_ML_AGREEMENT_OVERRIDES_ACTIVE_ONLY_SIGNAL'),
    );
  });

  test('build74 video TV: 3 of 4 SCREEN with high family probability beats false REALITY geometry', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        geometry: 'REALITY',
        sceneClass: 'REALITY',
        decision: 'NO_DISPLAY_EVIDENCE',
        score: 20,
      ),
      _passive(),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.74,
        screenProbability: 0.9739,
        score: 97,
        frames: 4,
        strong: 2,
        medium: 2,
        average: 66.25,
        maxFrame: 97,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_TABLET',
          'REALITY_OUTDOOR',
        ],
      ),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons,
        contains('ML_SCREEN_REALISTIC_CONTENT_PERSISTENCE_CONFIRMED'));
  });

  test('build74 video desk: PLANAR temporal-only signal resolves to REALITY', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        geometry: 'PLANAR',
        planar: true,
        horizontalBands: true,
      ),
      _passive(),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.55,
        screenProbability: 0.62,
        score: 71,
        frames: 4,
        strong: 0,
        medium: 0,
        average: 33.75,
        maxFrame: 71,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'REALITY_PAPER',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains(
        'PLANAR_GEOMETRY_RESOLVED_BY_SEMANTIC_REALITY_WITHOUT_HARD_DISPLAY_EVIDENCE',
      ),
    );
  });

  test('hard display trace blocks PLANAR semantic REALITY override', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        geometry: 'PLANAR',
        planar: true,
        confirmed: true,
        periodic: true,
        decision: 'STRONG_DISPLAY_RISK',
        score: 75,
      ),
      _passive(),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.55,
        screenProbability: 0.62,
        score: 71,
        frames: 4,
        strong: 0,
        medium: 0,
        average: 33.75,
        maxFrame: 71,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'REALITY_PAPER',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });

  test('only 2 of 4 SCREEN frames cannot trigger realistic-content SCREEN persistence', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        geometry: 'REALITY',
        sceneClass: 'REALITY',
        decision: 'NO_DISPLAY_EVIDENCE',
        score: 20,
      ),
      _passive(),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.98,
        screenProbability: 0.98,
        score: 97,
        frames: 4,
        strong: 2,
        medium: 2,
        average: 70,
        maxFrame: 97,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'REALITY_ROOM',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(
      result.reasons,
      isNot(contains('ML_SCREEN_REALISTIC_CONTENT_PERSISTENCE_CONFIRMED')),
    );
  });
}
''')

print('build74 fusion fixes materialized')
