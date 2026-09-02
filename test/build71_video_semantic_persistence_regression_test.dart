import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> _passive({int score = 0, bool structural = false}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 12,
      'screenReplayRiskScore': score,
      'signals': {
        'structuralDisplayTrace': structural,
        'confirmedDisplayTrace': structural,
        'strongDisplayTrace': structural,
      },
    };

Map<String, dynamic> _live({
  required String sceneClass,
  required String geometryClass,
  bool planar = false,
  bool reflectedReality = false,
  bool rawActive = false,
  bool activeDisplay = false,
  bool confirmedDisplay = false,
  bool periodicLight = false,
  bool activeIndeterminate = false,
  int score = 45,
  String decision = 'NON_CONCLUSIVE',
  double localFlicker = 0.10,
  double refreshBand = 0.05,
  double fineStripe = 0.05,
  double fineGrid = 0.20,
  double moire = 0.10,
  double persistentPattern = 0.10,
  double dynamicChallenge = 0.50,
  double globalFlicker = 0.05,
  bool pairedFlicker = false,
  bool horizontalRefreshBands = false,
  String reason = 'ACTIVE_V5',
}) => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': score,
      'displayRiskDecision': decision,
      'sceneClass': sceneClass,
      'reason': reason,
      'videoEquivalentAvailable': false,
      'globalFlickerScore': globalFlicker,
      'localTemporalFlickerScore': localFlicker,
      'refreshBandScore': refreshBand,
      'fineStripeScore': fineStripe,
      'fineGridScore': fineGrid,
      'moireFrequencyScore': moire,
      'persistentPatternScore': persistentPattern,
      'dynamicChallengeScore': dynamicChallenge,
      'geometryChallenge': {
        'sceneClass': geometryClass,
        'realityEvidence': geometryClass == 'REALITY',
        'planarEvidence': planar,
      },
      'signals': {
        'rawActiveDisplayEvidence': rawActive,
        'activeIlluminationDisplayEvidence': activeDisplay,
        'reflectedRealityEvidence': reflectedReality,
        'planarSceneEvidence': planar,
        'activeChallengeIndeterminate': activeIndeterminate,
        'confirmedDisplayTrace': confirmedDisplay,
        'periodicLightTrace': periodicLight,
        'pairedFlickerTrace': pairedFlicker,
        'displayBandTrace': false,
        'horizontalRefreshBands': horizontalRefreshBands,
        'uncorroboratedDisplayPattern': true,
      },
    };

Map<String, dynamic> _ml({
  required String predictedClass,
  required double confidence,
  required double screenProbability,
  required int score,
  required int framesAnalyzed,
  required int strongFrames,
  required int mediumFrames,
  required double averageScore,
  required int maxFrameScore,
  required List<String> frameClasses,
  int fullFrameRisk = 0,
  int contentAreaRisk = 0,
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
      'framesAnalyzed': framesAnalyzed,
      'strongScreenFrameCount': strongFrames,
      'mediumScreenFrameCount': mediumFrames,
      'averageScreenReplayRiskScore': averageScore,
      'maxFrameScreenReplayRiskScore': maxFrameScore,
      'signals': {
        'fullFrameRiskScore': fullFrameRisk,
        'contentAreaRiskScore': contentAreaRisk,
      },
      'videoFrameAnalyses': [
        for (final frameClass in frameClasses)
          {'predictedClass': frameClass},
      ],
    };

Map<String, dynamic> _d3Live({bool reflectedReality = false}) => _live(
      sceneClass: 'REALITY',
      geometryClass: 'REALITY',
      reflectedReality: reflectedReality,
      score: 20,
      decision: 'NO_DISPLAY_EVIDENCE',
      localFlicker: 0.3382,
      refreshBand: 0.1494,
      fineStripe: 0.0685,
      fineGrid: 0.5134,
      moire: 0.3461,
      persistentPattern: 0.9619,
      dynamicChallenge: 0.0,
      globalFlicker: 0.1622,
      pairedFlicker: true,
      horizontalRefreshBands: true,
      reason:
          'ACTIVE_V5|MULTI_DEPTH_PARALLAX_DETECTED|NON_PLANAR_CAMERA_MOTION_RESPONSE',
    );

Map<String, dynamic> _d3Ml() => _ml(
      predictedClass: 'SCREEN_MONITOR',
      confidence: 0.8985,
      screenProbability: 0.9688,
      score: 97,
      framesAnalyzed: 5,
      strongFrames: 2,
      mediumFrames: 3,
      averageScore: 88.0,
      maxFrameScore: 97,
      fullFrameRisk: 97,
      contentAreaRisk: 75,
      frameClasses: const [
        'SCREEN_MONITOR',
        'SCREEN_MONITOR',
        'SCREEN_MONITOR',
        'SCREEN_MONITOR',
        'SCREEN_MONITOR',
      ],
    );

Map<String, dynamic> _reality43Ml({bool includeScreenFrame = false}) => _ml(
      predictedClass: 'REALITY_ROOM',
      confidence: 0.30,
      screenProbability: 0.2889,
      score: 29,
      framesAnalyzed: 4,
      strongFrames: 0,
      mediumFrames: 0,
      averageScore: 18.25,
      maxFrameScore: 29,
      frameClasses: [
        includeScreenFrame ? 'SCREEN_MONITOR' : 'REALITY_ROOM',
        'REALITY_PAPER',
        'REALITY_ROOM',
        'REALITY_PAPER',
      ],
    );

Map<String, dynamic> _reality9Ml() => _ml(
      predictedClass: 'REALITY_OUTDOOR',
      confidence: 0.7887,
      screenProbability: 0.0963,
      score: 10,
      framesAnalyzed: 4,
      strongFrames: 0,
      mediumFrames: 0,
      averageScore: 3.0,
      maxFrameScore: 10,
      frameClasses: const [
        'REALITY_OUTDOOR',
        'REALITY_OUTDOOR',
        'REALITY_ROOM',
        'REALITY_OUTDOOR',
      ],
    );

void main() {
  test('build71 D3C7 monitor: all-frame SCREEN persistence defeats false REALITY geometry', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _d3Live(),
      _passive(score: 0),
      _d3Ml(),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, 97);
    expect(
      result.reasons,
      contains('ML_SCREEN_ALL_FRAME_SEMANTIC_PERSISTENCE_CONFIRMED'),
    );
  });

  test('build71 43E1 physical scene: all-frame REALITY resolves uncorroborated planar temporal signal', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        activeIndeterminate: true,
        score: 45,
        decision: 'NON_CONCLUSIVE',
        localFlicker: 0.348,
        refreshBand: 0.1607,
        fineStripe: 0.0226,
        fineGrid: 0.7569,
        moire: 0.6123,
        persistentPattern: 0.9525,
        dynamicChallenge: 0.703,
        globalFlicker: 0.1408,
        pairedFlicker: true,
        horizontalRefreshBands: true,
      ),
      _passive(score: 20),
      _reality43Ml(),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
    expect(
      result.reasons,
      contains(
        'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
      ),
    );
  });

  test('build71 9EA7 outdoor scene: PLANAR alone cannot veto unanimous REALITY frames', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'REALITY',
        geometryClass: 'PLANAR',
        planar: true,
        reflectedReality: true,
        score: 20,
        decision: 'NO_DISPLAY_EVIDENCE',
        localFlicker: 0.2239,
        refreshBand: 0.0675,
        fineStripe: 0.0555,
        fineGrid: 0.2134,
        moire: 0.3671,
        persistentPattern: 0.9709,
        dynamicChallenge: 0.7349,
        globalFlicker: 0.0883,
      ),
      _passive(score: 0),
      _reality9Ml(),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
  });

  test('REALITY override is blocked by one semantic SCREEN frame', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        activeIndeterminate: true,
      ),
      _passive(score: 20),
      _reality43Ml(includeScreenFrame: true),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });

  test('REALITY override is blocked by active display evidence', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        rawActive: true,
        activeDisplay: true,
        activeIndeterminate: true,
      ),
      _passive(score: 20),
      _reality43Ml(),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });

  test('SCREEN semantic persistence cannot defeat reflected REALITY evidence', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _d3Live(reflectedReality: true),
      _passive(score: 0),
      _d3Ml(),
    ]);

    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });
}
