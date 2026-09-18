import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_context_evidence.dart';

void main() {
  group('BUILD117 display physics / scene context separation', () {
    test('mixed HFR cannot erase an existing strong display verdict', () {
      final base = HCVDisplayRiskResult(
        risk: 'HIGH',
        score: 97,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['ML_SCREEN'],
        strongSources: const <String>['ML_SCREEN'],
        reasons: const <String>[
          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
          'ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION',
        ],
      );

      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: base,
        passiveOptical: null,
        ml: null,
        temporalFrequencyProbe: _mixedUnknownHfr(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(result.score, 97);
      expect(result.strongSources, contains('ML_SCREEN'));
      expect(result.reasons, isNot(contains('HFR_V3_MIXED_REAL_SCENE')));
      expect(
        result.reasons,
        isNot(contains('HFR_V3_PARTIAL_DISPLAY_COVERAGE_IS_REALITY')),
      );
    });

    test('positive multi-depth context resolves an embedded display as reality', () {
      final base = HCVDisplayRiskResult(
        risk: 'HIGH',
        score: 98,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['HFR_DISPLAY', 'ML_SCREEN'],
        strongSources: const <String>['HFR_DISPLAY', 'ML_SCREEN'],
        reasons: const <String>['DISPLAY_PHYSICS_STRONG'],
      );
      final context = HCVSceneContextEvidence.fromGeometry(
        <String, dynamic>{
          'sceneClass': 'REALITY',
          'realityEvidence': true,
          'planarEvidence': false,
        },
      );

      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: base,
        passiveOptical: null,
        ml: null,
        temporalFrequencyProbe: null,
        sceneContextEvidence: context,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(result.evidenceSources, contains('HFR_DISPLAY'));
      expect(result.strongSources, contains('ML_SCREEN'));
      expect(
        result.reasons,
        contains('POSITIVE_SCENE_CONTEXT_OVERRIDES_DISPLAY_PRESENCE'),
      );
    });

    test('planarity alone cannot turn a strong display into reality', () {
      final base = HCVDisplayRiskResult(
        risk: 'HIGH',
        score: 96,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['ML_SCREEN'],
        strongSources: const <String>['ML_SCREEN'],
        reasons: const <String>['DISPLAY_PHYSICS_STRONG'],
      );
      final context = HCVSceneContextEvidence.fromGeometry(
        <String, dynamic>{
          'sceneClass': 'PLANAR',
          'realityEvidence': false,
          'planarEvidence': true,
        },
      );

      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: base,
        passiveOptical: null,
        ml: null,
        temporalFrequencyProbe: null,
        sceneContextEvidence: context,
      );

      expect(context.contextClass, HCVSceneContextEvidence.sceneContextUnknown);
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.score, 96);
    });

    test('still optical trace is not replaced by clean temporal optical', () {
      final base = HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: 45,
        decision: 'NON_CONCLUSIVE',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>[],
        strongSources: const <String>[],
        reasons: const <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
      );

      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: base,
        passiveOptical: _strongStillOptical(),
        photoTemporalOptical: _cleanTemporalOptical(),
        ml: _moderateStillScreenMl(),
        temporalFrequencyProbe: _strictNegativeHfr(),
        photoTemporalMl: _weakTemporalScreenMl(),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(
        result.reasons,
        isNot(contains('V3_BOUNDED_SEMANTIC_ONLY_DISPLAY_APPEARANCE')),
      );
      expect(
        result.reasons,
        isNot(contains('WEAK_PHOTO_AND_TEMPORAL_SCREEN_SEMANTICS_UNCORROBORATED')),
      );
    });
  });
}

Map<String, dynamic> _mixedUnknownHfr() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 90,
      'actualFrameRateFromTimestamps': 240.0,
      'displayRealityEvidenceV3': <String, dynamic>{
        'mixedSceneDetected': true,
        'positivePhysicalRealityEvidence': false,
        'fullFrameDisplay': false,
        'fullFrameReality': false,
      },
    };

Map<String, dynamic> _strictNegativeHfr() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 90,
      'actualFrameRateFromTimestamps': 240.0,
      'displayRealityEvidenceV3': <String, dynamic>{
        'mixedSceneDetected': false,
        'positivePhysicalRealityEvidence': false,
        'fullFrameDisplay': false,
        'fullFrameReality': false,
      },
    };

Map<String, dynamic> _strongStillOptical() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'screenReplayRisk': 'HIGH',
      'screenReplayRiskScore': 70,
      'framesAnalyzed': 18,
      'signals': <String, dynamic>{
        'strongDisplayTrace': true,
        'structuralDisplayTrace': true,
        'horizontalRefreshBands': true,
      },
    };

Map<String, dynamic> _cleanTemporalOptical() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'captureSource': 'PHOTO_TECHNICAL_MINI_VIDEO_V2',
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 20,
      'framesAnalyzed': 18,
      'signals': <String, dynamic>{},
    };

Map<String, dynamic> _moderateStillScreenMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.877,
      'screenReplayRiskScore': 88,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 88,
        'contentAreaRiskScore': 88,
      },
    };

Map<String, dynamic> _weakTemporalScreenMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'mediumScreenFrameCount': 3,
      'strongScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 60.0,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        <String, dynamic>{'screenProbability': 0.60},
        <String, dynamic>{'screenProbability': 0.61},
        <String, dynamic>{'screenProbability': 0.62},
      ],
    };
