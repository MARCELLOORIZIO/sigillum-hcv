import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

HCVDisplayRiskResult unresolvedV3() => const HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'PARTIAL',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
    );

Map<String, dynamic> opticalCleanV3() => <String, dynamic>{
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
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'opticalCorroboratedTrace': false,
      },
    };

Map<String, dynamic> v3Probe({
  required bool fullFrameDisplay,
  required bool fullFrameReality,
  required bool mixed,
  int displayCells = 0,
  int spatialFamilyCells = 0,
  int rowTimeFamilyCells = 0,
  bool? allNineSameFamily,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': fullFrameDisplay,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrameDisplay,
        'fullFrameReality': fullFrameReality,
        'mixedSceneDetected': mixed,
        'allNineCellsSameDisplayFamily':
            allNineSameFamily ??
                (fullFrameDisplay &&
                    spatialFamilyCells == 9 &&
                    rowTimeFamilyCells == 9),
        'displayLikeCellCount': displayCells,
        'spatialFamilyCellCount': spatialFamilyCells,
        'rowTimeFamilyCellCount': rowTimeFamilyCells,
      },
    };

Map<String, dynamic> temporalV3(
  List<double> probabilities, {
  int fullFrame = 96,
  int content = 95,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (var i = 0; i < probabilities.length; i++)
          <String, dynamic>{
            'videoFrameIndex': i,
            'screenProbability': probabilities[i],
            'signals': <String, dynamic>{
              'fullFrameRiskScore': fullFrame,
              'contentAreaRiskScore': content,
            },
          },
      ],
    };

void main() {
  test('V3 full-frame display requires all nine cells in one physical family', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(
        legacyHfrCandidate: true,
        spatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.50,
      ),
      isTrue,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(
        legacyHfrCandidate: true,
        spatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 8,
        medianRowTimeCoherence: 0.50,
      ),
      isFalse,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(
        legacyHfrCandidate: false,
        spatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.80,
      ),
      isFalse,
    );
  });

  test('BUILD104 full-frame display photo survives two locally weak cells', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(
        legacyHfrCandidate: true,
        spatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.786861,
      ),
      isTrue,
    );
  });

  test('BUILD104 full-frame display video survives one locally weak cell', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(
        legacyHfrCandidate: true,
        spatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.800272,
      ),
      isTrue,
    );
  });

  test('BUILD104 TV inside room does not become full-frame display', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(
        legacyHfrCandidate: false,
        spatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 7,
        medianRowTimeCoherence: 0.378844,
      ),
      isFalse,
    );
  });

  test('fusion accepts BUILD104 recovered full-frame family with 7 local display cells', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(<double>[0.10, 0.12, 0.11]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: true,
        fullFrameReality: false,
        mixed: false,
        displayCells: 7,
        spatialFamilyCells: 9,
        rowTimeFamilyCells: 9,
        allNineSameFamily: true,
      ),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(
      result.reasons,
      contains('HFR_V3_ALL_NINE_CELLS_ONE_DISPLAY_FAMILY'),
    );
  });

  test('row-by-time matrix exposes coherent temporal rhythm', () {
    final frames = <List<double>>[];
    for (var t = 0; t < 24; t++) {
      frames.add(List<double>.generate(32, (row) {
        final temporal = sin(2 * pi * 4 * t / 24);
        final rowPhase = 0.15 * sin(2 * pi * row / 8);
        return 0.5 + 0.18 * temporal + rowPhase;
      }));
    }
    final result = HCVTemporalFrequencyMath.analyzeRowTimeMatrix(frames);
    expect(result['rowTimeAnalysisStatus'], 'ANALYZED');
    expect((result['rowTimeCoherenceScore'] as num).toDouble(), greaterThan(0.50));
  });

  test('mixed monitor plus room is reality even with strong screen ML', () {
    final strongBase = const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 98,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['ML_SCREEN'],
      strongSources: <String>['ML_SCREEN'],
      reasons: <String>['ML_SCREEN_STRONG'],
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: strongBase,
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(<double>[0.98, 0.97, 0.96]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: false,
        mixed: true,
        displayCells: 4,
        spatialFamilyCells: 4,
        rowTimeFamilyCells: 4,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('HFR_V3_MIXED_REAL_SCENE'));
  });

  test('full-frame text monitor can use repeated full-frame ML when HFR is quiet', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(<double>[0.97, 0.96, 0.95]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: true,
        mixed: false,
      ),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES'));
  });

  test('inherited strong screen ML is vetoed when screen is not full-frame', () {
    final strongBase = const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 98,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['ML_SCREEN'],
      strongSources: <String>['ML_SCREEN'],
      reasons: <String>['ML_SCREEN_STRONG'],
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: strongBase,
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(
        <double>[0.98, 0.97, 0.96],
        fullFrame: 62,
        content: 93,
      ),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: false,
        mixed: false,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'),
    );
  });

  test('screen presence without full-frame support cannot promote a real room', () {
    final base = unresolvedV3();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(
        <double>[0.98, 0.97, 0.96],
        fullFrame: 62,
        content: 93,
      ),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: false,
        mixed: false,
      ),
    );
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('BUILD105 full-frame photo passes V3 family gate despite five locally stable cells', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayFamilyGlobalHfrV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.261673,
        globalModulationDepth: 0.962852,
        globalSpectralConcentration: 0.907329,
        medianCellPeriodicityStrength: 0.217227,
        medianCellFrequencyStability: 0.903614,
        medianCellPhaseStepConsistency: 0.684237,
        periodicCellCount: 9,
      ),
      isTrue,
    );
  });

  test('V3 family gate does not weaken global median stability or periodic-cell requirements', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayFamilyGlobalHfrV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.26,
        globalModulationDepth: 0.96,
        globalSpectralConcentration: 0.91,
        medianCellPeriodicityStrength: 0.22,
        medianCellFrequencyStability: 0.84,
        medianCellPhaseStepConsistency: 0.68,
        periodicCellCount: 9,
      ),
      isFalse,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayFamilyGlobalHfrV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.26,
        globalModulationDepth: 0.96,
        globalSpectralConcentration: 0.91,
        medianCellPeriodicityStrength: 0.22,
        medianCellFrequencyStability: 0.90,
        medianCellPhaseStepConsistency: 0.68,
        periodicCellCount: 5,
      ),
      isFalse,
    );
  });

  test('BUILD105 framed artwork video qualifies as strong physical Reality V3', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 2.864590,
        medianCellPeriodicityStrength: 0.006995,
        medianCellFrequencyStability: 0.168675,
        periodicCellCount: 0,
        stableCellCount: 0,
      ),
      isTrue,
    );
  });

  test('BUILD105 desk video qualifies as physical Reality V3 despite one weak periodic cell', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 2.864562,
        medianCellPeriodicityStrength: 0.021898,
        medianCellFrequencyStability: 0.373494,
        periodicCellCount: 1,
        stableCellCount: 1,
      ),
      isTrue,
    );
  });

  test('Reality V3 rejects mixed scenes and true high-frequency display signatures', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: true,
        displayLikeCellCount: 2,
        dominantTemporalFrequencyHz: 2.8646,
        medianCellPeriodicityStrength: 0.012,
        medianCellFrequencyStability: 0.29,
        periodicCellCount: 4,
        stableCellCount: 2,
      ),
      isFalse,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 100.26,
        medianCellPeriodicityStrength: 0.01,
        medianCellFrequencyStability: 0.20,
        periodicCellCount: 1,
        stableCellCount: 1,
      ),
      isFalse,
    );
  });

  test('Reality V3 resolves weak artwork semantics without changing ML thresholds', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(<double>[0.7543, 0.6020]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: true,
        mixed: false,
        displayCells: 0,
        spatialFamilyCells: 7,
        rowTimeFamilyCells: 9,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE'));
  });

  test('Reality V3 overrides temporal-only passive optical false positive on desk', () {
    final temporalOnlyOptical = <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 15,
      'screenReplayRiskScore': 75,
      'signals': <String, dynamic>{
        'displayFlicker': false,
        'pixelGridOrMoireHint': false,
        'uniformPixelGrid': false,
        'localRefreshFlicker': true,
        'horizontalRefreshBands': false,
        'pairedLocalRefresh': true,
        'temporalScreenPulse': true,
        'structuralDisplayTrace': false,
        'strongDisplayTrace': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'opticalCorroboratedTrace': false,
      },
    };
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: temporalOnlyOptical,
      ml: temporalV3(<double>[0.7381, 0.1400]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: true,
        mixed: false,
        displayCells: 0,
        spatialFamilyCells: 6,
        rowTimeFamilyCells: 9,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('HFR_V3_REALITY_OVERRIDES_TEMPORAL_ONLY_PASSIVE_OPTICAL_CUE'),
    );
  });

  test('Reality V3 cannot override structural optical screen evidence', () {
    final structuralOptical = opticalCleanV3();
    final signals = Map<String, dynamic>.from(structuralOptical['signals'] as Map);
    signals['pixelGridOrMoireHint'] = true;
    structuralOptical['signals'] = signals;
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: structuralOptical,
      ml: temporalV3(<double>[0.30, 0.25]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: true,
        mixed: false,
      ),
    );
    expect(result.decision, 'NON_CONCLUSIVE');
  });

}
