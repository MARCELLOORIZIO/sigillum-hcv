import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('BUILD124 multi-evidence fusion', () {
    test('reads periodic/stable counters from real coherent HFR block', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 5,
          reality: 0,
          periodic: 6,
          stable: 5,
          medianPeriodicity: 0.217,
        ),
        ml: _videoMl(
          probability: 0.20,
          scores: const <int>[20, 20],
          screen: false,
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY'),
      );
    });

    test('Gentlemen PHOTO F48B pattern is recovered by physical HFR', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 5,
          reality: 0,
          periodic: 8,
          stable: 6,
          medianPeriodicity: 0.167391,
        ),
        stillMl: _stillMl(
          probability: 0.6418,
          full: 64,
          content: 81,
        ),
        temporalMl: _videoMl(
          probability: 0.9594,
          scores: const <int>[96, 95, 94],
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('BMW PHOTO BA4D uses still plus mini-video plus HFR corroboration',
        () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 2,
          reality: 0,
          periodic: 2,
          stable: 2,
          medianPeriodicity: 0.054431,
        ),
        stillMl: _stillMl(
          probability: 0.5968,
          full: 60,
          content: 82,
        ),
        temporalMl: _videoMl(
          probability: 0.5590,
          scores: const <int>[56, 56, 42],
          screenFrames: 2,
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_PHOTO_MULTI_EVIDENCE_DISPLAY'),
      );
    });

    test('red TV VIDEO 9C4B requires temporal plus HFR corroboration', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 2,
          reality: 0,
          periodic: 2,
          stable: 2,
          medianPeriodicity: 0.010146,
          spatial: 7,
        ),
        ml: _videoMl(
          probability: 0.7094,
          scores: const <int>[71, 64],
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_MULTI_EVIDENCE_DISPLAY'),
      );
    });

    test('historical wallpaper D56D is not recovered by temporal ML alone', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          medianPeriodicity: 0.007608,
        ),
        stillMl: _stillMl(
          probability: 0.1829,
          full: 94,
          content: 18,
          screen: false,
        ),
        temporalMl: _videoMl(
          probability: 0.9452,
          scores: const <int>[95, 93, 81],
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('room with monitors remains REALITY without persistent corroboration',
        () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          medianPeriodicity: 0.008032,
          spatial: 7,
        ),
        ml: _videoMl(
          probability: 0.8059,
          scores: const <int>[81, 48, 44, 43],
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('future corroborated borderline evidence remains inconclusive', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 1,
          reality: 0,
          periodic: 1,
          stable: 1,
          medianPeriodicity: 0.03,
        ),
        ml: _videoMl(
          probability: 0.64,
          scores: const <int>[68, 63, 40],
        ),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('ABSENCE_OF_DISPLAY_PROOF_IS_NOT_POSITIVE_REALITY_PROOF'),
      );
    });

    test('camera verdict uses BUILD124 and never scene-context final policy',
        () {
      final source = File('lib/camera_page.dart').readAsStringSync();

      expect(
        source,
        contains('HCVMultiEvidenceDisplayPolicy.resolvePhoto('),
      );
      expect(
        source,
        contains('HCVMultiEvidenceDisplayPolicy.resolveVideo('),
      );
      expect(source, isNot(contains('HCVDisplayFinalPolicy.resolve(')));
    });

    test('BUILD124 HFR paths match production certificate schema', () {
      final source =
          File('lib/hcv_multi_evidence_display_policy.dart').readAsStringSync();

      expect(source, contains("probe['displayRealityEvidenceV3']"));
      expect(
        source,
        contains("probe['coherentDisplayPeriodicityEvidence']"),
      );
      expect(source, contains("coherent['periodicCellCount']"));
      expect(source, contains("coherent['stableCellCount']"));
      expect(source, isNot(contains("v3['periodicCellCount']")));
      expect(source, isNot(contains("v3['stableCellCount']")));
    });

    test('scene context geometry and sensors cannot enter BUILD124 verdict',
        () {
      final source =
          File('lib/hcv_multi_evidence_display_policy.dart').readAsStringSync();

      expect(source, isNot(contains('HCVSceneContextEvidence')));
      expect(source, isNot(contains('geometryProbe')));
      expect(source, isNot(contains('sensorSignals')));
      expect(source, isNot(contains('DISPLAY_EMBEDDED_IN_REALITY')));
    });

    test('PHOTO technical cycle remains 1.5 seconds and three ML frames', () {
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
  required int display,
  required int reality,
  required int periodic,
  required int stable,
  required double medianPeriodicity,
  int spatial = 9,
  int harmonic = 9,
  int row = 9,
  bool fullFrame = false,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrame,
        'displayLikeCellCount': display,
        'realityLikeCellCount': reality,
        'spatialFamilyCellCount': spatial,
        'harmonicAwareSpatialFamilyCellCount': harmonic,
        'rowTimeFamilyCellCount': row,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': periodic,
        'stableCellCount': stable,
        'medianCellPeriodicityStrength': medianPeriodicity,
      },
    };

Map<String, dynamic> _stillMl({
  required double probability,
  required int full,
  required int content,
  bool screen = true,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': screen ? 'SCREEN_MONITOR' : 'REALITY_ROOM',
      'screenProbability': probability,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
      },
    };

Map<String, dynamic> _videoMl({
  required double probability,
  required List<int> scores,
  bool screen = true,
  int? screenFrames,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': screen ? 'SCREEN_MONITOR' : 'REALITY_ROOM',
      'screenProbability': probability,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (var i = 0; i < scores.length; i++)
          <String, dynamic>{
            'predictedClass': i < (screenFrames ?? scores.length)
                ? 'SCREEN_MONITOR'
                : 'REALITY_ROOM',
            'signals': <String, dynamic>{
              'fullFrameRiskScore': scores[i],
              'contentAreaRiskScore': scores[i],
            },
          },
      ],
    };
