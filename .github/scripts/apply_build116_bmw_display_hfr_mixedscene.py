from pathlib import Path

source_path = Path('lib/hcv_temporal_frequency_probe.dart')
source = source_path.read_text()

old = """    final fullFrameDisplayV3 =
        strictFullFrameDisplayV3 ||
        harmonicFullFrameDisplayRecovery ||
        lowModulationDisplayRecoveryBuild109;
    final allNineCellsSameDisplayFamily =
        fullFrameDisplayV3 &&
        rowTimeFamilyCellCount == 9 &&
        (spatialFamilyCellCount == 9 ||
            harmonicAwareSpatialFamilyCellCount == 9);
    final mixedSceneDetected = displayLikeCellCount > 0 && !fullFrameDisplayV3;
"""
new = """    // BUILD116: some modern automotive panels can expose a coherent display
    // signature in every 3x3 cell while their global frame-luma spectrum stays
    // below the legacy 40 Hz gate. Recover only the strongest display-only
    // case: all nine cells must independently look display-like, all nine must
    // be periodic and stable, and both spatial + row-time coverage must span
    // the complete grid. This is deliberately narrower than the normal V3
    // display-family rule and cannot fire for a TV/monitor embedded in a room.
    final displayOnlyFullGridRecoveryBuild116 =
        !strictFullFrameDisplayV3 &&
        !harmonicFullFrameDisplayRecovery &&
        !lowModulationDisplayRecoveryBuild109 &&
        qualifiesDisplayOnlyFullGridRecoveryBuild116(
          actualFps: actualFps,
          framesAnalyzed: acceptedFrames,
          shortExposureVerified: raw['shortExposureVerified'] == true,
          exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
          displayLikeCellCount: displayLikeCellCount,
          realityLikeCellCount: realityLikeCellCount,
          indeterminateCellCount: indeterminateCellCount,
          periodicCellCount: periodicCellCount,
          stableCellCount: stableCellCount,
          medianCellPeriodicityStrength: medianCellPeriodicity,
          medianCellFrequencyStability: medianCellStability,
          medianCellPhaseStepConsistency: medianCellPhase,
          spatialFamilyCellCount: spatialFamilyCellCount,
          harmonicAwareSpatialFamilyCellCount:
              harmonicAwareSpatialFamilyCellCount,
          rowTimeFamilyCellCount: rowTimeFamilyCellCount,
          medianRowTimeCoherence: medianRowTimeCoherence,
        );
    final fullFrameDisplayV3 =
        strictFullFrameDisplayV3 ||
        harmonicFullFrameDisplayRecovery ||
        lowModulationDisplayRecoveryBuild109 ||
        displayOnlyFullGridRecoveryBuild116;
    final allNineCellsSameDisplayFamily =
        fullFrameDisplayV3 &&
        rowTimeFamilyCellCount == 9 &&
        (spatialFamilyCellCount == 9 ||
            harmonicAwareSpatialFamilyCellCount == 9);

    // BUILD116: mixedSceneDetected must mean actual mixed spatial coverage, not
    // merely "some cells did not clear the local display threshold". When no
    // cell contains reality evidence and the entire 3x3 grid shares the same
    // spatial and row-time family, retain the uncertainty but do not assert a
    // real-scene veto. Strong ML/optical evidence may then resolve the sample.
    final displayOnlyFullGridCoverageBuild116 =
        qualifiesDisplayOnlyFullGridCoverageBuild116(
          actualFps: actualFps,
          framesAnalyzed: acceptedFrames,
          shortExposureVerified: raw['shortExposureVerified'] == true,
          exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
          displayLikeCellCount: displayLikeCellCount,
          realityLikeCellCount: realityLikeCellCount,
          periodicCellCount: periodicCellCount,
          stableCellCount: stableCellCount,
          medianCellPeriodicityStrength: medianCellPeriodicity,
          medianCellFrequencyStability: medianCellStability,
          medianCellPhaseStepConsistency: medianCellPhase,
          spatialFamilyCellCount: spatialFamilyCellCount,
          harmonicAwareSpatialFamilyCellCount:
              harmonicAwareSpatialFamilyCellCount,
          rowTimeFamilyCellCount: rowTimeFamilyCellCount,
          medianRowTimeCoherence: medianRowTimeCoherence,
        );
    final mixedSceneDetected =
        displayLikeCellCount > 0 &&
        !fullFrameDisplayV3 &&
        !displayOnlyFullGridCoverageBuild116;
"""
if old not in source:
    raise SystemExit('BUILD116 insertion anchor not found')
source = source.replace(old, new, 1)

old = """        'lowModulationDisplayRecoveryBuild109':
            lowModulationDisplayRecoveryBuild109,
        'harmonicAwareSpatialFamilyCellCount':
            harmonicAwareSpatialFamilyCellCount,
        'localDisplayLikeCellCountDecisionGate': false,
"""
new = """        'lowModulationDisplayRecoveryBuild109':
            lowModulationDisplayRecoveryBuild109,
        'displayOnlyFullGridRecoveryBuild116':
            displayOnlyFullGridRecoveryBuild116,
        'displayOnlyFullGridCoverageBuild116':
            displayOnlyFullGridCoverageBuild116,
        'harmonicAwareSpatialFamilyCellCount':
            harmonicAwareSpatialFamilyCellCount,
        'localDisplayLikeCellCountDecisionGate': false,
"""
if old not in source:
    raise SystemExit('BUILD116 evidence anchor not found')
source = source.replace(old, new, 1)

old = """        'lowModulationDisplayRecoveryBuild109':
            lowModulationDisplayRecoveryBuild109,
        'displayFamilyMode': harmonicFullFrameDisplayRecovery
            ? 'HARMONIC_2_TO_1_CORROBORATED'
            : lowModulationDisplayRecoveryBuild109
            ? 'LOW_MODULATION_MULTI_AXIS_CORROBORATED'
            : 'STRICT_SINGLE_FAMILY',
        'classificationPolicy': 'BUILD109_VALIDATED_V3_DISPLAY_PRESERVED;LOW_MODULATION_0_50_TO_0_75_REQUIRES_HARMONIC_SPATIAL_9_OF_9_PLUS_ROW_TIME_9_OF_9_PLUS_STRONG_ROW_COHERENCE_PLUS_TWO_SHORT_EXPOSURE_CORROBORATIONS;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',
"""
new = """        'lowModulationDisplayRecoveryBuild109':
            lowModulationDisplayRecoveryBuild109,
        'displayOnlyFullGridRecoveryBuild116':
            displayOnlyFullGridRecoveryBuild116,
        'displayOnlyFullGridCoverageBuild116':
            displayOnlyFullGridCoverageBuild116,
        'displayFamilyMode': harmonicFullFrameDisplayRecovery
            ? 'HARMONIC_2_TO_1_CORROBORATED'
            : lowModulationDisplayRecoveryBuild109
            ? 'LOW_MODULATION_MULTI_AXIS_CORROBORATED'
            : displayOnlyFullGridRecoveryBuild116
            ? 'DISPLAY_ONLY_FULL_GRID_CORROBORATED'
            : 'STRICT_SINGLE_FAMILY',
        'classificationPolicy': 'BUILD116_PRESERVES_VALIDATED_V3_AND_BUILD109_GATES;DISPLAY_ONLY_9_OF_9_RECOVERY_REQUIRES_PERIODIC_STABLE_FULL_GRID_PHYSICS;DISPLAY_ONLY_PARTIAL_LOCAL_CELLS_WITH_9_OF_9_SPATIAL_AND_ROW_TIME_COVERAGE_DO_NOT_ASSERT_MIXED_REALITY;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',
"""
if old not in source:
    raise SystemExit('BUILD116 policy anchor not found')
source = source.replace(old, new, 1)

anchor = """  static bool qualifiesNoTemporalDisplaySignatureV31({
"""
methods = r'''  /// BUILD116 narrow physical recovery for modern displays whose global
  /// frame-luma rhythm is weak/slow but whose complete 3x3 grid is independently
  /// and persistently display-like. This never accepts partial display coverage.
  static bool qualifiesDisplayOnlyFullGridRecoveryBuild116({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required int displayLikeCellCount,
    required int realityLikeCellCount,
    required int indeterminateCellCount,
    required int periodicCellCount,
    required int stableCellCount,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int spatialFamilyCellCount,
    required int harmonicAwareSpatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    return displayLikeCellCount == 9 &&
        realityLikeCellCount == 0 &&
        indeterminateCellCount == 0 &&
        periodicCellCount == 9 &&
        stableCellCount == 9 &&
        medianCellPeriodicityStrength >= 0.50 &&
        medianCellFrequencyStability >= 0.95 &&
        medianCellPhaseStepConsistency >= 0.90 &&
        spatialFamilyCellCount == 9 &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.40;
  }

  /// BUILD116 coverage guard. It does not itself declare a display. It only
  /// prevents the mixed-real-scene veto when physical frequency families span
  /// all nine cells and no cell contains positive reality-like evidence.
  static bool qualifiesDisplayOnlyFullGridCoverageBuild116({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required int displayLikeCellCount,
    required int realityLikeCellCount,
    required int periodicCellCount,
    required int stableCellCount,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int spatialFamilyCellCount,
    required int harmonicAwareSpatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    return displayLikeCellCount >= 5 &&
        realityLikeCellCount == 0 &&
        periodicCellCount >= 5 &&
        stableCellCount >= 5 &&
        medianCellPeriodicityStrength >= 0.10 &&
        medianCellFrequencyStability >= 0.90 &&
        medianCellPhaseStepConsistency >= 0.50 &&
        spatialFamilyCellCount == 9 &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.40;
  }

'''
if anchor not in source:
    raise SystemExit('BUILD116 method anchor not found')
source = source.replace(anchor, methods + anchor, 1)
source_path.write_text(source)

test_path = Path('test/build116_bmw_display_hfr_mixedscene_test.dart')
test_path.write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

HCVDisplayRiskResult strongScreenBase() => const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 99,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['ML_SCREEN_CLASS'],
      strongSources: <String>['ML_SCREEN_CLASS'],
      reasons: <String>[
        'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
        'ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION',
      ],
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

Map<String, dynamic> v32Probe({
  required bool fullFrameDisplay,
  required bool mixed,
  required int displayCells,
  required int realityCells,
  required int indeterminateCells,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': fullFrameDisplay,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrameDisplay,
        'fullFrameReality': false,
        'positivePhysicalRealityEvidence': false,
        'mixedSceneDetected': mixed,
        'allNineCellsSameDisplayFamily': fullFrameDisplay,
        'displayLikeCellCount': displayCells,
        'realityLikeCellCount': realityCells,
        'indeterminateCellCount': indeterminateCells,
        'spatialFamilyCellCount': 9,
        'harmonicAwareSpatialFamilyCellCount': 9,
        'rowTimeFamilyCellCount': 9,
      },
    };

Map<String, dynamic> bmwVideoMl() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.9906,
      'predictedClassConfidence': 0.8532,
      'screenReplayRiskScore': 99,
      'averageScreenReplayRiskScore': 99.0,
      'maxFrameScreenReplayRiskScore': 99,
      'strongScreenFrameCount': 3,
      'mediumScreenFrameCount': 3,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        <String, dynamic>{
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': 0.9906,
          'screenReplayRiskScore': 99,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 99,
            'contentAreaRiskScore': 98,
          },
        },
        <String, dynamic>{
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': 0.9938,
          'screenReplayRiskScore': 99,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 99,
            'contentAreaRiskScore': 99,
          },
        },
        <String, dynamic>{
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': 0.9862,
          'screenReplayRiskScore': 99,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 99,
            'contentAreaRiskScore': 99,
          },
        },
      ],
    };

Map<String, dynamic> realityMl() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'predictedClass': 'REALITY_OUTDOOR',
      'screenProbability': 0.1664,
      'predictedClassConfidence': 0.6941,
      'screenReplayRiskScore': 17,
      'averageScreenReplayRiskScore': 15.6667,
      'maxFrameScreenReplayRiskScore': 17,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        <String, dynamic>{
          'predictedClass': 'REALITY_OUTDOOR',
          'screenProbability': 0.1664,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 17,
            'contentAreaRiskScore': 8,
          },
        },
        <String, dynamic>{
          'predictedClass': 'REALITY_OUTDOOR',
          'screenProbability': 0.1528,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 15,
            'contentAreaRiskScore': 6,
          },
        },
        <String, dynamic>{
          'predictedClass': 'REALITY_OUTDOOR',
          'screenProbability': 0.1503,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 15,
            'contentAreaRiskScore': 12,
          },
        },
      ],
    };

void main() {
  test('BMW 969E full-grid display physics qualifies bounded BUILD116 recovery', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayOnlyFullGridRecoveryBuild116(
        actualFps: 240.6256,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        displayLikeCellCount: 9,
        realityLikeCellCount: 0,
        indeterminateCellCount: 0,
        periodicCellCount: 9,
        stableCellCount: 9,
        medianCellPeriodicityStrength: 0.72278,
        medianCellFrequencyStability: 1.0,
        medianCellPhaseStepConsistency: 0.99691,
        spatialFamilyCellCount: 9,
        harmonicAwareSpatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.52781,
      ),
      isTrue,
    );
  });

  test('BMW D41E full-grid display physics qualifies bounded BUILD116 recovery', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayOnlyFullGridRecoveryBuild116(
        actualFps: 240.6280,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        displayLikeCellCount: 9,
        realityLikeCellCount: 0,
        indeterminateCellCount: 0,
        periodicCellCount: 9,
        stableCellCount: 9,
        medianCellPeriodicityStrength: 0.69028,
        medianCellFrequencyStability: 1.0,
        medianCellPhaseStepConsistency: 0.99734,
        spatialFamilyCellCount: 9,
        harmonicAwareSpatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.46932,
      ),
      isTrue,
    );
  });

  test('BMW B77 and AC89 are full-grid coverage candidates, not mixed reality', () {
    for (final sample in <List<double>>[
      <double>[5, 0.11563, 0.92771, 0.57247, 0.48631],
      <double>[5, 0.21835, 0.93976, 0.82189, 0.41025],
    ]) {
      expect(
        HCVTemporalFrequencyProbe.qualifiesDisplayOnlyFullGridCoverageBuild116(
          actualFps: 240.626,
          framesAnalyzed: 84,
          shortExposureVerified: true,
          exposureLocked: true,
          displayLikeCellCount: sample[0].toInt(),
          realityLikeCellCount: 0,
          periodicCellCount: 5,
          stableCellCount: 5,
          medianCellPeriodicityStrength: sample[1],
          medianCellFrequencyStability: sample[2],
          medianCellPhaseStepConsistency: sample[3],
          spatialFamilyCellCount: 9,
          harmonicAwareSpatialFamilyCellCount: 9,
          rowTimeFamilyCellCount: 9,
          medianRowTimeCoherence: sample[4],
        ),
        isTrue,
      );
    }
  });

  test('TV inside room controls remain mixed reality', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayOnlyFullGridCoverageBuild116(
        actualFps: 240.6256,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        displayLikeCellCount: 3,
        realityLikeCellCount: 1,
        periodicCellCount: 4,
        stableCellCount: 3,
        medianCellPeriodicityStrength: 0.08872,
        medianCellFrequencyStability: 0.67470,
        medianCellPhaseStepConsistency: 0.57087,
        spatialFamilyCellCount: 7,
        harmonicAwareSpatialFamilyCellCount: 8,
        rowTimeFamilyCellCount: 5,
        medianRowTimeCoherence: 0.42258,
      ),
      isFalse,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayOnlyFullGridCoverageBuild116(
        actualFps: 240.6280,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        displayLikeCellCount: 3,
        realityLikeCellCount: 3,
        periodicCellCount: 3,
        stableCellCount: 3,
        medianCellPeriodicityStrength: 0.01562,
        medianCellFrequencyStability: 0.30120,
        medianCellPhaseStepConsistency: 0.44297,
        spatialFamilyCellCount: 8,
        harmonicAwareSpatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 6,
        medianRowTimeCoherence: 0.26589,
      ),
      isFalse,
    );
  });

  test('one reality-like cell vetoes full-grid coverage even with perfect families', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayOnlyFullGridCoverageBuild116(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        displayLikeCellCount: 8,
        realityLikeCellCount: 1,
        periodicCellCount: 8,
        stableCellCount: 8,
        medianCellPeriodicityStrength: 0.70,
        medianCellFrequencyStability: 1.0,
        medianCellPhaseStepConsistency: 0.99,
        spatialFamilyCellCount: 9,
        harmonicAwareSpatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.70,
      ),
      isFalse,
    );
  });

  test('BMW B77 strong full-frame ML is no longer destroyed by a false mixed veto', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: strongScreenBase(),
      passiveOptical: cleanOptical(),
      ml: bmwVideoMl(),
      temporalFrequencyProbe: v32Probe(
        fullFrameDisplay: false,
        mixed: false,
        displayCells: 5,
        realityCells: 0,
        indeterminateCells: 4,
      ),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, greaterThanOrEqualTo(95));
  });

  test('BMW 969E physical full-grid recovery overrides misleading reality ML', () {
    final base = HCVDisplayRiskFusion.mlFirstVideoDecision(realityMl())!;
    expect(base.decision, 'NO_DISPLAY_EVIDENCE');
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: realityMl(),
      temporalFrequencyProbe: v32Probe(
        fullFrameDisplay: true,
        mixed: false,
        displayCells: 9,
        realityCells: 0,
        indeterminateCells: 0,
      ),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(
      result.reasons,
      contains('HFR_V3_ALL_NINE_CELLS_ONE_DISPLAY_FAMILY'),
    );
  });
}
''')
print('BUILD116 patch staged in working tree')
