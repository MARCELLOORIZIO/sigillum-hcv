import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

HCVDisplayRiskResult unresolved() => const HCVDisplayRiskResult(
  risk: 'MEDIUM',
  score: 45,
  decision: 'NON_CONCLUSIVE',
  analysisStatus: 'PARTIAL',
  evidenceSources: <String>[],
  strongSources: <String>[],
  reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
);

Map<String, dynamic> cleanOptical() => <String, dynamic>{
  'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
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
  },
};

Map<String, dynamic> hfr({required bool coherent, bool reality = false}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': coherent,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'dominantTemporalFrequencyHz': reality ? 2.86 : 100.26,
        'medianCellPeriodicityStrength': reality ? 0.007 : 0.27,
        'medianCellFrequencyStability': reality ? 0.22 : 0.99,
        'medianCellPhaseStepConsistency': reality ? 0.28 : 0.64,
        'periodicCellCount': reality ? 0 : 9,
        'stableCellCount': reality ? 0 : 8,
      },
    };

Map<String, dynamic> temporal(
  List<double> probabilities, {
  int fullFrameRiskScore = 96,
  int contentAreaRiskScore = 95,
}) => <String, dynamic>{
  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'framesAnalyzed': probabilities.length,
  'videoFrameAnalyses': <Map<String, dynamic>>[
    for (var i = 0; i < probabilities.length; i++)
      <String, dynamic>{
        'videoFrameIndex': i,
        'screenProbability': probabilities[i],
        'signals': <String, dynamic>{
          'fullFrameRiskScore': fullFrameRiskScore,
          'contentAreaRiskScore': contentAreaRiskScore,
        },
      },
  ],
};

void main() {
  test('strict coherent HFR is active DISPLAY evidence', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.01, 0.02]),
      temporalFrequencyProbe: hfr(coherent: true),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('HFR_V3_ALL_NINE_CELLS_ONE_DISPLAY_FAMILY'));
  });

  test('two high temporal screen samples are active DISPLAY evidence', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.98, 0.97]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES'));
  });

  test('BUILD102-like reality signature resolves NON_CONCLUSIVE to reality', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.7414, 0.0204, 0.7886, 0.0055]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
    expect(result.reasons, contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE'));
  });

  test('three-sample fast photo monitor remains DISPLAY', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: <String, dynamic>{'analysisStatus': 'ANALYZED'},
      photoTemporalMl: temporal(<double>[0.9599, 0.9784, 0.9625]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });

  test('one isolated high screen sample does not become DISPLAY', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.95, 0.20, 0.30]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('hard optical display trace prevents reality override', () {
    final optical = cleanOptical();
    (optical['signals'] as Map<String, dynamic>)['horizontalRefreshBands'] = true;
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: optical,
      ml: temporal(<double>[0.20, 0.30, 0.40]),
      temporalFrequencyProbe: hfr(coherent: false, reality: true),
    );
    expect(identical(result, base), isTrue);
  });

  test('incomplete HFR cannot create reality evidence', () {
    final incomplete = hfr(coherent: false, reality: true)..['framesAnalyzed'] = 20;
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: temporal(<double>[0.20, 0.30, 0.40]),
      temporalFrequencyProbe: incomplete,
    );
    expect(identical(result, base), isTrue);
  });
}
