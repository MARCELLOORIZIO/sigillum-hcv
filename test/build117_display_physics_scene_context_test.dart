import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_final_policy.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_context_evidence.dart';

HCVDisplayRiskResult strongDisplay() => const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 98,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['ML_SCREEN_CLASS'],
      strongSources: <String>['ML_SCREEN_CLASS'],
      reasons: <String>['ML_SCREEN_STRONG'],
    );

Map<String, dynamic> cleanTemporalOptical() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 15,
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 20,
      'signals': <String, dynamic>{
        'strongDisplayTrace': false,
        'structuralDisplayTrace': false,
        'temporalScreenPulse': false,
      },
    };

Map<String, dynamic> mixedUnknownHfr() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'fullFrameReality': false,
        'positivePhysicalRealityEvidence': false,
        'mixedSceneDetected': true,
        'displayLikeCellCount': 4,
        'realityLikeCellCount': 0,
        'indeterminateCellCount': 5,
        'spatialFamilyCellCount': 9,
        'harmonicAwareSpatialFamilyCellCount': 9,
        'rowTimeFamilyCellCount': 9,
      },
    };

Map<String, dynamic> stillScreenMl() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.877,
      'predictedClassConfidence': 0.80,
      'screenReplayRiskScore': 88,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 95,
        'contentAreaRiskScore': 90,
      },
    };

Map<String, dynamic> stillOpticalHigh() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRisk': 'HIGH',
      'screenReplayRiskScore': 70,
      'signals': <String, dynamic>{
        'strongDisplayTrace': true,
        'structuralDisplayTrace': true,
        'temporalScreenPulse': false,
      },
    };

void main() {
  test('F5F9-style DISPLAY plus UNKNOWN HFR cannot become REALITY', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: strongDisplay(),
      passiveOptical: cleanTemporalOptical(),
      postCaptureOptical: null,
      ml: stillScreenMl(),
      temporalFrequencyProbe: mixedUnknownHfr(),
    );

    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });

  test('photo still optical remains decision evidence after temporal mini-video', () {
    final unresolved = const HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'PARTIAL',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
    );

    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved,
      passiveOptical: cleanTemporalOptical(),
      postCaptureOptical: stillOpticalHigh(),
      ml: stillScreenMl(),
      temporalFrequencyProbe: mixedUnknownHfr(),
      photoTemporalMl: <String, dynamic>{
        'analysisStatus': 'ANALYZED',
        'framesAnalyzed': 3,
        'videoFrameAnalyses': <Map<String, dynamic>>[
          <String, dynamic>{'predictedClass': 'SCREEN_MONITOR'},
          <String, dynamic>{'predictedClass': 'SCREEN_MONITOR'},
          <String, dynamic>{'predictedClass': 'SCREEN_MONITOR'},
        ],
      },
    );

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('PHOTO_STILL_ML_OPTICAL_CORROBORATION'));
  });

  test('scene context UNKNOWN is neutral', () {
    final context = HCVSceneContextEvidence.assess(
      temporalFrequencyProbe: mixedUnknownHfr(),
    );
    expect(context.context, HCVSceneContextResult.unknown);

    final finalResult = HCVDisplayFinalPolicy.resolve(
      displayPhysics: strongDisplay(),
      sceneContext: context,
    );
    expect(finalResult.decision, 'STRONG_DISPLAY_RISK');
  });

  test('positive multi-depth geometry makes display embedded in reality', () {
    final context = HCVSceneContextEvidence.assess(
      liveScreenProbe: <String, dynamic>{
        'sceneClass': 'REALITY',
        'reason': 'MULTI_DEPTH_PARALLAX_DETECTED',
        'geometryChallenge': <String, dynamic>{
          'sceneClass': 'REALITY',
          'realityEvidence': true,
        },
      },
      temporalFrequencyProbe: mixedUnknownHfr(),
    );

    expect(
      context.context,
      HCVSceneContextResult.displayEmbeddedInReality,
    );

    final finalResult = HCVDisplayFinalPolicy.resolve(
      displayPhysics: strongDisplay(),
      sceneContext: context,
    );
    expect(finalResult.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      finalResult.reasons,
      contains('DISPLAY_EMBEDDED_IN_REALITY_FINAL_POLICY'),
    );
  });
}
