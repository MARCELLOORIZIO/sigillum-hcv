import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

bool qualifies({
  double modulation = 0.5388,
  double spectral = 0.8926,
  double periodicity = 0.1704,
  double stability = 0.9639,
  double phase = 0.5132,
  int periodicCells = 8,
  int stableCells = 7,
  int displayLikeCells = 7,
  int harmonicFamilyCells = 9,
  int rowTimeFamilyCells = 9,
  double rowTimeCoherence = 0.825,
  int corroborationStages = 2,
}) {
  return HCVTemporalFrequencyProbe.qualifiesLowModulationCorroboratedGlobalHfrBuild109(
    actualFps: 240.6256,
    framesAnalyzed: 84,
    shortExposureVerified: true,
    exposureLocked: true,
    dominantTemporalFrequencyHz: 100.2597,
    globalModulationDepth: modulation,
    globalSpectralConcentration: spectral,
    medianCellPeriodicityStrength: periodicity,
    medianCellFrequencyStability: stability,
    medianCellPhaseStepConsistency: phase,
    periodicCellCount: periodicCells,
    stableCellCount: stableCells,
    displayLikeCellCount: displayLikeCells,
    harmonicAwareSpatialFamilyCellCount: harmonicFamilyCells,
    rowTimeFamilyCellCount: rowTimeFamilyCells,
    medianRowTimeCoherence: rowTimeCoherence,
    exposureCorroborationStageCount: corroborationStages,
  );
}

void main() {
  test(
    'BUILD109 recovers the archived low-modulation full-frame signature',
    () {
      expect(qualifies(), isTrue);
    },
  );

  test('BUILD109 recovery is bounded below by 0.50 modulation', () {
    expect(qualifies(modulation: 0.4999), isFalse);
  });

  test('BUILD109 recovery does not replace the normal >=0.75 HFR gate', () {
    expect(qualifies(modulation: 0.75), isFalse);
    expect(
      HCVTemporalFrequencyProbe.qualifiesHarmonicRecoveredGlobalHfrV32(
        actualFps: 240.6256,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.2597,
        globalModulationDepth: 0.5388,
        globalSpectralConcentration: 0.8926,
        medianCellPeriodicityStrength: 0.1704,
        medianCellFrequencyStability: 0.9639,
        medianCellPhaseStepConsistency: 0.5132,
        periodicCellCount: 8,
      ),
      isFalse,
    );
  });

  test('BUILD109 requires all nine harmonic-aware spatial cells', () {
    expect(qualifies(harmonicFamilyCells: 8), isFalse);
  });

  test('BUILD109 requires all nine row-time family cells', () {
    expect(qualifies(rowTimeFamilyCells: 8), isFalse);
  });

  test('BUILD109 requires strong row-time coherence', () {
    expect(qualifies(rowTimeCoherence: 0.7499), isFalse);
  });

  test('BUILD109 requires seven stable cells', () {
    expect(qualifies(stableCells: 6), isFalse);
  });

  test('BUILD109 requires seven display-like cells', () {
    expect(qualifies(displayLikeCells: 6), isFalse);
  });

  test('BUILD109 requires two corroborating short-exposure stages', () {
    expect(qualifies(corroborationStages: 1), isFalse);
  });

  test('BUILD109 keeps independent spectral and temporal gates strong', () {
    expect(qualifies(spectral: 0.8499), isFalse);
    expect(qualifies(periodicity: 0.1199), isFalse);
    expect(qualifies(stability: 0.7999), isFalse);
    expect(qualifies(phase: 0.3999), isFalse);
    expect(qualifies(periodicCells: 5), isFalse);
  });
}
