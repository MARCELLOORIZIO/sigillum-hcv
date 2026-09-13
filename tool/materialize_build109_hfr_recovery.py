from pathlib import Path

TARGET = Path('lib/hcv_temporal_frequency_probe.dart')
TEST = Path('test/build109_low_modulation_hfr_recovery_test.dart')

text = TARGET.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text = text.replace(old, new, 1)


old_helper = """    return globalModulationDepth >= 0.75 &&
        globalSpectralConcentration >= 0.85 &&
        medianCellPeriodicityStrength >= 0.12 &&
        medianCellFrequencyStability >= 0.80 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6;
  }

  static bool qualifiesNoTemporalDisplaySignatureV31({
"""
new_helper = """    return globalModulationDepth >= 0.75 &&
        globalSpectralConcentration >= 0.85 &&
        medianCellPeriodicityStrength >= 0.12 &&
        medianCellFrequencyStability >= 0.80 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6;
  }

  // BUILD109: narrow recovery for a physically corroborated full-frame display
  // whose global modulation falls below the validated 0.75 production gate.
  // This does not lower the normal HFR threshold: it only admits the 0.50-0.75
  // band when several independent spatial, row-time and exposure axes agree.
  static bool qualifiesLowModulationCorroboratedGlobalHfrBuild109({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required double? dominantTemporalFrequencyHz,
    required double globalModulationDepth,
    required double globalSpectralConcentration,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int periodicCellCount,
    required int stableCellCount,
    required int displayLikeCellCount,
    required int harmonicAwareSpatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
    required int exposureCorroborationStageCount,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    if (dominantTemporalFrequencyHz == null ||
        dominantTemporalFrequencyHz < 40.0 ||
        dominantTemporalFrequencyHz > 120.0 ||
        dominantTemporalFrequencyHz > actualFps / 2.0 + 1.0) {
      return false;
    }
    return globalModulationDepth >= 0.50 &&
        globalModulationDepth < 0.75 &&
        globalSpectralConcentration >= 0.85 &&
        medianCellPeriodicityStrength >= 0.12 &&
        medianCellFrequencyStability >= 0.80 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6 &&
        stableCellCount >= 7 &&
        displayLikeCellCount >= 7 &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.75 &&
        exposureCorroborationStageCount >= 2;
  }

  static bool qualifiesNoTemporalDisplaySignatureV31({
"""
replace_once(old_helper, new_helper, 'insert BUILD109 low-modulation helper')

old_runtime = """    final harmonicExposureCorroborated =
        advancedPhysicsV32['harmonicRecoveryExposureCorroborated'] == true;
    final harmonicFullFrameDisplayRecovery =
        !strictFullFrameDisplayV3 &&
        harmonicRecoveryGlobalHfrCandidate &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20 &&
        harmonicExposureCorroborated;
    final fullFrameDisplayV3 =
        strictFullFrameDisplayV3 || harmonicFullFrameDisplayRecovery;
"""
new_runtime = """    final harmonicExposureCorroborated =
        advancedPhysicsV32['harmonicRecoveryExposureCorroborated'] == true;
    final harmonicRecoveryCorroborationStageCount =
        (advancedPhysicsV32['harmonicRecoveryCorroborationStageCount'] as num?)
                ?.toInt() ??
            0;
    final harmonicFullFrameDisplayRecovery =
        !strictFullFrameDisplayV3 &&
        harmonicRecoveryGlobalHfrCandidate &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20 &&
        harmonicExposureCorroborated;
    final lowModulationDisplayRecoveryBuild109 =
        !strictFullFrameDisplayV3 &&
        !harmonicFullFrameDisplayRecovery &&
        qualifiesLowModulationCorroboratedGlobalHfrBuild109(
          actualFps: actualFps,
          framesAnalyzed: acceptedFrames,
          shortExposureVerified: raw['shortExposureVerified'] == true,
          exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
          dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
          globalModulationDepth: globalModulationDepth,
          globalSpectralConcentration: globalSpectralConcentration,
          medianCellPeriodicityStrength: medianCellPeriodicity,
          medianCellFrequencyStability: medianCellStability,
          medianCellPhaseStepConsistency: medianCellPhase,
          periodicCellCount: periodicCellCount,
          stableCellCount: stableCellCount,
          displayLikeCellCount: displayLikeCellCount,
          harmonicAwareSpatialFamilyCellCount:
              harmonicAwareSpatialFamilyCellCount,
          rowTimeFamilyCellCount: rowTimeFamilyCellCount,
          medianRowTimeCoherence: medianRowTimeCoherence,
          exposureCorroborationStageCount:
              harmonicRecoveryCorroborationStageCount,
        );
    final fullFrameDisplayV3 = strictFullFrameDisplayV3 ||
        harmonicFullFrameDisplayRecovery ||
        lowModulationDisplayRecoveryBuild109;
"""
replace_once(old_runtime, new_runtime, 'wire BUILD109 low-modulation recovery')

old_evidence = """        'harmonicRecoveryGlobalHfrCandidateV32': harmonicRecoveryGlobalHfrCandidate,
        'harmonicFullFrameDisplayRecoveryV32': harmonicFullFrameDisplayRecovery,
        'harmonicRecoveryExposureCorroboratedV32': harmonicExposureCorroborated,
        'harmonicAwareSpatialFamilyCellCount': harmonicAwareSpatialFamilyCellCount,
"""
new_evidence = """        'harmonicRecoveryGlobalHfrCandidateV32': harmonicRecoveryGlobalHfrCandidate,
        'harmonicFullFrameDisplayRecoveryV32': harmonicFullFrameDisplayRecovery,
        'harmonicRecoveryExposureCorroboratedV32': harmonicExposureCorroborated,
        'harmonicRecoveryCorroborationStageCountV32':
            harmonicRecoveryCorroborationStageCount,
        'lowModulationDisplayRecoveryBuild109':
            lowModulationDisplayRecoveryBuild109,
        'harmonicAwareSpatialFamilyCellCount': harmonicAwareSpatialFamilyCellCount,
"""
replace_once(old_evidence, new_evidence, 'publish BUILD109 evidence')

old_reality = """        'medianRowTimeCoherence': medianRowTimeCoherence,
        'harmonicDisplayRecovery': harmonicFullFrameDisplayRecovery,
        'displayFamilyMode': harmonicFullFrameDisplayRecovery
            ? 'HARMONIC_2_TO_1_CORROBORATED'
            : 'STRICT_SINGLE_FAMILY',
        'classificationPolicy':
            'BUILD108_VALIDATED_V3_DISPLAY_PRESERVED;HARMONIC_2_TO_1_REQUIRES_GLOBAL_HFR_PLUS_ROW_TIME_9_OF_9_PLUS_TWO_SHORT_EXPOSURE_CORROBORATIONS;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',
"""
new_reality = """        'medianRowTimeCoherence': medianRowTimeCoherence,
        'harmonicDisplayRecovery': harmonicFullFrameDisplayRecovery,
        'lowModulationDisplayRecoveryBuild109':
            lowModulationDisplayRecoveryBuild109,
        'displayFamilyMode': harmonicFullFrameDisplayRecovery
            ? 'HARMONIC_2_TO_1_CORROBORATED'
            : lowModulationDisplayRecoveryBuild109
                ? 'LOW_MODULATION_MULTI_AXIS_CORROBORATED'
                : 'STRICT_SINGLE_FAMILY',
        'classificationPolicy':
            'BUILD109_VALIDATED_V3_DISPLAY_PRESERVED;LOW_MODULATION_0_50_TO_0_75_REQUIRES_HARMONIC_SPATIAL_9_OF_9_PLUS_ROW_TIME_9_OF_9_PLUS_STRONG_ROW_COHERENCE_PLUS_TWO_SHORT_EXPOSURE_CORROBORATIONS;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',
"""
replace_once(old_reality, new_reality, 'publish BUILD109 display family mode')

TARGET.write_text(text)

TEST.write_text("""import 'package:flutter_test/flutter_test.dart';
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
  return HCVTemporalFrequencyProbe
      .qualifiesLowModulationCorroboratedGlobalHfrBuild109(
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
  test('BUILD109 recovers the archived low-modulation full-frame signature', () {
    expect(qualifies(), isTrue);
  });

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
""")

print('BUILD109 HFR materialization applied exactly once')
