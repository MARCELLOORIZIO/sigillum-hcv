import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> _passive({int score = 20}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 30,
      'screenReplayRiskScore': score,
      'signals': {
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'strongDisplayTrace': score >= 70,
      },
    };

Map<String, dynamic> _live({
  required String geometryClass,
  bool reflectedReality = false,
}) => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'sceneClass': geometryClass == 'REALITY' ? 'REALITY' : 'UNKNOWN',
      'reason': 'ACTIVE_V5|PLANARITY_IS_CORROBORATION_ONLY',
      'videoEquivalentAvailable': false,
      'globalFlickerScore': 0.10,
      'localTemporalFlickerScore': 0.20,
      'refreshBandScore': 0.10,
      'fineStripeScore': 0.05,
      'fineGridScore': 0.20,
      'moireFrequencyScore': 0.20,
      'persistentPatternScore': 0.80,
      'dynamicChallengeScore': 0.40,
      'geometryChallenge': {
        'sceneClass': geometryClass,
        'realityEvidence': geometryClass == 'REALITY',
        'planarEvidence': geometryClass == 'PLANAR',
      },
      'signals': {
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': reflectedReality,
        'planarSceneEvidence': geometryClass == 'PLANAR',
        'activeChallengeIndeterminate': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'pairedFlickerTrace': false,
        'displayBandTrace': false,
        'horizontalRefreshBands': false,
        'uncorroboratedDisplayPattern': true,
      },
    };

Map<String, dynamic> _ml({
  required String predictedClass,
  required double confidence,
  required double screenProbability,
  required int score,
  required int frames,
  required int strongFrames,
  required int mediumFrames,
  required double average,
  required int maxFrame,
  required List<String> frameClasses,
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
      'strongScreenFrameCount': strongFrames,
      'mediumScreenFrameCount': mediumFrames,
      'averageScreenReplayRiskScore': average,
      'maxFrameScreenReplayRiskScore': maxFrame,
      'signals': {
        'fullFrameRiskScore': maxFrame,
        'contentAreaRiskScore': maxFrame,
      },
      'videoFrameAnalyses': [
        for (final frameClass in frameClasses)
          {'predictedClass': frameClass},
      ],
    };

void main() {
  test('build73 C39 6/6 SCREEN with PLANAR geometry becomes STRONG', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(geometryClass: 'PLANAR'),
      _passive(score: 85),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.7774,
        screenProbability: 0.9424,
        score: 94,
        frames: 6,
        strongFrames: 3,
        mediumFrames: 5,
        average: 87.8333,
        maxFrame: 94,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
        ],
      ),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('ML_SCREEN_SEMANTIC_PERSISTENCE_V2_CONFIRMED'));
  });

  test('build73 36F 5/6 SCREEN strong anchor defeats false REALITY geometry', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(geometryClass: 'REALITY'),
      _passive(score: 20),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.9794,
        screenProbability: 0.9801,
        score: 98,
        frames: 6,
        strongFrames: 3,
        mediumFrames: 3,
        average: 74.6667,
        maxFrame: 98,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('ML_SCREEN_SEMANTIC_PERSISTENCE_V2_CONFIRMED'));
  });

  test('build73 F6A 1/6 SCREEN remains REALITY', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(geometryClass: 'REALITY'),
      _passive(score: 100),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.4388,
        screenProbability: 0.5171,
        score: 52,
        frames: 6,
        strongFrames: 0,
        mediumFrames: 0,
        average: 19.5,
        maxFrame: 52,
        frameClasses: const [
          'SCREEN_MONITOR',
          'REALITY_OUTDOOR',
          'REALITY_ROOM',
          'REALITY_PAPER',
          'REALITY_ROOM',
          'REALITY_ROOM',
        ],
      ),
    ]);

    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('ML-first: 80 percent SCREEN at p=.95 overrides geometry REALITY', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(geometryClass: 'REALITY'),
      _passive(score: 20),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.90,
        screenProbability: 0.95,
        score: 95,
        frames: 5,
        strongFrames: 2,
        mediumFrames: 3,
        average: 86,
        maxFrame: 95,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(
      result.reasons,
      contains('ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY'),
    );
  });

  test('reflected REALITY blocks persistence V2', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(geometryClass: 'REALITY', reflectedReality: true),
      _passive(score: 20),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.99,
        screenProbability: 0.99,
        score: 99,
        frames: 5,
        strongFrames: 5,
        mediumFrames: 5,
        average: 99,
        maxFrame: 99,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
        ],
      ),
    ]);

    expect(result.reasons, isNot(contains('ML_SCREEN_SEMANTIC_PERSISTENCE_V2_CONFIRMED')));
  });
}
