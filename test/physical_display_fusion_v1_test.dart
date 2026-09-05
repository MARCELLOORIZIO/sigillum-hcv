import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_physical_display_fusion.dart';

const noDisplay = HCVDisplayRiskResult(
    risk: 'LOW',
    score: 4,
    decision: 'NO_DISPLAY_EVIDENCE',
    analysisStatus: 'COMPLETE',
    evidenceSources: ['ML_REALITY_CLASS'],
    strongSources: [],
    reasons: ['LIVE_PROBE_MISSING']);
const mlStrong = HCVDisplayRiskResult(
    risk: 'HIGH',
    score: 85,
    decision: 'STRONG_DISPLAY_RISK',
    analysisStatus: 'COMPLETE',
    evidenceSources: ['ML_SCREEN_CLASS'],
    strongSources: ['ML_SCREEN_CLASS'],
    reasons: ['ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY']);

Map<String, dynamic> hfr(
        {double p = .24, double s = .94, double phase = .68, double c = .90}) =>
    {
      'analysisStatus': 'ANALYZED',
      'medianCellPeriodicityStrength': p,
      'medianCellFrequencyStability': s,
      'medianCellPhaseStepConsistency': phase,
      'globalFrameLumaTemporalSpectrum': {'temporalSpectralConcentration': c},
    };
Map<String, dynamic> reflect(bool strong) => {
      'analysisStatus': 'ANALYZED',
      'strongReflectiveResponseCandidate': strong,
      'medianCellRelativeTorchResponse': strong ? .55 : .08,
      'reflectiveCellsAt20Percent': strong ? 8 : 1,
      'medianCellReversibility': strong ? .85 : .20,
    };

void main() {
  test('strong HFR rescues ML false negative', () {
    final r = HCVPhysicalDisplayFusion.apply(
        baseline: noDisplay,
        temporalFrequencyProbe: hfr(),
        illuminationResponseProbe: reflect(false),
        hardDisplayCorroboration: false);
    expect(r.decision, 'STRONG_DISPLAY_RISK');
    expect(r.reasons, contains('PHYSICAL_HFR_DISPLAY_RESCUE_V1'));
    expect(r.reasons, isNot(contains('LIVE_PROBE_MISSING')));
  });

  test('strong reflection demotes uncorroborated ML display', () {
    final r = HCVPhysicalDisplayFusion.apply(
        baseline: mlStrong,
        temporalFrequencyProbe: hfr(p: .01, s: .2, phase: .2, c: .4),
        illuminationResponseProbe: reflect(true),
        hardDisplayCorroboration: false);
    expect(r.decision, 'NON_CONCLUSIVE');
    expect(
        r.reasons,
        contains(
            'REFLECTIVE_ILLUMINATION_RESPONSE_BLOCKS_UNCORROBORATED_DISPLAY_WARNING'));
  });

  test('reflection cannot veto hard display corroboration', () {
    final r = HCVPhysicalDisplayFusion.apply(
        baseline: mlStrong,
        temporalFrequencyProbe: hfr(p: .01, s: .2, phase: .2, c: .4),
        illuminationResponseProbe: reflect(true),
        hardDisplayCorroboration: true);
    expect(r.decision, 'STRONG_DISPLAY_RISK');
  });
}
