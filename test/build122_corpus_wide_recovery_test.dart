import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_final_policy.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_context_evidence.dart';

void main() {
  group('BUILD122 corpus-wide display recovery', () {
    test('near-full HFR recovery is present and requires 8 of 9 display cells',
        () {
      final source =
          File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();

      expect(source, contains('nearFullGridDisplayRecoveryBuild122'));
      expect(source, contains('displayLikeCellCount >= 8'));
      expect(source, contains('realityLikeCellCount == 0'));
      expect(source, contains('periodicCellCount == 9'));
      expect(source, contains('stableCellCount == 9'));
      expect(source, contains('medianCellPeriodicity >= 0.50'));
      expect(source, contains('medianCellStability >= 0.95'));
      expect(source, contains('medianCellPhase >= 0.90'));
      expect(source, contains('medianRowTimeCoherence >= 0.25'));
    });

    test('8-of-9 display-like HFR can never be treated as strict negative', () {
      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _nonConclusiveBase(),
        passiveOptical: _cleanOptical(),
        ml: _weakVideoMl(),
        temporalFrequencyProbe: _completeRearHfr(
          displayLikeCells: 8,
          realityLikeCells: 0,
        ),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        isNot(contains('V3_BOUNDED_SEMANTIC_ONLY_DISPLAY_APPEARANCE')),
      );
    });

    test('complete 120 fps front HFR uses target frame count, not fixed 60',
        () {
      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _nonConclusiveBase(),
        passiveOptical: _cleanOptical(),
        ml: _weakVideoMl(),
        temporalFrequencyProbe: _completeFrontHfr(),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('V3_BOUNDED_SEMANTIC_ONLY_DISPLAY_APPEARANCE'),
      );
    });

    test('raw full-frame monitor evidence survives overlay crop correction',
        () {
      final result = HCVDisplayRiskFusion.mlFirstVideoDecision(
        _overlayCorrectedMonitorMl(),
      );

      expect(result, isNotNull);
      expect(result!.decision, 'STRONG_DISPLAY_RISK');
      expect(result.score, greaterThanOrEqualTo(90));
      expect(
        result.reasons,
        contains('BUILD122_RAW_FULL_FRAME_VIDEO_RECOVERY'),
      );
    });

    test('bounded semantic resolver cannot downgrade raw full-frame recovery',
        () {
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
        passiveOptical: _cleanOptical(),
        ml: _overlayCorrectedMonitorMl(),
        temporalFrequencyProbe: _completeFrontHfr(),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        isNot(contains('V3_BOUNDED_SEMANTIC_ONLY_DISPLAY_APPEARANCE')),
      );
    });

    test('wallpaper-like pseudo-parallax does not become embedded reality', () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _geometryProbe(
          depthDispersion: 0.6164,
          planarCoherence: 0.1684,
          flowReliability: 0.78,
          motionMagnitude: 0.22,
        ),
        sensorSignals: _movingSensors(),
      );

      expect(
        context.contextClass,
        HCVSceneContextEvidence.sceneContextUnknown,
      );
      expect(
        context.reasons,
        contains('MULTI_DEPTH_CONFIDENCE_INSUFFICIENT_BUILD122'),
      );
    });

    test('robust multi-depth scene can still become embedded reality', () {
      final context = HCVSceneContextEvidence.fromPassiveGeometryAndSensors(
        geometryProbe: _geometryProbe(
          depthDispersion: 0.78,
          planarCoherence: 0.18,
          flowReliability: 0.72,
          motionMagnitude: 0.24,
        ),
        sensorSignals: _movingSensors(),
      );

      expect(
        context.contextClass,
        HCVSceneContextEvidence.displayEmbeddedInReality,
      );
      expect(context.positiveRealityEvidence, isTrue);
    });

    test('full-frame physical display vetoes embedded-context absolution', () {
      const physics = HCVDisplayRiskResult(
        risk: 'HIGH',
        score: 98,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: <String>['HFR_V3_FULL_FRAME_DISPLAY_PHYSICS'],
        strongSources: <String>['HFR_V3_FULL_FRAME_DISPLAY_PHYSICS'],
        reasons: <String>['HFR_V3_ALL_NINE_CELLS_ONE_DISPLAY_FAMILY'],
      );
      const context = HCVSceneContextEvidence(
        contextClass: HCVSceneContextEvidence.displayEmbeddedInReality,
        analysisStatus: 'ANALYZED',
        positiveRealityEvidence: true,
        reasons: <String>['TEST_EMBEDDED_CONTEXT'],
      );

      final result = HCVDisplayFinalPolicy.resolve(
        displayPhysics: physics,
        sceneContext: context,
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains(
          'FULL_FRAME_DISPLAY_PHYSICS_VETOES_EMBEDDED_OVERRIDE_BUILD122',
        ),
      );
    });

    test('PHOTO temporal cycle remains frozen at 1.5 seconds and 3 ML frames',
        () {
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

HCVDisplayRiskResult _nonConclusiveBase() => const HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
    );

Map<String, dynamic> _cleanOptical() => <String, dynamic>{
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
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'opticalCorroboratedTrace': false,
      },
    };

Map<String, dynamic> _weakVideoMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 20.0,
      'maxFrameScreenReplayRiskScore': 30,
      'screenProbability': 0.20,
      'predictedClass': 'REALITY_ROOM',
      'videoFrameAnalyses': <Map<String, dynamic>>[
        _realityFrame(),
        _realityFrame(),
        _realityFrame(),
      ],
    };

Map<String, dynamic> _realityFrame() => <String, dynamic>{
      'predictedClass': 'REALITY_ROOM',
      'screenProbability': 0.20,
      'screenReplayRiskScore': 20,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 20,
        'contentAreaRiskScore': 20,
      },
    };

Map<String, dynamic> _completeRearHfr({
  required int displayLikeCells,
  required int realityLikeCells,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'targetFrameCount': 84,
      'configuredFrameRate': 240.0,
      'actualFrameRateFromTimestamps': 240.0,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'mixedSceneDetected': false,
        'displayLikeCellCount': displayLikeCells,
        'realityLikeCellCount': realityLikeCells,
      },
    };

Map<String, dynamic> _completeFrontHfr() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 42,
      'targetFrameCount': 42,
      'configuredFrameRate': 120.0,
      'actualFrameRateFromTimestamps': 119.95,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'mixedSceneDetected': false,
        'displayLikeCellCount': 0,
        'realityLikeCellCount': 0,
      },
    };

Map<String, dynamic> _overlayCorrectedMonitorMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'screenReplayRiskScore': 47,
      'screenProbability': 0.47,
      'predictedClass': 'REALITY_PAPER',
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 40.0,
      'maxFrameScreenReplayRiskScore': 47,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        _rawMonitorFrame(93, 0.93, 0.90, corrected: false),
        _rawMonitorFrame(82, 0.82, 0.84, corrected: true),
        _rawMonitorFrame(77, 0.77, 0.75, corrected: true),
      ],
      'videoPhotoSpatialEvidence': <String, dynamic>{
        'sceneTransitionDetected': false,
      },
    };

Map<String, dynamic> _rawMonitorFrame(
  int score,
  double probability,
  double confidence, {
  required bool corrected,
}) =>
    <String, dynamic>{
      'predictedClass': corrected ? 'REALITY_PAPER' : 'SCREEN_MONITOR',
      'screenProbability': corrected ? 0.43 : probability,
      'screenReplayRiskScore': corrected ? 43 : score,
      'signals': <String, dynamic>{
        'sigillumOverlayCorrected': corrected,
        'fullFrameRiskScore': score,
        'contentAreaRiskScore': corrected ? 43 : score,
        'rawFullFrameScreenProbability': probability,
        'rawFullFramePredictedClass': 'SCREEN_MONITOR',
        'rawFullFramePredictedClassConfidence': confidence,
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
        'directionCoherence': 0.60,
        'depthDispersion': depthDispersion,
        'planarCoherence': planarCoherence,
        'matchedRegions': 20,
      },
    };

Map<String, dynamic> _movingSensors() => <String, dynamic>{
      'signalsRecorded': true,
      'accelerometerSamples': 7,
      'gyroscopeSamples': 7,
      'accelerometerMotionScore': 0.20,
      'gyroscopeMotionScore': 0.08,
    };
