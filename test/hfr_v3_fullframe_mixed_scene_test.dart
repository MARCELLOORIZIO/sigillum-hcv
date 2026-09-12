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
}
