import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

HCVDisplayRiskResult unresolved() => const HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'PARTIAL',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>[
        'DISPLAY_CLASSIFICATION_NOT_RESOLVED',
        'LIVE_PROBE_MISSING',
      ],
    );

Map<String, dynamic> negativeV32() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'mixedSceneDetected': false,
        'allNineCellsSameDisplayFamily': false,
        'spatialFamilyCellCount': 6,
        'harmonicAwareSpatialFamilyCellCount': 7,
        'rowTimeFamilyCellCount': 9,
      },
    };

Map<String, dynamic> cleanOptical({bool localRefresh = false}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 15,
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 20,
      'signals': <String, dynamic>{
        'displayFlicker': false,
        'pixelGridOrMoireHint': false,
        'uniformPixelGrid': false,
        'localRefreshFlicker': localRefresh,
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

Map<String, dynamic> frame({
  required double p,
  required int score,
  required int full,
  required int content,
  String predictedClass = 'SCREEN_MONITOR',
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': predictedClass,
      'screenProbability': p,
      'screenReplayRiskScore': score,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
      },
    };

Map<String, dynamic> temporalMl({
  required List<Map<String, dynamic>> frames,
  required double p,
  required double average,
  required int maxFrame,
  required int medium,
  required int strong,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frames.length,
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': p,
      'screenReplayRiskScore': maxFrame >= 88 ? 54 : maxFrame,
      'mediumScreenFrameCount': medium,
      'strongScreenFrameCount': strong,
      'averageScreenReplayRiskScore': average,
      'maxFrameScreenReplayRiskScore': maxFrame,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': maxFrame,
        'contentAreaRiskScore': 80,
      },
      'videoFrameAnalyses': frames,
      'videoPhotoSpatialEvidence': <String, dynamic>{
        'type': 'SIGILLUM_VIDEO_PHOTO_SPATIAL_EVIDENCE_V1',
        'analysisStatus': 'ANALYZED',
        'stableScreenSequence': false,
        'stableFullFrameScreenCorroboration': false,
        'sceneTransitionDetected': false,
      },
    };

Map<String, dynamic> stillMl({
  required double p,
  required int score,
  required int full,
  required int content,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.70,
      'screenProbability': p,
      'screenReplayRiskScore': score,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
      },
    };

void main() {
  test('BUILD68 0D55 reflective artwork photo resolves to reality', () {
    final temporal = temporalMl(
      frames: <Map<String, dynamic>>[
        frame(p: 0.7964, score: 80, full: 80, content: 66),
        frame(p: 0.7776, score: 78, full: 78, content: 62),
        frame(p: 0.7296, score: 73, full: 73, content: 74),
      ],
      p: 0.7964,
      average: 77.0,
      maxFrame: 80,
      medium: 0,
      strong: 0,
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: stillMl(p: 0.5424, score: 54, full: 76, content: 54),
      temporalFrequencyProbe: negativeV32(),
      photoTemporalMl: temporal,
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
    expect(
      result.reasons,
      contains('V3_BOUNDED_SEMANTIC_ONLY_DISPLAY_APPEARANCE'),
    );
  });

  test('BUILD68 8A5E reflection video ignores isolated low optical refresh',
      () {
    final ml = temporalMl(
      frames: <Map<String, dynamic>>[
        frame(p: 0.6479, score: 65, full: 65, content: 70),
        frame(p: 0.5183, score: 52, full: 52, content: 60),
      ],
      p: 0.6479,
      average: 58.5,
      maxFrame: 65,
      medium: 0,
      strong: 0,
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(localRefresh: true),
      ml: ml,
      temporalFrequencyProbe: negativeV32(),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test(
      'BUILD68 D2A8 visible monitors in real context resolve under bounded V3 evidence',
      () {
    final temporal = temporalMl(
      frames: <Map<String, dynamic>>[
        frame(p: 0.7376, score: 74, full: 74, content: 91),
        frame(p: 0.9451, score: 95, full: 95, content: 87),
        frame(p: 0.7275, score: 73, full: 73, content: 95),
      ],
      p: 0.9451,
      average: 80.6667,
      maxFrame: 95,
      medium: 1,
      strong: 1,
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: stillMl(p: 0.6774, score: 68, full: 68, content: 96),
      temporalFrequencyProbe: negativeV32(),
      photoTemporalMl: temporal,
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('BUILD68 FFCC room context video resolves under bounded V3 evidence',
      () {
    final ml = temporalMl(
      frames: <Map<String, dynamic>>[
        frame(p: 0.8317, score: 83, full: 83, content: 80),
        frame(
          p: 0.3246,
          score: 32,
          full: 32,
          content: 35,
          predictedClass: 'REALITY_ROOM',
        ),
        frame(
          p: 0.0664,
          score: 7,
          full: 7,
          content: 10,
          predictedClass: 'REALITY_ROOM',
        ),
      ],
      p: 0.8317,
      average: 40.6667,
      maxFrame: 83,
      medium: 0,
      strong: 0,
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(localRefresh: true)
        ..['screenReplayRiskScore'] = 0,
      ml: ml,
      temporalFrequencyProbe: negativeV32(),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('BUILD65 A6 optical corroboration cannot be downgraded', () {
    final optical = cleanOptical(localRefresh: true)
      ..['screenReplayRisk'] = 'HIGH'
      ..['screenReplayRiskScore'] = 80
      ..['captureSource'] = 'PHOTO_TECHNICAL_MINI_VIDEO_V2';
    final signals = optical['signals'] as Map<String, dynamic>;
    signals['pairedLocalRefresh'] = true;
    signals['temporalScreenPulse'] = true;
    signals['strongDisplayTrace'] = true;

    final temporal = temporalMl(
      frames: <Map<String, dynamic>>[
        frame(p: 0.8801, score: 88, full: 88, content: 77),
        frame(p: 0.8293, score: 83, full: 83, content: 72),
        frame(p: 0.8109, score: 81, full: 81, content: 84),
      ],
      p: 0.8801,
      average: 84.0,
      maxFrame: 88,
      medium: 1,
      strong: 0,
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: optical,
      ml: stillMl(p: 0.895, score: 89, full: 89, content: 94),
      temporalFrequencyProbe: negativeV32(),
      photoTemporalMl: temporal,
    );
    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });

  test('persistent full-frame screen sequence is never downgraded', () {
    final ml = temporalMl(
      frames: <Map<String, dynamic>>[
        frame(p: 0.97, score: 97, full: 97, content: 94),
        frame(p: 0.95, score: 95, full: 95, content: 92),
        frame(p: 0.94, score: 94, full: 94, content: 91),
      ],
      p: 0.97,
      average: 95.3,
      maxFrame: 97,
      medium: 3,
      strong: 3,
    );
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml,
      temporalFrequencyProbe: negativeV32(),
    );
    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });
}
