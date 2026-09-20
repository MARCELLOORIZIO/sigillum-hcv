import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_context_free_display_policy.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('BUILD124 historical evidence-path and real-schema regressions', () {
    test('the 87-certificate HFR schema keeps counts outside V3', () {
      final hfr = _hfr(
        display: 5,
        reality: 0,
        periodic: 8,
        stable: 6,
        median: 0.167391,
        globalHz: 100.2596,
        spectral: 0.9265,
      );

      expect(
        (hfr['displayRealityEvidenceV3'] as Map)
            .containsKey('periodicCellCount'),
        isFalse,
      );
      expect(
        (hfr['coherentDisplayPeriodicityEvidence'] as Map)[
            'periodicCellCount'],
        8,
      );
    });

    test('PHOTO F48B TV: 5-cell HFR and three persistent ML frames promote',
        () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 5,
          reality: 0,
          periodic: 8,
          stable: 6,
          median: 0.167391,
          globalHz: 100.2596,
          spectral: 0.9265,
        ),
        ml: _photo(
          predicted: 'SCREEN_MONITOR',
          probability: 0.6418,
          full: 64,
          content: 81,
        ),
        photoTemporalMl: _video(
          predicted: 'SCREEN_MONITOR',
          probability: 0.9594,
          frameScores: <int>[96, 95, 94],
          allScreen: true,
        ),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.strongSources, isNotEmpty);
    });

    test('VIDEO CAC6 TV: independently corroborated partial HFR promotes',
        () {
      final result = HCVContextFreeDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 5,
          reality: 0,
          periodic: 6,
          stable: 5,
          median: 0.216991,
          globalHz: 100.2586,
          spectral: 0.8918,
        ),
        ml: _video(
          predicted: 'SCREEN_MONITOR',
          probability: 0.782,
          frameScores: <int>[78, 63, 43],
        ),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_HFR_PHYSICAL_PARTIAL_DISPLAY_PROOF'),
      );
    });

    test('PHOTO BA4D BMW low physical and ML evidence is NON_CONCLUSIVE', () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 2,
          reality: 0,
          periodic: 2,
          stable: 2,
          median: 0.05443,
          globalHz: 2.8646,
          spectral: 0.5677,
        ),
        ml: _photo(
          predicted: 'SCREEN_MONITOR',
          probability: 0.5968,
          full: 60,
          content: 82,
        ),
        photoTemporalMl: _video(
          predicted: 'SCREEN_MONITOR',
          probability: 0.56,
          frameScores: <int>[56, 56, 42],
        ),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
    });

    test('VIDEO 9C4B TV red low physical and ML evidence is NON_CONCLUSIVE',
        () {
      final result = HCVContextFreeDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 2,
          reality: 0,
          periodic: 2,
          stable: 2,
          median: 0.01014,
          globalHz: 2.8645,
          spectral: 0.5781,
          spatial: 7,
        ),
        ml: _video(
          predicted: 'SCREEN_MONITOR',
          probability: 0.7094,
          frameScores: <int>[71, 64],
        ),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
    });

    test('D56D fabric: even STRONG old mini-video cannot override REALITY still',
        () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.0076,
          globalHz: 0,
          spectral: 0,
        ),
        ml: _photo(
          predicted: 'REALITY_ROOM',
          probability: 0.1829,
          full: 94,
          content: 18,
        ),
        photoTemporalMl: _video(
          predicted: 'SCREEN_MONITOR',
          probability: 0.95,
          frameScores: <int>[95, 93, 81],
          allScreen: true,
        ),
        base: _legacyStrong(),
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('0B39 one-frame VIDEO 95 does not produce DISPLAY', () {
      final result = HCVContextFreeDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.0052,
          globalHz: 0,
          spectral: 0,
        ),
        ml: _video(
          predicted: 'SCREEN_PHONE',
          probability: 0.9503,
          frameScores: <int>[95, 49, 33],
        ),
        base: _legacyStrong(),
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('scene with embedded monitor cannot be promoted by weak semantics',
        () {
      final result = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.0067,
          globalHz: 0,
          spectral: 0,
        ),
        ml: _photo(
          predicted: 'SCREEN_MONITOR',
          probability: 0.7113,
          full: 71,
          content: 95,
        ),
        photoTemporalMl: _video(
          predicted: 'SCREEN_MONITOR',
          probability: 0.84,
          frameScores: <int>[84, 78, 71],
          allScreen: true,
        ),
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('PHOTO raw ML and VIDEO raw ML strong evidence are preserved', () {
      final photo = HCVContextFreeDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0,
          globalHz: 0,
          spectral: 0,
        ),
        ml: _photo(
          predicted: 'SCREEN_MONITOR',
          probability: 0.997,
          full: 100,
          content: 100,
        ),
      );
      final video = HCVContextFreeDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0,
          globalHz: 0,
          spectral: 0,
        ),
        ml: _video(
          predicted: 'SCREEN_MONITOR',
          probability: 0.9534,
          frameScores: <int>[95, 94, 92],
        ),
      );
      expect(photo.decision, 'STRONG_DISPLAY_RISK');
      expect(video.decision, 'STRONG_DISPLAY_RISK');
    });

    test('restored camera path supplies BOTH source families for PHOTO/VIDEO',
        () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      final policy =
          File('lib/hcv_context_free_display_policy.dart').readAsStringSync();

      expect(
        camera,
        contains('combinePhotoDisplayRiskFromPreCaptureEvidence('),
      );
      expect(
        camera,
        contains('combineVideoDisplayRiskFromCaptureEvidence('),
      );
      expect(
        RegExp(r'photoTemporalMl: photoTemporalMl,')
            .allMatches(camera)
            .length,
        greaterThanOrEqualTo(2),
      );
      expect(camera, contains('photoTemporalOptical: photoTemporalOptical'));
      expect(camera, contains('base: legacyFusion'));
      expect(camera, isNot(contains('HCVDisplayFinalPolicy.resolve(')));
      expect(policy, contains('coherentDisplayPeriodicityEvidence'));
      expect(policy, isNot(contains('HCVSceneContextEvidence')));
    });
  });
}

HCVDisplayRiskResult _legacyStrong() => const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 95,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['LEGACY_TEMPORAL_ML'],
      strongSources: <String>['LEGACY_TEMPORAL_ML'],
      reasons: <String>['LEGACY_DISPLAY_RISK'],
    );

Map<String, dynamic> _hfr({
  required int display,
  required int reality,
  required int periodic,
  required int stable,
  required double median,
  required double globalHz,
  required double spectral,
  int spatial = 9,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.0,
      'coherentDisplayPeriodicity': false,
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': periodic,
        'stableCellCount': stable,
        'medianCellPeriodicityStrength': median,
        'dominantTemporalFrequencyHz': globalHz,
        'globalSpectralConcentration': spectral,
      },
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'mixedSceneDetected': display > 0,
        'displayLikeCellCount': display,
        'realityLikeCellCount': reality,
        'spatialFamilyCellCount': spatial,
        'harmonicAwareSpatialFamilyCellCount': 9,
        'rowTimeFamilyCellCount': 9,
      },
    };

Map<String, dynamic> _photo({
  required String predicted,
  required double probability,
  required int full,
  required int content,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': predicted,
      'screenProbability': probability,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
      },
    };

Map<String, dynamic> _video({
  required String predicted,
  required double probability,
  required List<int> frameScores,
  bool allScreen = false,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': predicted,
      'screenProbability': probability,
      'framesAnalyzed': frameScores.length,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (final score in frameScores)
          <String, dynamic>{
            'predictedClass': allScreen || score >= 60
                ? 'SCREEN_MONITOR'
                : 'REALITY_ROOM',
            'screenProbability': score / 100.0,
            'signals': <String, dynamic>{
              'fullFrameRiskScore': score,
              'contentAreaRiskScore': score,
            },
          },
      ],
    };
