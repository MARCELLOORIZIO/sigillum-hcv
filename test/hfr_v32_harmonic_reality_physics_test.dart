import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  test('BUILD108 treats a strict 2:1 row harmonic as one physical family', () {
    expect(
      HCVTemporalFrequencyProbe.harmonicAwareModalBinCount(
        const [2, 2, 2, 4, 2, 2, 2, 2, 2],
      ),
      9,
    );
  });

  test('BUILD108 harmonic global HFR keeps strong global gates', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesHarmonicRecoveredGlobalHfrV32(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.2607,
        globalModulationDepth: 1.313,
        globalSpectralConcentration: 0.921,
        medianCellPeriodicityStrength: 0.162,
        medianCellFrequencyStability: 0.819,
        medianCellPhaseStepConsistency: 0.661,
        periodicCellCount: 8,
      ),
      isTrue,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesHarmonicRecoveredGlobalHfrV32(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 5.7,
        globalModulationDepth: 0.03,
        globalSpectralConcentration: 0.20,
        medianCellPeriodicityStrength: 0.01,
        medianCellFrequencyStability: 0.30,
        medianCellPhaseStepConsistency: 0.20,
        periodicCellCount: 0,
      ),
      isFalse,
    );
  });

  test('fusion accepts V3.2 corroborated harmonic full-frame display', () {
    const base = HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: const <String, dynamic>{},
      ml: const <String, dynamic>{'analysisStatus': 'NOT_ANALYZED'},
      temporalFrequencyProbe: const <String, dynamic>{
        'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
        'analysisStatus': 'ANALYZED',
        'coherentDisplayPeriodicity': true,
        'shortExposureVerified': true,
        'exposureLockedForEntireNativeCapture': true,
        'framesAnalyzed': 84,
        'actualFrameRateFromTimestamps': 240.62,
        'displayRealityEvidenceV3': <String, dynamic>{
          'fullFrameDisplay': true,
          'mixedSceneDetected': false,
          'allNineCellsSameDisplayFamily': true,
          'spatialFamilyCellCount': 8,
          'harmonicAwareSpatialFamilyCellCount': 9,
          'rowTimeFamilyCellCount': 9,
          'harmonicDisplayRecovery': true,
        },
      },
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, greaterThanOrEqualTo(95));
  });
}
