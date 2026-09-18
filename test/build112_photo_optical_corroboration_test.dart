import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _frame({
  required double probability,
  required int risk,
  required int fullFrame,
  required int contentArea,
  String predictedClass = 'SCREEN_MONITOR',
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': predictedClass,
      'screenProbability': probability,
      'screenReplayRiskScore': risk,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

Map<String, dynamic> _temporal(List<Map<String, dynamic>> frames) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frames.length,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 1,
      'averageScreenReplayRiskScore': frames
              .map((e) => (e['screenReplayRiskScore'] as num).toDouble())
              .reduce((a, b) => a + b) /
          frames.length,
      'videoFrameAnalyses': frames,
    };

Map<String, dynamic> _still({
  double probability = 0.895,
  int risk = 89,
  int fullFrame = 89,
  int contentArea = 94,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'screenReplayRiskScore': risk,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

Map<String, dynamic> _optical({
  String risk = 'HIGH',
  int score = 80,
  bool strongDisplayTrace = true,
  bool temporalScreenPulse = true,
  bool localRefreshFlicker = true,
}) =>
    <String, dynamic>{
      'captureSource': 'PHOTO_TECHNICAL_MINI_VIDEO_V2',
      'screenReplayRisk': risk,
      'screenReplayRiskScore': score,
      'signals': <String, dynamic>{
        'strongDisplayTrace': strongDisplayTrace,
        'temporalScreenPulse': temporalScreenPulse,
        'localRefreshFlicker': localRefreshFlicker,
      },
    };

Map<String, dynamic> _stillOptical({
  int score = 20,
  bool structuralDisplayTrace = false,
  bool strongDisplayTrace = false,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRisk': score >= 70 ? 'HIGH' : 'LOW',
      'screenReplayRiskScore': score,
      'signals': <String, dynamic>{
        'structuralDisplayTrace': structuralDisplayTrace,
        'strongDisplayTrace': strongDisplayTrace,
      },
    };

Map<String, dynamic> _quietHfr({
  bool mixedScene = false,
  bool positivePhysicalReality = false,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.0,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'fullFrameReality': false,
        'positivePhysicalRealityEvidence': positivePhysicalReality,
        'mixedSceneDetected': mixedScene,
        'allNineCellsSameDisplayFamily': false,
        'displayLikeCellCount': 0,
        'spatialFamilyCellCount': 0,
        'harmonicAwareSpatialFamilyCellCount': 0,
        'rowTimeFamilyCellCount': 0,
      },
    };

const _baseA6 = HCVDisplayRiskResult(
  risk: 'MEDIUM',
  score: 45,
  decision: 'NON_CONCLUSIVE',
  analysisStatus: 'COMPLETE',
  evidenceSources: <String>[],
  strongSources: <String>[],
  reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
);

HCVDisplayRiskResult _resolve({
  Map<String, dynamic>? still,
  Map<String, dynamic>? temporal,
  Map<String, dynamic>? optical,
  Map<String, dynamic>? hfr,
}) =>
    HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: _baseA6,
      passiveOptical: _stillOptical(),
      ml: still ?? _still(),
      temporalFrequencyProbe: hfr ?? _quietHfr(),
      photoTemporalMl: temporal ??
          _temporal(<Map<String, dynamic>>[
            _frame(probability: 0.8801, risk: 88, fullFrame: 88, contentArea: 77),
            _frame(probability: 0.8293, risk: 83, fullFrame: 83, contentArea: 72),
            _frame(probability: 0.8109, risk: 81, fullFrame: 81, contentArea: 84),
          ]),
      photoTemporalOptical: optical ?? _optical(),
    );

void main() {
  test('A6 BUILD111 physical monitor sample is recovered as HIGH', () {
    final result = _resolve();

    expect(result.risk, 'HIGH');
    expect(result.score, 89);
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(
      result.evidenceSources,
      contains('PHOTO_MODERATE_SCREEN_OPTICAL_CORROBORATION'),
    );
    expect(
      result.reasons,
      contains('PHOTO_OPTICAL_REFRESH_TRACE_CORROBORATES_SCREEN'),
    );
  });

  test('same ML semantics without optical refresh trace stay non-HIGH', () {
    final result = _resolve(
      optical: _optical(
        risk: 'LOW',
        score: 20,
        strongDisplayTrace: false,
        temporalScreenPulse: false,
        localRefreshFlicker: false,
      ),
    );

    expect(result.risk, isNot('HIGH'));
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('HFR mixed coverage alone is not positive REALITY evidence', () {
    final result = _resolve(hfr: _quietHfr(mixedScene: true));

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
    expect(result.reasons, isNot(contains('HFR_V3_MIXED_REAL_SCENE')));
  });

  test('positive physical reality veto blocks A6 recovery', () {
    final result = _resolve(
      hfr: _quietHfr(positivePhysicalReality: true),
    );

    expect(result.risk, isNot('HIGH'));
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('one temporal frame below full-frame 80 blocks recovery', () {
    final result = _resolve(
      temporal: _temporal(<Map<String, dynamic>>[
        _frame(probability: 0.8801, risk: 88, fullFrame: 88, contentArea: 77),
        _frame(probability: 0.8293, risk: 83, fullFrame: 79, contentArea: 72),
        _frame(probability: 0.8109, risk: 81, fullFrame: 81, contentArea: 84),
      ]),
    );

    expect(result.risk, isNot('HIGH'));
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });
}
