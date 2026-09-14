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

Map<String, dynamic> _still({
  required int score,
  required double probability,
  required int fullFrame,
  required int contentArea,
  String predictedClass = 'SCREEN_MONITOR',
}) => <String, dynamic>{
  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'scanMode': 'STILL_IMAGE_ML_CLASSIFIER',
  'framesAnalyzed': 1,
  'screenReplayRisk': score >= 90 ? 'HIGH' : 'LOW',
  'screenReplayRiskScore': score,
  'screenProbability': probability,
  'predictedClass': predictedClass,
  'predictedClassConfidence': probability,
  'signals': <String, dynamic>{
    'fullFrameRiskScore': fullFrame,
    'contentAreaRiskScore': contentArea,
  },
};

Map<String, dynamic> _temporal({
  required List<double> probabilities,
  required List<int> fullFrames,
  required List<int> contentAreas,
  List<String>? predictedClasses,
}) {
  final scores = probabilities.map((value) => (value * 100).round()).toList();
  final strong = scores.where((score) => score >= 92).length;
  final medium = scores.where((score) => score >= 88).length;
  final average = scores.reduce((a, b) => a + b) / scores.length;
  final maxScore = scores.reduce((a, b) => a > b ? a : b);
  final classes =
      predictedClasses ??
      List<String>.filled(probabilities.length, 'SCREEN_MONITOR');
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'scanMode': 'VIDEO_MULTI_FRAME_ML_CLASSIFIER',
    'framesAnalyzed': probabilities.length,
    'screenReplayRiskScore': maxScore,
    'screenReplayRisk': 'HIGH',
    'predictedClass': 'SCREEN_MONITOR',
    'predictedClassConfidence': probabilities.reduce((a, b) => a > b ? a : b),
    'screenProbability': probabilities.reduce((a, b) => a > b ? a : b),
    'strongScreenFrameCount': strong,
    'mediumScreenFrameCount': medium,
    'averageScreenReplayRiskScore': average,
    'maxFrameScreenReplayRiskScore': maxScore,
    'signals': <String, dynamic>{
      'fullFrameRiskScore': fullFrames.reduce((a, b) => a > b ? a : b),
      'contentAreaRiskScore': contentAreas.reduce((a, b) => a > b ? a : b),
    },
    'videoFrameAnalyses': <Map<String, dynamic>>[
      for (var i = 0; i < probabilities.length; i++)
        <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'videoFrameIndex': i,
          'predictedClass': classes[i],
          'predictedClassConfidence': probabilities[i],
          'screenProbability': probabilities[i],
          'screenReplayRiskScore': scores[i],
          'signals': <String, dynamic>{
            'fullFrameRiskScore': fullFrames[i],
            'contentAreaRiskScore': contentAreas[i],
          },
        },
    ],
  };
}

HCVDisplayRiskResult _resolve({
  required Map<String, dynamic> still,
  required Map<String, dynamic> temporal,
  bool mixed = false,
}) {
  final base = HCVDisplayRiskFusion.mlFirstVideoDecision(temporal);
  expect(base, isNotNull);
  expect(base!.decision, 'STRONG_DISPLAY_RISK');
  return HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
    base: base,
    passiveOptical: _opticalClean(),
    ml: still,
    photoTemporalMl: temporal,
    temporalFrequencyProbe: _quietV32(mixed: mixed),
  );
}

void main() {
  test('C546 BUILD110 monitor regression remains HIGH', () {
    final temporal = _temporal(
      probabilities: const <double>[0.954401, 0.951494, 0.922244],
      fullFrames: const <int>[95, 95, 92],
      contentAreas: const <int>[71, 79, 73],
    );
    final result = _resolve(
      still: _still(
        score: 93,
        probability: 0.932044,
        fullFrame: 93,
        contentArea: 87,
      ),
      temporal: temporal,
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.risk, 'HIGH');
    expect(
      result.reasons,
      contains('PHOTO_STILL_TEMPORAL_FULL_FRAME_CORROBORATION'),
    );
    expect(
      result.reasons,
      isNot(contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE')),
    );
  });

  test('F776 BUILD110 monitor regression remains HIGH', () {
    final temporal = _temporal(
      probabilities: const <double>[0.979805, 0.931175, 0.922176],
      fullFrames: const <int>[98, 93, 92],
      contentAreas: const <int>[75, 74, 73],
    );
    final result = _resolve(
      still: _still(
        score: 97,
        probability: 0.9732,
        fullFrame: 97,
        contentArea: 92,
      ),
      temporal: temporal,
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.risk, 'HIGH');
    expect(
      result.reasons,
      contains('PHOTO_STILL_TEMPORAL_FULL_FRAME_CORROBORATION'),
    );
  });

  test(
    'strong temporal monitor cannot promote weak still spatial evidence',
    () {
      final temporal = _temporal(
        probabilities: const <double>[0.954401, 0.951494, 0.922244],
        fullFrames: const <int>[95, 95, 92],
        contentAreas: const <int>[71, 79, 73],
      );
      final result = _resolve(
        still: _still(
          score: 93,
          probability: 0.932044,
          fullFrame: 93,
          contentArea: 84,
        ),
        temporal: temporal,
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'),
      );
      expect(
        result.reasons,
        isNot(contains('PHOTO_STILL_TEMPORAL_FULL_FRAME_CORROBORATION')),
      );
    },
  );

  test('semantic transition cannot activate still-temporal corroboration', () {
    final temporal = _temporal(
      probabilities: const <double>[0.954401, 0.951494, 0.922244],
      fullFrames: const <int>[95, 95, 92],
      contentAreas: const <int>[71, 79, 73],
      predictedClasses: const <String>[
        'SCREEN_MONITOR',
        'REALITY_ROOM',
        'SCREEN_MONITOR',
      ],
    );
    final result = _resolve(
      still: _still(
        score: 93,
        probability: 0.932044,
        fullFrame: 93,
        contentArea: 87,
      ),
      temporal: temporal,
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      isNot(contains('PHOTO_STILL_TEMPORAL_FULL_FRAME_CORROBORATION')),
    );
  });

  test('mixed-scene HFR veto remains absolute', () {
    final temporal = _temporal(
      probabilities: const <double>[0.954401, 0.951494, 0.922244],
      fullFrames: const <int>[95, 95, 92],
      contentAreas: const <int>[71, 79, 73],
    );
    final result = _resolve(
      still: _still(
        score: 93,
        probability: 0.932044,
        fullFrame: 93,
        contentArea: 87,
      ),
      temporal: temporal,
      mixed: true,
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('HFR_V3_MIXED_REAL_SCENE'));
    expect(
      result.reasons,
      isNot(contains('PHOTO_STILL_TEMPORAL_FULL_FRAME_CORROBORATION')),
    );
  });
}
