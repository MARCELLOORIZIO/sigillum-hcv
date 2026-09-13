import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_video_photo_spatial_evidence.dart';

Map<String, dynamic> _frame({
  required int index,
  required String predictedClass,
  required double probability,
  required int fullFrame,
  required int contentArea,
}) => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'videoFrameIndex': index,
  'approxVideoSecond': index.toDouble(),
  'predictedClass': predictedClass,
  'predictedClassConfidence': 0.95,
  'screenProbability': probability,
  'screenReplayRiskScore': (probability * 100).round(),
  'signals': <String, dynamic>{
    'fullFrameRiskScore': fullFrame,
    'contentAreaRiskScore': contentArea,
  },
};

Map<String, dynamic> _ml(
  List<Map<String, dynamic>> frames, {
  bool includePhotoSpatial = true,
}) {
  final scores = frames
      .map((frame) => (frame['screenReplayRiskScore'] as num).toInt())
      .toList();
  final strong = scores.where((score) => score >= 92).length;
  final medium = scores.where((score) => score >= 88).length;
  final average = scores.reduce((a, b) => a + b) / scores.length;
  final maxScore = scores.reduce((a, b) => a > b ? a : b);
  final result = <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': maxScore,
    'predictedClass': 'SCREEN_MONITOR',
    'predictedClassConfidence': 0.95,
    'screenProbability': 0.96,
    'framesAnalyzed': frames.length,
    'strongScreenFrameCount': strong,
    'mediumScreenFrameCount': medium,
    'averageScreenReplayRiskScore': average,
    'maxFrameScreenReplayRiskScore': maxScore,
    'signals': const <String, dynamic>{
      'fullFrameRiskScore': 96,
      'contentAreaRiskScore': 82,
    },
    'videoFrameAnalyses': frames,
  };
  if (includePhotoSpatial) {
    result['videoPhotoSpatialEvidence'] = HCVVideoPhotoSpatialEvidence.analyze(
      frames,
    );
  }
  return result;
}

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

HCVDisplayRiskResult _strongBase() => const HCVDisplayRiskResult(
  risk: 'HIGH',
  score: 96,
  decision: 'STRONG_DISPLAY_RISK',
  analysisStatus: 'COMPLETE',
  evidenceSources: <String>['ML_SCREEN_CLASS'],
  strongSources: <String>['ML_SCREEN_CLASS'],
  reasons: <String>[
    'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
    'ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION',
  ],
);

HCVDisplayRiskResult _resolve(Map<String, dynamic> ml, {bool mixed = false}) =>
    HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: _strongBase(),
      passiveOptical: null,
      ml: ml,
      temporalFrequencyProbe: _quietV32(mixed: mixed),
    );

void main() {
  test(
    'four-frame stable PHOTO-like sequence prevents false full-frame veto',
    () {
      final frames = <Map<String, dynamic>>[
        _frame(
          index: 0,
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.96,
          fullFrame: 96,
          contentArea: 82,
        ),
        _frame(
          index: 1,
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.95,
          fullFrame: 95,
          contentArea: 80,
        ),
        _frame(
          index: 2,
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.94,
          fullFrame: 94,
          contentArea: 77,
        ),
        _frame(
          index: 3,
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.93,
          fullFrame: 93,
          contentArea: 60,
        ),
      ];

      final result = _resolve(_ml(frames));
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.evidenceSources,
        contains('VIDEO_PHOTO_SPATIAL_CORROBORATION'),
      );
      expect(
        result.reasons,
        contains('VIDEO_PHOTO_SPATIAL_STABLE_SCREEN_SEQUENCE'),
      );
      expect(
        result.reasons,
        contains('VIDEO_PHOTO_SPATIAL_FULL_FRAME_CORROBORATION'),
      );
      expect(
        result.reasons,
        isNot(contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE')),
      );
    },
  );

  test('absence of the new evidence preserves BUILD109 behavior', () {
    final frames = <Map<String, dynamic>>[
      _frame(
        index: 0,
        predictedClass: 'SCREEN_MONITOR',
        probability: 0.96,
        fullFrame: 96,
        contentArea: 82,
      ),
      _frame(
        index: 1,
        predictedClass: 'SCREEN_MONITOR',
        probability: 0.95,
        fullFrame: 95,
        contentArea: 80,
      ),
      _frame(
        index: 2,
        predictedClass: 'SCREEN_MONITOR',
        probability: 0.94,
        fullFrame: 94,
        contentArea: 77,
      ),
      _frame(
        index: 3,
        predictedClass: 'SCREEN_MONITOR',
        probability: 0.93,
        fullFrame: 93,
        contentArea: 60,
      ),
    ];

    final result = _resolve(_ml(frames, includePhotoSpatial: false));
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'),
    );
    expect(
      result.evidenceSources,
      isNot(contains('VIDEO_PHOTO_SPATIAL_CORROBORATION')),
    );
  });

  test(
    'SCREEN to REALITY transition can never activate PHOTO-like promotion',
    () {
      final frames = <Map<String, dynamic>>[
        _frame(
          index: 0,
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.96,
          fullFrame: 96,
          contentArea: 82,
        ),
        _frame(
          index: 1,
          predictedClass: 'REALITY_ROOM',
          probability: 0.05,
          fullFrame: 8,
          contentArea: 10,
        ),
        _frame(
          index: 2,
          predictedClass: 'REALITY_ROOM',
          probability: 0.03,
          fullFrame: 6,
          contentArea: 8,
        ),
        _frame(
          index: 3,
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.94,
          fullFrame: 94,
          contentArea: 80,
        ),
      ];
      final ml = _ml(frames);
      final evidence = ml['videoPhotoSpatialEvidence'] as Map;
      expect(evidence['sceneTransitionDetected'], true);
      expect(evidence['stableFullFrameScreenCorroboration'], false);

      final result = _resolve(ml);
      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
      expect(
        result.evidenceSources,
        isNot(contains('VIDEO_PHOTO_SPATIAL_CORROBORATION')),
      );
    },
  );

  test('mixed-scene HFR veto remains absolute', () {
    final frames = <Map<String, dynamic>>[
      for (var i = 0; i < 4; i++)
        _frame(
          index: i,
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.96,
          fullFrame: 96,
          contentArea: 82,
        ),
    ];

    final result = _resolve(_ml(frames), mixed: true);
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('HFR_V3_MIXED_REAL_SCENE'));
    expect(
      result.evidenceSources,
      isNot(contains('VIDEO_PHOTO_SPATIAL_CORROBORATION')),
    );
  });
}
