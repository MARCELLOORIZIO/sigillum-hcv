import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> _passive({int score = 75, bool structural = false}) => {
  'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'screenReplayRiskScore': score,
  'signals': {
    'structuralDisplayTrace': structural,
    'confirmedDisplayTrace': structural,
    'strongDisplayTrace': score >= 70,
  },
};

Map<String, dynamic> _live({
  required String sceneClass,
  required String geometryClass,
  bool rawActive = false,
  bool activeDisplay = false,
  bool confirmedDisplay = false,
  bool periodicLight = false,
  bool planar = false,
  int score = 45,
  String decision = 'NON_CONCLUSIVE',
  double localFlicker = 0.10,
  double refreshBand = 0.05,
  double globalFlicker = 0.05,
  bool displayBand = false,
  bool horizontalBands = false,
}) => {
  'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
  'activeProbeVersion': 5,
  'analysisStatus': 'ANALYZED',
  'framesAnalyzed': 45,
  'screenReplayRiskScore': score,
  'displayRiskDecision': decision,
  'sceneClass': sceneClass,
  'reason': geometryClass == 'REALITY'
      ? 'ACTIVE_V5|MULTI_DEPTH_PARALLAX_DETECTED|NON_PLANAR_CAMERA_MOTION_RESPONSE'
      : 'ACTIVE_V5|GEOMETRY_RESPONSE_AMBIGUOUS',
  'videoEquivalentAvailable': false,
  'localTemporalFlickerScore': localFlicker,
  'refreshBandScore': refreshBand,
  'fineStripeScore': 0.08,
  'fineGridScore': 0.30,
  'moireFrequencyScore': 0.20,
  'persistentPatternScore': 0.20,
  'dynamicChallengeScore': 0.30,
  'globalFlickerScore': globalFlicker,
  'geometryChallenge': {
    'sceneClass': geometryClass,
    'realityEvidence': geometryClass == 'REALITY',
    'planarEvidence': planar,
  },
  'signals': {
    'rawActiveDisplayEvidence': rawActive,
    'activeIlluminationDisplayEvidence': activeDisplay,
    'reflectedRealityEvidence': false,
    'planarSceneEvidence': planar,
    'activeChallengeIndeterminate': false,
    'confirmedDisplayTrace': confirmedDisplay,
    'periodicLightTrace': periodicLight,
    'strongRefreshTrace': displayBand,
    'displayBandTrace': displayBand,
    'opticalStripeTrace': false,
    'opticalCorroboratedTrace': false,
    'moireFrequencyTrace': displayBand,
    'pairedFlickerTrace': displayBand,
    'horizontalRefreshBands': horizontalBands,
    'uncorroboratedDisplayPattern': !confirmedDisplay,
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
  'framesAnalyzed': frames,
  'strongScreenFrameCount': strongFrames,
  'mediumScreenFrameCount': mediumFrames,
  'averageScreenReplayRiskScore': average,
  'maxFrameScreenReplayRiskScore': maxFrame,
  'signals': {
    'fullFrameRiskScore': fullFrameRisk,
    'contentAreaRiskScore': contentAreaRisk,
  },
  'videoFrameAnalyses': [
    for (final frameClass in frameClasses) {'predictedClass': frameClass},
  ],
};

void main() {
  test('build72 E86 short REALITY resolves isolated active false positive', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'REALITY',
        geometryClass: 'REALITY',
        rawActive: true,
        activeDisplay: true,
        localFlicker: 0.34,
        refreshBand: 0.18,
        globalFlicker: 0.10,
        displayBand: true,
        horizontalBands: true,
      ),
      _passive(score: 75, structural: false),
      _ml(
        predictedClass: 'REALITY_PAPER',
        confidence: 0.5582,
        screenProbability: 0.2218,
        score: 22,
        frames: 2,
        strongFrames: 0,
        mediumFrames: 0,
        average: 18.5,
        maxFrame: 22,
        frameClasses: const ['REALITY_PAPER', 'REALITY_PAPER'],
      ),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
    expect(
      result.reasons,
      contains('SHORT_VIDEO_GEOMETRIC_AND_SEMANTIC_REALITY_AGREE'),
    );
  });

  test('build72 3E long unanimous REALITY ignores active-only false positive', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'UNKNOWN',
        rawActive: true,
        activeDisplay: true,
      ),
      _passive(score: 75, structural: false),
      _ml(
        predictedClass: 'REALITY_OUTDOOR',
        confidence: 0.567,
        screenProbability: 0.0986,
        score: 10,
        frames: 6,
        strongFrames: 0,
        mediumFrames: 0,
        average: 5.6667,
        maxFrame: 10,
        frameClasses: const [
          'REALITY_OUTDOOR',
          'REALITY_ROOM',
          'REALITY_PAPER',
          'REALITY_PAPER',
          'REALITY_ROOM',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
    expect(
      result.reasons,
      contains(
        'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
      ),
    );
  });

  test('persistent SCREEN remains strong even against REALITY geometry', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'REALITY',
        geometryClass: 'REALITY',
        score: 20,
        decision: 'NO_DISPLAY_EVIDENCE',
      ),
      _passive(score: 20, structural: false),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.98,
        screenProbability: 0.9882,
        score: 99,
        frames: 4,
        strongFrames: 3,
        mediumFrames: 3,
        average: 95.25,
        maxFrame: 99,
        fullFrameRisk: 99,
        contentAreaRisk: 93,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
        ],
      ),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });

  test('confirmed live display evidence blocks semantic REALITY override', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'UNKNOWN',
        rawActive: true,
        activeDisplay: true,
        confirmedDisplay: true,
        periodicLight: true,
        score: 75,
        decision: 'STRONG_DISPLAY_RISK',
      ),
      _passive(score: 20, structural: false),
      _ml(
        predictedClass: 'REALITY_ROOM',
        confidence: 0.95,
        screenProbability: 0.05,
        score: 5,
        frames: 6,
        strongFrames: 0,
        mediumFrames: 0,
        average: 5,
        maxFrame: 8,
        frameClasses: const [
          'REALITY_ROOM',
          'REALITY_ROOM',
          'REALITY_ROOM',
          'REALITY_ROOM',
          'REALITY_ROOM',
          'REALITY_ROOM',
        ],
      ),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });

  test('ML-first: short strong REALITY is not vetoed by PLANAR alone', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        rawActive: true,
        activeDisplay: true,
      ),
      _passive(score: 20, structural: false),
      _ml(
        predictedClass: 'REALITY_PAPER',
        confidence: 0.80,
        screenProbability: 0.10,
        score: 10,
        frames: 2,
        strongFrames: 0,
        mediumFrames: 0,
        average: 8,
        maxFrame: 10,
        frameClasses: const ['REALITY_PAPER', 'REALITY_PAPER'],
      ),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('ML_FIRST_VIDEO_NO_SCREEN_MAJORITY_LOW_PROBABILITY'),
    );
  });

  test('camera stop path serializes finalization before video processing', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(
      source,
      contains(
        'if (_captureLifecycle != HCVCaptureLifecycle.recording) return;',
      ),
    );
    expect(
      source,
      contains('_setCaptureLifecycle(HCVCaptureLifecycle.finalizingVideo);'),
    );
    expect(
      source.indexOf(
        '_setCaptureLifecycle(HCVCaptureLifecycle.finalizingVideo);',
      ),
      lessThan(source.indexOf('await controller!.stopVideoRecording();')),
    );
    expect(
      source,
      contains('_setCaptureLifecycle(HCVCaptureLifecycle.processingVideo);'),
    );
    expect(source, contains('_waitForFinalizedVideoContainer(file.path)'));
    expect(source, contains('stableReads >= 3'));
    expect(source, contains('Duration(seconds: 6)'));
    expect(source, contains('copiedSize != sourceSize'));
    expect(source, contains('PopScope('));
    expect(source, contains('canPop: !_captureInteractionLocked'));
  });
}
