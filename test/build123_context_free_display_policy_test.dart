import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_context_free_display_policy.dart';

void main() {
  group('BUILD123 context-free DISPLAY/REALITY policy', () {
    test('HFR 7-of-9 full-frame family is DISPLAY', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          displayLike: 7,
          realityLike: 0,
          periodic: 7,
          stable: 7,
          spatial: 9,
          harmonic: 9,
          rowTime: 9,
        ),
        ml: _photoReality(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_HFR_FULL_FRAME_DISPLAY'),
      );
    });

    test('HFR 6-of-9 does not activate the display gate', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          displayLike: 6,
          realityLike: 0,
          periodic: 9,
          stable: 9,
          spatial: 9,
          harmonic: 9,
          rowTime: 9,
        ),
        ml: _photoReality(),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('BMW-like 8-of-9 HFR is DISPLAY even with weak ML', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          displayLike: 8,
          realityLike: 0,
          periodic: 9,
          stable: 9,
          spatial: 9,
          harmonic: 9,
          rowTime: 9,
        ),
        ml: _photoReality(screenProbability: 0.337),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('PHOTO exact 0.90 90 75 boundary is DISPLAY', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _quietHfr(),
        ml: _photoScreen(
          probability: 0.90,
          fullFrame: 90,
          contentArea: 75,
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_PHOTO_STILL_ML_SPATIAL_PROOF'),
      );
    });

    test('PHOTO below probability boundary remains REALITY', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _quietHfr(),
        ml: _photoScreen(
          probability: 0.899,
          fullFrame: 100,
          contentArea: 100,
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('archive72 191D-like PHOTO monitor is DISPLAY', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _quietHfr(),
        ml: _photoScreen(
          probability: 0.997,
          fullFrame: 100,
          contentArea: 100,
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('D56D-like wallpaper PHOTO remains REALITY', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _quietHfr(),
        ml: _photoReality(
          screenProbability: 0.1829,
          fullFrame: 94,
          contentArea: 18,
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('VIDEO persistent two-frame full-frame evidence is DISPLAY', () {
      final result = HCVContextFreeDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _quietHfr(),
        ml: _videoScreen(
          aggregateProbability: 0.80,
          fullFrameScores: const <int>[90, 80, 20],
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_FULL_FRAME_SCREEN'),
      );
    });

    test('VIDEO one isolated 95 spike remains REALITY', () {
      final result = HCVContextFreeDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _quietHfr(),
        ml: _videoScreen(
          aggregateProbability: 0.9503,
          fullFrameScores: const <int>[95, 42, 31],
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('archive72 6761-like persistent VIDEO monitor is DISPLAY', () {
      final result = HCVContextFreeDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _quietHfr(),
        ml: _videoScreen(
          aggregateProbability: 0.9534,
          fullFrameScores: const <int>[95, 93, 91],
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('VIDEO aggregate SCREEN probability below 0.80 remains REALITY', () {
      final result = HCVContextFreeDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _quietHfr(),
        ml: _videoScreen(
          aggregateProbability: 0.799,
          fullFrameScores: const <int>[99, 98, 97],
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('camera verdict path no longer calls scene-context final policy', () {
      final source = File('lib/camera_page.dart').readAsStringSync();

      expect(source, isNot(contains('HCVDisplayFinalPolicy.resolve(')));
      expect(
        source,
        contains('HCVContextFreeDisplayPolicy.resolvePhoto('),
      );
      expect(
        source,
        contains('HCVContextFreeDisplayPolicy.resolveVideo('),
      );
    });

    test('context-free policy retains optical but excludes scene geometry', () {
      final source =
          File('lib/hcv_context_free_display_policy.dart').readAsStringSync();

      expect(source, isNot(contains('HCVSceneContextEvidence')));
      expect(source, isNot(contains('geometryProbe')));
      expect(source, isNot(contains('sensorSignals')));
      expect(source, contains('passiveOptical'));
      expect(source, contains('photoTemporalMl'));
    });

    test('missing both ML and HFR remains NON_CONCLUSIVE', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        ml: null,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.analysisStatus, 'NOT_ANALYZED');
    });

    test('PHOTO technical cycle remains 1.5 seconds and 3 ML frames', () {
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

Map<String, dynamic> _hfr({
  required int displayLike,
  required int realityLike,
  required int periodic,
  required int stable,
  required int spatial,
  required int harmonic,
  required int rowTime,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.0,
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': periodic,
        'stableCellCount': stable,
      },
      'displayRealityEvidenceV3': <String, dynamic>{
        'displayLikeCellCount': displayLike,
        'realityLikeCellCount': realityLike,
        'spatialFamilyCellCount': spatial,
        'harmonicAwareSpatialFamilyCellCount': harmonic,
        'rowTimeFamilyCellCount': rowTime,
      },
    };

Map<String, dynamic> _quietHfr() => _hfr(
      displayLike: 0,
      realityLike: 0,
      periodic: 0,
      stable: 0,
      spatial: 0,
      harmonic: 0,
      rowTime: 0,
    );

Map<String, dynamic> _photoScreen({
  required double probability,
  required int fullFrame,
  required int contentArea,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

Map<String, dynamic> _photoReality({
  double screenProbability = 0.18,
  int fullFrame = 18,
  int contentArea = 18,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'REALITY_ROOM',
      'screenProbability': screenProbability,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

Map<String, dynamic> _videoScreen({
  required double aggregateProbability,
  required List<int> fullFrameScores,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': aggregateProbability,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (final score in fullFrameScores)
          <String, dynamic>{
            'predictedClass': score >= 80 ? 'SCREEN_MONITOR' : 'REALITY_ROOM',
            'screenProbability': score / 100.0,
            'signals': <String, dynamic>{
              'fullFrameRiskScore': score,
              'contentAreaRiskScore': score,
            },
          },
      ],
    };
