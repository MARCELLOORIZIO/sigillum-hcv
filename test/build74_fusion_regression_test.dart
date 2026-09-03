import 'package:flutter_test/flutter_test.dart';
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
