import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _frame(double p, int full, int content) => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': p,
      'screenProbability': p,
      'screenReplayRiskScore': (p * 100).round(),
      'signals': <String, dynamic>{
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
      },
    };

Map<String, dynamic> _temporal(List<Map<String, dynamic>> frames) => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frames.length,
      'strongScreenFrameCount': frames.length,
      'mediumScreenFrameCount': frames.length,
      'averageScreenReplayRiskScore': frames
              .map((e) => (e['screenReplayRiskScore'] as num).toDouble())
              .reduce((a, b) => a + b) /
          frames.length,
      'videoFrameAnalyses': frames,
    };

Map<String, dynamic> _still(double p, int full, int content) => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': p,
      'screenReplayRiskScore': (p * 100).round(),
      'signals': <String, dynamic>{
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
      },
    };

Map<String, dynamic> _quietHfr() => <String, dynamic>{
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
        'positivePhysicalRealityEvidence': false,
        'mixedSceneDetected': false,
        'allNineCellsSameDisplayFamily': false,
        'displayLikeCellCount': 0,
        'spatialFamilyCellCount': 0,
        'harmonicAwareSpatialFamilyCellCount': 0,
        'rowTimeFamilyCellCount': 0,
      },
    };

const base = HCVDisplayRiskResult(
  risk: 'HIGH',
  score: 97,
  decision: 'STRONG_DISPLAY_RISK',
  analysisStatus: 'COMPLETE',
  evidenceSources: <String>['ML_SCREEN_CLASS'],
  strongSources: <String>['ML_SCREEN_CLASS'],
  reasons: <String>[
    'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
    'ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION',
  ],
);

HCVDisplayRiskResult _resolve(Map<String, dynamic> still, Map<String, dynamic> temporal) =>
    HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: null,
      ml: still,
      temporalFrequencyProbe: _quietHfr(),
      photoTemporalMl: temporal,
    );

void main() {
  test('C546 BUILD110 monitor case remains HIGH', () {
    final r = _resolve(
      _still(0.932, 93, 87),
      _temporal(<Map<String, dynamic>>[
        _frame(0.95, 95, 71),
        _frame(0.95, 95, 79),
        _frame(0.92, 92, 73),
      ]),
    );
    expect(r.decision, 'STRONG_DISPLAY_RISK');
    expect(r.risk, 'HIGH');
    expect(r.reasons, contains('PHOTO_STILL_STRONG_SCREEN_WITH_TEMPORAL_SCREEN_SEQUENCE'));
    expect(r.reasons, isNot(contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE')));
  });

  test('F776 BUILD110 monitor case remains HIGH', () {
    final r = _resolve(
      _still(0.9732, 97, 92),
      _temporal(<Map<String, dynamic>>[
        _frame(0.98, 98, 75),
        _frame(0.93, 93, 74),
        _frame(0.92, 92, 73),
      ]),
    );
    expect(r.decision, 'STRONG_DISPLAY_RISK');
    expect(r.risk, 'HIGH');
  });

  test('weak later photo diagnostics cannot erase inherited strong evidence', () {
    final r = _resolve(
      _still(0.91, 91, 70),
      _temporal(<Map<String, dynamic>>[
        _frame(0.95, 95, 71),
        _frame(0.94, 94, 74),
        _frame(0.93, 93, 73),
      ]),
    );
    expect(r.decision, 'STRONG_DISPLAY_RISK');
    expect(
      r.reasons,
      isNot(contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE')),
    );
  });
}
