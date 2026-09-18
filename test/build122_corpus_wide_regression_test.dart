import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_final_policy.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_context_evidence.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  group('BUILD122 corpus-wide regressions', () {
    test('26C near-full 8-of-9 HFR recovery qualifies', () {
      final result = HCVTemporalFrequencyProbe
          .qualifiesNearFullGridDisplayRecoveryBuild122(
        actualFps: 240.630453,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        displayLikeCellCount: 8,
        realityLikeCellCount: 0,
        periodicCellCount: 9,
        stableCellCount: 9,
        medianCellPeriodicityStrength: 0.588377,
        medianCellFrequencyStability: 1.0,
        medianCellPhaseStepConsistency: 0.995185,
        spatialFamilyCellCount: 9,
        harmonicAwareSpatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.277287,
      );

      expect(result, isTrue);
    });

    test('near-full HFR recovery rejects weaker or mixed coverage', () {
      bool qualifies({
        int displayCells = 8,
        int realityCells = 0,
        double rowTime = 0.277287,
      }) =>
          HCVTemporalFrequencyProbe
              .qualifiesNearFullGridDisplayRecoveryBuild122(
            actualFps: 240.630453,
            framesAnalyzed: 84,
            shortExposureVerified: true,
            exposureLocked: true,
            displayLikeCellCount: displayCells,
            realityLikeCellCount: realityCells,
            periodicCellCount: 9,
            stableCellCount: 9,
            medianCellPeriodicityStrength: 0.588377,
            medianCellFrequencyStability: 1.0,
            medianCellPhaseStepConsistency: 0.995185,
            spatialFamilyCellCount: 9,
            harmonicAwareSpatialFamilyCellCount: 9,
            rowTimeFamilyCellCount: 9,
            medianRowTimeCoherence: rowTime,
          );

      expect(qualifies(displayCells: 7), isFalse);
      expect(qualifies(realityCells: 1), isFalse);
      expect(qualifies(rowTime: 0.24), isFalse);
    });

    test('3659 archive-compatible raw-full video pattern becomes STRONG', () {
      final ml = _archive3659Ml();

      expect(
        HCVDisplayRiskFusion.hasRawFullVideoScreenRecoveryBuild122(ml),
        isTrue,
      );

      final result = HCVDisplayRiskFusion.mlFirstVideoDecision(ml);
      expect(result, isNotNull);
      expect(result!.decision, 'STRONG_DISPLAY_RISK');
      expect(result.score, greaterThanOrEqualTo(95));
      expect(
        result.strongSources,
        contains('ML_RAW_FULL_FRAME_SCREEN_RECOVERY'),
      );
    });

    test('FA4B archive-compatible raw-full video pattern becomes STRONG', () {
      final ml = _archiveFa4bMl();

      expect(
        HCVDisplayRiskFusion.hasRawFullVideoScreenRecoveryBuild122(ml),
        isTrue,
      );
      expect(
        HCVDisplayRiskFusion.mlFirstVideoDecision(ml)!.decision,
        'STRONG_DISPLAY_RISK',
      );
    });

    test('wallpaper-like video does not satisfy raw-full recovery', () {
      final ml = _wallpaperMl();

      expect(
        HCVDisplayRiskFusion.hasRawFullVideoScreenRecoveryBuild122(ml),
        isFalse,
      );
    });

    test('raw full-frame ML diagnostics survive overlay correction', () {
      final source =
          File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

      expect(source, contains("'rawFullFramePredictedClass'"));
      expect(source, contains("'rawFullFramePredictedClassConfidence'"));
      expect(source, contains("'rawFullFrameScreenProbability'"));
    });

    test('complete 42-of-42 front HFR can resolve selfie semantic noise', () {
      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _unresolvedBase(),
        passiveOptical: _cleanOptical(frames: 1),
        ml: _selfieStillMl(),
        temporalFrequencyProbe: _frontCompleteNegativeHfr(),
        photoTemporalMl: _selfieTemporalMl(),
        photoTemporalOptical: _cleanOptical(frames: 15),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
      expect(
        result.reasons,
        contains('V3_BOUNDED_SEMANTIC_ONLY_DISPLAY_APPEARANCE'),
      );
    });

    test('V3 with surviving display-like cells is never strict negative', () {
      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _unresolvedBase(),
        passiveOptical: _cleanOptical(frames: 15),
        ml: _weakVideoMl(),
        temporalFrequencyProbe: _nearFullButLegacyNegativeHfr(),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        isNot(contains('V3_BOUNDED_SEMANTIC_ONLY_DISPLAY_APPEARANCE')),
      );
    });

    test('wallpaper geometry no longer becomes embedded reality', () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _geometryProbe(
          depthDispersion: 0.6164,
          planarCoherence: 0.1684,
          flowReliability: 0.6005,
          motionMagnitude: 0.1667,
        ),
        sensorSignals: _strongSensors(),
      );

      expect(
        context.contextClass,
        HCVSceneContextEvidence.sceneContextUnknown,
      );
      expect(
        context.reasons,
        contains('PASSIVE_GEOMETRY_HIGH_CONFIDENCE_NOT_MET'),
      );
    });

    test('robust embedded room geometry remains embedded reality', () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _geometryProbe(
          depthDispersion: 0.7537,
          planarCoherence: 0.1025,
          flowReliability: 0.6010,
          motionMagnitude: 0.1667,
        ),
        sensorSignals: _strongSensors(),
      );

      expect(
        context.contextClass,
        HCVSceneContextEvidence.displayEmbeddedInReality,
      );
    });

    test('embedded context cannot erase full-frame HFR display physics', () {
      final result = HCVDisplayFinalPolicy.resolve(
        displayPhysics: const HCVDisplayRiskResult(
          risk: 'HIGH',
          score: 95,
          decision: 'STRONG_DISPLAY_RISK',
          analysisStatus: 'COMPLETE',
          evidenceSources: <String>['HFR_COHERENT_DISPLAY_PERIODICITY'],
          strongSources: <String>['HFR_COHERENT_DISPLAY_PERIODICITY'],
          reasons: <String>['HFR_FULL_FRAME_COHERENT_DISPLAY_PERIODICITY'],
        ),
        sceneContext: HCVSceneContextEvidence.confirmedEmbedded(
          reasons: const <String>['POSITIVE_MULTI_DEPTH_SCENE_GEOMETRY'],
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains(
          'FULL_FRAME_HFR_DISPLAY_PHYSICS_OVERRIDES_EMBEDDED_CONTEXT',
        ),
      );
    });

    test('embedded context still resolves semantic-only display appearance',
        () {
      final result = HCVDisplayFinalPolicy.resolve(
        displayPhysics: const HCVDisplayRiskResult(
          risk: 'HIGH',
          score: 95,
          decision: 'STRONG_DISPLAY_RISK',
          analysisStatus: 'COMPLETE',
          evidenceSources: <String>['ML_SCREEN_CLASS'],
          strongSources: <String>['ML_SCREEN_CLASS'],
          reasons: <String>['ML_SCREEN_MULTI_FRAME_PERSISTENCE_CONFIRMED'],
        ),
        sceneContext: HCVSceneContextEvidence.confirmedEmbedded(
          reasons: const <String>['POSITIVE_MULTI_DEPTH_SCENE_GEOMETRY'],
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('DISPLAY_EMBEDDED_IN_REALITY_FINAL_POLICY'),
      );
    });

    test('PHOTO temporal duration and frame count remain frozen', () {
      final source =
          File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

      expect(
        source,
        contains(
          'static const Duration defaultDuration = Duration(milliseconds: 1500)',
        ),
      );
      expect(source, contains('static const int photoMlFrameLimit = 3'));
    });
  });
}

HCVDisplayRiskResult _unresolvedBase() => const HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
    );

Map<String, dynamic> _archive3659Ml() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'screenReplayRiskScore': 54,
      'screenProbability': 0.9319,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.8878,
      'strongScreenFrameCount': 1,
      'mediumScreenFrameCount': 1,
      'averageScreenReplayRiskScore': 56.3,
      'maxFrameScreenReplayRiskScore': 93,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        _frame(
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.9319,
          confidence: 0.8878,
          score: 93,
          fullScore: 93,
          contentScore: 57,
          overlayCorrected: false,
        ),
        _frame(
          predictedClass: 'REALITY_PAPER',
          probability: 0.43,
          confidence: 0.5678,
          score: 43,
          fullScore: 82,
          contentScore: 43,
          overlayCorrected: true,
        ),
        _frame(
          predictedClass: 'REALITY_PAPER',
          probability: 0.3275,
          confidence: 0.6719,
          score: 33,
          fullScore: 77,
          contentScore: 33,
          overlayCorrected: true,
        ),
      ],
    };

Map<String, dynamic> _archiveFa4bMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 2,
      'screenReplayRiskScore': 85,
      'screenProbability': 0.8478,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.8148,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 66.0,
      'maxFrameScreenReplayRiskScore': 85,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        _frame(
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.8478,
          confidence: 0.8148,
          score: 85,
          fullScore: 85,
          contentScore: 59,
          overlayCorrected: false,
        ),
        _frame(
          predictedClass: 'REALITY_PAPER',
          probability: 0.4721,
          confidence: 0.5231,
          score: 47,
          fullScore: 91,
          contentScore: 47,
          overlayCorrected: true,
        ),
      ],
    };

Map<String, dynamic> _wallpaperMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 2,
      'screenReplayRiskScore': 49,
      'screenProbability': 0.4936,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.4124,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 44.5,
      'maxFrameScreenReplayRiskScore': 49,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        _frame(
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.4936,
          confidence: 0.4124,
          score: 49,
          fullScore: 49,
          contentScore: 83,
          overlayCorrected: false,
        ),
        _frame(
          predictedClass: 'REALITY_ROOM',
          probability: 0.3963,
          confidence: 0.3958,
          score: 40,
          fullScore: 81,
          contentScore: 40,
          overlayCorrected: true,
        ),
      ],
    };

Map<String, dynamic> _frame({
  required String predictedClass,
  required double probability,
  required double confidence,
  required int score,
  required int fullScore,
  required int contentScore,
  required bool overlayCorrected,
}) =>
    <String, dynamic>{
      'predictedClass': predictedClass,
      'screenProbability': probability,
      'predictedClassConfidence': confidence,
      'screenReplayRiskScore': score,
      'signals': <String, dynamic>{
        'sigillumOverlayCorrected': overlayCorrected,
        'fullFrameRiskScore': fullScore,
        'contentAreaRiskScore': contentScore,
      },
    };

Map<String, dynamic> _frontCompleteNegativeHfr() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 42,
      'targetFrameCount': 42,
      'configuredFrameRate': 120.0,
      'actualFrameRateFromTimestamps': 119.953813,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'mixedSceneDetected': false,
        'displayLikeCellCount': 0,
        'realityLikeCellCount': 0,
      },
    };

Map<String, dynamic> _nearFullButLegacyNegativeHfr() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'targetFrameCount': 84,
      'configuredFrameRate': 240.0,
      'actualFrameRateFromTimestamps': 240.630453,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'mixedSceneDetected': false,
        'displayLikeCellCount': 8,
        'realityLikeCellCount': 0,
      },
    };

Map<String, dynamic> _selfieStillMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRiskScore': 36,
      'screenProbability': 0.3646,
      'predictedClass': 'REALITY_OUTDOOR',
      'predictedClassConfidence': 0.3924,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 78,
        'contentAreaRiskScore': 36,
      },
    };

Map<String, dynamic> _selfieTemporalMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'screenReplayRiskScore': 75,
      'screenProbability': 0.7454,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.7324,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 71.0,
      'maxFrameScreenReplayRiskScore': 75,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        _frame(
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.6326,
          confidence: 0.6221,
          score: 63,
          fullScore: 63,
          contentScore: 79,
          overlayCorrected: false,
        ),
        _frame(
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.7454,
          confidence: 0.7324,
          score: 75,
          fullScore: 75,
          contentScore: 82,
          overlayCorrected: false,
        ),
        _frame(
          predictedClass: 'SCREEN_MONITOR',
          probability: 0.7547,
          confidence: 0.7362,
          score: 75,
          fullScore: 75,
          contentScore: 77,
          overlayCorrected: false,
        ),
      ],
    };

Map<String, dynamic> _weakVideoMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 2,
      'screenReplayRiskScore': 40,
      'screenProbability': 0.40,
      'predictedClass': 'REALITY_ROOM',
      'predictedClassConfidence': 0.60,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 30.0,
      'maxFrameScreenReplayRiskScore': 40,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        _frame(
          predictedClass: 'REALITY_ROOM',
          probability: 0.40,
          confidence: 0.60,
          score: 40,
          fullScore: 40,
          contentScore: 30,
          overlayCorrected: false,
        ),
        _frame(
          predictedClass: 'REALITY_ROOM',
          probability: 0.20,
          confidence: 0.70,
          score: 20,
          fullScore: 20,
          contentScore: 20,
          overlayCorrected: false,
        ),
      ],
    };

Map<String, dynamic> _cleanOptical({required int frames}) => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frames,
      'screenReplayRisk': 'LOW',
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

Map<String, dynamic> _geometryProbe({
  required double depthDispersion,
  required double planarCoherence,
  required double flowReliability,
  required double motionMagnitude,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'REALITY',
        'realityEvidence': true,
        'planarEvidence': false,
        'motionMagnitude': motionMagnitude,
        'flowReliability': flowReliability,
        'directionCoherence': 0.80,
        'depthDispersion': depthDispersion,
        'planarCoherence': planarCoherence,
        'matchedRegions': 20,
      },
    };

Map<String, dynamic> _strongSensors() => <String, dynamic>{
      'signalsRecorded': true,
      'accelerometerSamples': 7,
      'gyroscopeSamples': 7,
      'accelerometerMotionScore': 0.20,
      'gyroscopeMotionScore': 0.08,
    };
