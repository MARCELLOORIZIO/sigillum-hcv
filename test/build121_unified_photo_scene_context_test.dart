import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('BUILD121 unified PHOTO and scene-context fixes', () {
    test('passive scene context keeps a real 1.2 second sensor window', () {
      final source =
          File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();

      expect(
        source,
        contains('Duration duration = const Duration(milliseconds: 1200)'),
      );
      expect(source, contains('int maxFrames = 60'));
      expect(
        source,
        contains('while (DateTime.now().isBefore(deadline))'),
      );
      expect(
        source,
        isNot(
          contains(
            'while (frames.length < maxFrames && DateTime.now().isBefore(deadline))',
          ),
        ),
      );
    });

    test('PHOTO settles AUTO camera state before the 1.5 s temporal clip', () {
      final source = File('lib/camera_page.dart').readAsStringSync();
      final contextIndex = source.indexOf(
        'sceneContextProbe = await _capturePassiveSceneContext();',
      );
      final settleIndex = source.indexOf(
        'await _settleCameraAfterLiveProbe();',
        contextIndex,
      );
      final temporalIndex = source.indexOf(
        'temporalClip = await temporalProbeEngine.capture(',
        contextIndex,
      );

      expect(contextIndex, greaterThanOrEqualTo(0));
      expect(settleIndex, greaterThan(contextIndex));
      expect(temporalIndex, greaterThan(settleIndex));
    });

    test('PHOTO negative optical resolver uses the multi-frame technical clip',
        () {
      final fusionSource =
          File('lib/hcv_display_risk_fusion.dart').readAsStringSync();
      expect(
        fusionSource,
        contains(
          'final negativeOptical = photoTemporalOptical ?? passiveOptical;',
        ),
      );

      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _nonConclusiveBase(),
        passiveOptical: _optical(frames: 1, score: 0),
        ml: _stillRealityMl(
          screenProbability: 0.30,
          score: 30,
          fullFrameRisk: 30,
          contentAreaRisk: 30,
        ),
        temporalFrequencyProbe: _strictNegativeHfrV2(),
        photoTemporalMl: _weakTemporalMl(),
        photoTemporalOptical: _optical(frames: 15, score: 20),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
      expect(
        result.reasons,
        contains('STRICT_NEGATIVE_HFR_NO_PHYSICAL_DISPLAY_TRACE'),
      );
    });

    test(
        'strong PHOTO temporal ML plus final-still REALITY becomes NC without physical corroboration',
        () {
      final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _strongTemporalBase(),
        passiveOptical: _optical(frames: 1, score: 0),
        ml: _stillRealityMl(
          screenProbability: 0.18,
          score: 18,
          fullFrameRisk: 18,
          contentAreaRisk: 18,
        ),
        temporalFrequencyProbe: _strictNegativeHfrV2(),
        photoTemporalMl: _strongTemporalMl(),
        photoTemporalOptical: _optical(frames: 15, score: 20),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(
        result.reasons,
        contains('PHOTO_TEMPORAL_STRONG_STILL_REALITY_CONFLICT'),
      );
      expect(
        result.reasons,
        contains('NO_INDEPENDENT_PHYSICAL_DISPLAY_CORROBORATION'),
      );
    });

    test(
        'strict positive HFR still preserves STRONG display in same ML conflict',
        () {
      final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _strongTemporalBase(),
        passiveOptical: _optical(frames: 1, score: 0),
        ml: _stillRealityMl(
          screenProbability: 0.18,
          score: 18,
          fullFrameRisk: 18,
          contentAreaRisk: 18,
        ),
        temporalFrequencyProbe: _strictPositiveHfrV3(),
        photoTemporalMl: _strongTemporalMl(),
        photoTemporalOptical: _optical(frames: 15, score: 20),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.score, greaterThanOrEqualTo(95));
      expect(
        result.reasons,
        isNot(contains('PHOTO_TEMPORAL_STRONG_STILL_REALITY_CONFLICT')),
      );
    });

    test('accepted PHOTO temporal duration and ML frame count remain unchanged',
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

HCVDisplayRiskResult _strongTemporalBase() => const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 95,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['ML_SCREEN_CLASS'],
      strongSources: <String>['ML_SCREEN_CLASS'],
      reasons: <String>[
        'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
        'ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION',
      ],
    );

Map<String, dynamic> _optical({
  required int frames,
  required int score,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frames,
      'screenReplayRisk': score >= 70 ? 'HIGH' : 'LOW',
      'screenReplayRiskScore': score,
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

Map<String, dynamic> _stillRealityMl({
  required double screenProbability,
  required int score,
  required int fullFrameRisk,
  required int contentAreaRisk,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRiskScore': score,
      'screenProbability': screenProbability,
      'predictedClass': 'REALITY_ROOM',
      'predictedClassConfidence': 0.82,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrameRisk,
        'contentAreaRiskScore': contentAreaRisk,
      },
    };

Map<String, dynamic> _weakTemporalMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 40.0,
      'maxFrameScreenReplayRiskScore': 55,
      'screenProbability': 0.55,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        <String, dynamic>{
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': 0.55,
          'screenReplayRiskScore': 55,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 55,
            'contentAreaRiskScore': 55,
          },
        },
        <String, dynamic>{
          'predictedClass': 'REALITY_ROOM',
          'screenProbability': 0.35,
          'screenReplayRiskScore': 35,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 35,
            'contentAreaRiskScore': 35,
          },
        },
        <String, dynamic>{
          'predictedClass': 'REALITY_ROOM',
          'screenProbability': 0.30,
          'screenReplayRiskScore': 30,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 30,
            'contentAreaRiskScore': 30,
          },
        },
      ],
    };

Map<String, dynamic> _strongTemporalMl() => <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'strongScreenFrameCount': 3,
      'mediumScreenFrameCount': 3,
      'averageScreenReplayRiskScore': 95.0,
      'maxFrameScreenReplayRiskScore': 98,
      'screenProbability': 0.95,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.90,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        _strongTemporalFrame(0.94, 95),
        _strongTemporalFrame(0.96, 97),
        _strongTemporalFrame(0.95, 96),
      ],
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 95,
        'contentAreaRiskScore': 95,
      },
    };

Map<String, dynamic> _strongTemporalFrame(double probability, int score) =>
    <String, dynamic>{
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'screenReplayRiskScore': score,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 95,
        'contentAreaRiskScore': 95,
      },
    };

Map<String, dynamic> _strictNegativeHfrV2() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.0,
    };

Map<String, dynamic> _strictPositiveHfrV3() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': true,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.0,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': true,
        'mixedSceneDetected': false,
        'allNineCellsSameDisplayFamily': true,
        'spatialFamilyCellCount': 9,
        'harmonicDisplayRecovery': false,
        'harmonicAwareSpatialFamilyCellCount': 0,
        'rowTimeFamilyCellCount': 9,
      },
    };
