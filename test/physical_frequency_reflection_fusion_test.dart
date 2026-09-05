import 'package:flutter_test/flutter_test.dart';

import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_physical_display_evidence.dart';

Map<String, dynamic> _hfr({
  required double periodicity,
  required double stability,
  required double phase,
  required double modulation,
  required double spectral,
  int periodicCells = 0,
  int stableCells = 0,
  int phaseCells = 0,
}) {
  final cells = List.generate(9, (i) {
    return {
      'periodicityStrength': i < periodicCells ? 0.20 : periodicity,
      'dominantFrequencyStability': i < stableCells ? 0.90 : stability,
      'phaseStepConsistency': i < phaseCells ? 0.70 : phase,
    };
  });
  return {
    'analysisStatus': 'ANALYZED',
    'actualFrameRateFromTimestamps': 240.62,
    'shortExposureVerified': true,
    'framesAnalyzed': 84,
    'medianCellPeriodicityStrength': periodicity,
    'medianCellFrequencyStability': stability,
    'medianCellPhaseStepConsistency': phase,
    'globalFrameLumaTemporalSpectrum': {
      'robustFrameLumaModulationDepth': modulation,
      'temporalSpectralConcentration': spectral,
    },
    'cellResults': cells,
  };
}

HCVDisplayRiskResult _result({
  required String decision,
  required int score,
  List<String> strongSources = const [],
  List<String> reasons = const [],
}) {
  return HCVDisplayRiskResult(
    risk: decision == 'STRONG_DISPLAY_RISK'
        ? 'HIGH'
        : decision == 'NON_CONCLUSIVE'
            ? 'MEDIUM'
            : 'LOW',
    score: score,
    decision: decision,
    analysisStatus: 'COMPLETE',
    evidenceSources: strongSources,
    strongSources: strongSources,
    reasons: reasons,
  );
}

void main() {
  test('BUILD92 missed TV is rescued by strong 240 fps periodic signature', () {
    final probe = _hfr(
      periodicity: 0.23,
      stability: 0.93,
      phase: 0.64,
      modulation: 0.63,
      spectral: 0.91,
      periodicCells: 9,
      stableCells: 9,
      phaseCells: 8,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(decision: 'NO_DISPLAY_EVIDENCE', score: 20),
      mlAnalysis: {'screenProbability': 0.56},
      temporalFrequencyProbe: probe,
      illuminationResponseProbe: null,
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'STRONG_DISPLAY_RISK');
    expect(out.strongSources, contains('NATIVE_HFR_FREQUENCY_SIGNATURE'));
  });

  test(
      'BUILD92 reflective false positive becomes non-conclusive when HFR is quiet',
      () {
    final quiet = _hfr(
      periodicity: 0.007,
      stability: 0.23,
      phase: 0.18,
      modulation: 0.03,
      spectral: 0.50,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(
        decision: 'STRONG_DISPLAY_RISK',
        score: 85,
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: const [
          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
          'LIVE_PROBE_MISSING',
        ],
      ),
      mlAnalysis: {'screenProbability': 0.855},
      temporalFrequencyProbe: quiet,
      illuminationResponseProbe: null,
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'NON_CONCLUSIVE');
    expect(out.reasons, isNot(contains('LIVE_PROBE_MISSING')));
    expect(
      out.reasons,
      contains('ML_ONLY_DISPLAY_CONFLICTS_WITH_ELECTRONICALLY_QUIET_HFR'),
    );
  });

  test(
      'BUILD92 true monitor with temporal modulation is not vetoed by quiet rule',
      () {
    final monitor = _hfr(
      periodicity: 0.009,
      stability: 0.23,
      phase: 0.285,
      modulation: 0.166,
      spectral: 0.727,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(
        decision: 'STRONG_DISPLAY_RISK',
        score: 85,
        strongSources: const ['ML_SCREEN_CLASS'],
      ),
      mlAnalysis: {'screenProbability': 0.848},
      temporalFrequencyProbe: monitor,
      illuminationResponseProbe: null,
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'STRONG_DISPLAY_RISK');
  });

  test('strong reflective response can conflict with medium ML-only display',
      () {
    final nonStrongHfr = _hfr(
      periodicity: 0.04,
      stability: 0.55,
      phase: 0.40,
      modulation: 0.12,
      spectral: 0.70,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(
        decision: 'STRONG_DISPLAY_RISK',
        score: 84,
        strongSources: const ['ML_SCREEN_CLASS'],
      ),
      mlAnalysis: {'screenProbability': 0.84},
      temporalFrequencyProbe: nonStrongHfr,
      illuminationResponseProbe: {
        'analysisStatus': 'ANALYZED',
        'measurementQualitySufficient': true,
        'strongReflectiveResponse': true,
      },
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'NON_CONCLUSIVE');
    expect(
      out.reasons,
      contains('ML_ONLY_DISPLAY_CONFLICTS_WITH_STRONG_REFLECTIVE_RESPONSE'),
    );
  });

  test('very high ML confidence is not vetoed by reflection conflict support',
      () {
    final quiet = _hfr(
      periodicity: 0.007,
      stability: 0.23,
      phase: 0.18,
      modulation: 0.03,
      spectral: 0.50,
    );
    final out = HCVPhysicalDisplayEvidence.apply(
      baseline: _result(
        decision: 'STRONG_DISPLAY_RISK',
        score: 99,
        strongSources: const ['ML_SCREEN_CLASS'],
      ),
      mlAnalysis: {'screenProbability': 0.996},
      temporalFrequencyProbe: quiet,
      illuminationResponseProbe: {
        'analysisStatus': 'ANALYZED',
        'measurementQualitySufficient': true,
        'strongReflectiveResponse': true,
      },
      hardDisplayCorroboration: false,
    );
    expect(out.decision, 'STRONG_DISPLAY_RISK');
  });
}
