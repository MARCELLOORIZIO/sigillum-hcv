import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _opticalClean() => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'framesAnalyzed': 15,
  'screenReplayRiskScore': 20,
  'signals': <String, dynamic>{
    'displayFlicker': false,
    'pixelGridOrMoireHint': false,
    'uniformPixelGrid': false,
    'localRefreshFlicker': false,
    'horizontalRefreshBands': false,
    'pairedLocalRefresh': false,
    'temporalScreenPulse': false,
    'structuralDisplayTrace': false,
    'strongDisplayTrace': false,
    'confirmedDisplayTrace': false,
    'periodicLightTrace': false,
    'opticalCorroboratedTrace': false,
  },
};

Map<String, dynamic> _quietV32({bool mixed = false}) => <String, dynamic>{
  'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
  'analysisStatus': 'ANALYZED',
  'coherentDisplayPeriodicity': false,
  'shortExposureVerified': true,
  'exposureLockedForEntireNativeCapture': true,
  'framesAnalyzed': 84,
  'actualFrameRateFromTimestamps': 240.62,
  'displayRealityEvidenceV3': <String, dynamic>{
    'fullFrameDisplay': false,
    'fullFrameReality': false,
    'positivePhysicalRealityEvidence': false,
    'mixedSceneDetected': mixed,
    'allNineCellsSameDisplayFamily': false,
    'displayLikeCellCount': mixed ? 4 : 0,
    'spatialFamilyCellCount': mixed ? 4 : 0,
    'harmonicAwareSpatialFamilyCellCount': mixed ? 4 : 0,
    'rowTimeFamilyCellCount': mixed ? 4 : 0,
  },
};

Map<String, dynamic> _ml({
  List<double> probabilities = const <double>[0.9578, 0.9225, 0.9179],
  List<int> fullFrame = const <int>[96, 92, 92],
  List<int> content = const <int>[75, 76, 59],
  int strongScreenFrames = 3,
  double averageScore = 93.3333,
}) {
  assert(probabilities.length == 3);
  assert(fullFrame.length == 3);
  assert(content.length == 3);
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': 93,
    'predictedClass': 'SCREEN_MONITOR',
    'predictedClassConfidence': 0.95,
    'screenProbability': 0.9578,
    'framesAnalyzed': 3,
    'strongScreenFrameCount': strongScreenFrames,
    'mediumScreenFrameCount': 3,
    'averageScreenReplayRiskScore': averageScore,
    'maxFrameScreenReplayRiskScore': 96,
    'signals': <String, dynamic>{
      'fullFrameRiskScore': 96,
      'contentAreaRiskScore': 76,
    },
    'videoFrameAnalyses': <Map<String, dynamic>>[
      for (var i = 0; i < 3; i++)
        <String, dynamic>{
          'videoFrameIndex': i,
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': probabilities[i],
          'signals': <String, dynamic>{
            'fullFrameRiskScore': fullFrame[i],
            'contentAreaRiskScore': content[i],
          },
        },
    ],
  };
}

HCVDisplayRiskResult _resolve(Map<String, dynamic> ml, {bool mixed = false}) {
  final base = HCVDisplayRiskFusion.mlFirstVideoDecision(ml);
  expect(base, isNotNull);
  expect(base!.decision, 'STRONG_DISPLAY_RISK');
  expect(
    base.reasons,
    contains('ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY'),
  );
  expect(
    base.reasons,
    contains('ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION'),
  );
  return HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
    base: base,
    passiveOptical: _opticalClean(),
    ml: ml,
    temporalFrequencyProbe: _quietV32(mixed: mixed),
  );
}

void main() {
  test('BUILD109 recovers HCV-4A2F-like three-frame full-screen web text', () {
    final result = _resolve(_ml());
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.risk, 'HIGH');
    expect(
      result.reasons,
      contains('ML_THREE_FRAME_FULL_FRAME_SCREEN_RECOVERY_V109'),
    );
    expect(
      result.reasons,
      contains('TWO_FULL_FRAME_SCREEN_SAMPLES_WITH_CONTENT_SUPPORT_75'),
    );
    expect(
      result.reasons,
      isNot(contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE')),
    );
  });

  test('BUILD109 preserves the existing strict content-area 85 path', () {
    final result = _resolve(_ml(content: const <int>[90, 90, 59]));
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(
      result.reasons,
      contains('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES'),
    );
    expect(
      result.reasons,
      isNot(contains('ML_THREE_FRAME_FULL_FRAME_SCREEN_RECOVERY_V109')),
    );
  });

  test('BUILD109 recovery requires two content-area samples at least 75', () {
    final result = _resolve(_ml(content: const <int>[75, 74, 59]));
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'),
    );
  });

  test(
    'BUILD109 recovery requires all three frame probabilities at least 0.90',
    () {
      final result = _resolve(
        _ml(probabilities: const <double>[0.9578, 0.899, 0.9179]),
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'),
      );
    },
  );

  test('BUILD109 recovery requires two full-frame scores at least 90', () {
    final result = _resolve(_ml(fullFrame: const <int>[96, 89, 89]));
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'),
    );
  });

  test(
    'BUILD109 recovery requires all three aggregate strong screen frames',
    () {
      final result = _resolve(_ml(strongScreenFrames: 2));
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'),
      );
    },
  );

  test('BUILD109 legacy mixed flag without reality cells cannot veto display', () {
    final result = _resolve(_ml(), mixed: true);
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, isNot(contains('HFR_V3_MIXED_REAL_SCENE')));
  });
}
