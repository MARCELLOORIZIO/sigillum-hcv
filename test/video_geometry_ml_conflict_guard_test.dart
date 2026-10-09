import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('VIDEO geometry/ML conflict guard', () {
    test('DE13 night traffic false positive becomes NON_CONCLUSIVE', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.012602843277867135,
          spatial: 9,
          harmonic: 9,
          row: 9,
        ),
        ml: _videoMl(
          probability: 0.9709,
          scores: const <int>[97, 96, 93, 70],
        ),
        passiveOptical: _optical(
          score: 20,
          flat: true,
          lowMicro: true,
          rgbPhase: 0.3267,
        ),
        passiveSceneContext: _realityGeometry(
          depthDispersion: 0.4768,
          planarCoherence: 0.2729,
        ),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
      expect(
        result.reasons,
        contains('VIDEO_STRONG_ML_CONFLICT_WITH_POSITIVE_MULTI_DEPTH_REALITY'),
      );
      expect(
        result.reasons,
        contains('SCENE_CONTEXT_USED_ONLY_AS_CONTRADICTION_GUARD'),
      );
      expect(
        result.reasons,
        isNot(contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY')),
      );
    });

    test('archive90 monitor 1x remains STRONG despite REALITY geometry', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 4,
          median: 0.05234460894377347,
          spatial: 9,
          harmonic: 9,
          row: 9,
        ),
        ml: _videoMl(
          probability: 0.9906,
          scores: const <int>[99, 99, 99, 98],
        ),
        passiveOptical: _optical(
          score: 20,
          flat: false,
          lowMicro: true,
          rgbPhase: 0.8143,
        ),
        passiveSceneContext: _realityGeometry(
          depthDispersion: 0.7283,
          planarCoherence: 0.1359,
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY'),
      );
    });

    test('archive90 monitor zoom remains STRONG', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.030750650277535665,
          spatial: 9,
          harmonic: 9,
          row: 9,
        ),
        ml: _videoMl(
          probability: 0.9820,
          scores: const <int>[98, 96],
        ),
        passiveOptical: _optical(
          score: 20,
          flat: false,
          lowMicro: true,
          rgbPhase: 0.0,
        ),
        passiveSceneContext: _unknownGeometry(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY'),
      );
    });

    test('archive99 TV 1x remains STRONG with HFR local corroboration', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 4,
          reality: 0,
          periodic: 6,
          stable: 5,
          median: 0.1262666330281909,
          spatial: 9,
          harmonic: 9,
          row: 9,
        ),
        ml: _videoMl(
          probability: 0.8516,
          scores: const <int>[85, 70],
        ),
        passiveOptical: _optical(
          score: 20,
          flat: false,
          lowMicro: true,
          rgbPhase: 0.9987,
        ),
        passiveSceneContext: _realityGeometry(
          depthDispersion: 0.4375,
          planarCoherence: 0.3498,
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_MULTI_EVIDENCE_DISPLAY'),
      );
    });

    test('archive99 TV zoom remains STRONG via HFR partial corroboration', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 8,
          reality: 0,
          periodic: 9,
          stable: 8,
          median: 0.28987071395799247,
          spatial: 9,
          harmonic: 9,
          row: 9,
        ),
        ml: _videoMl(
          probability: 0.5504,
          scores: const <int>[55, 16],
        ),
        passiveOptical: _optical(
          score: 0,
          flat: false,
          lowMicro: false,
          rgbPhase: 0.9988,
        ),
        passiveSceneContext: _unknownGeometry(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY'),
      );
    });

    test('historical 20BC strong result is preserved until ground truth is known', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.02682346662046087,
          spatial: 9,
          harmonic: 9,
          row: 9,
        ),
        ml: _videoMl(
          probability: 0.9975,
          scores: const <int>[100, 100],
        ),
        passiveOptical: _optical(
          score: 20,
          flat: true,
          lowMicro: true,
          rgbPhase: 0.7178,
        ),
        passiveSceneContext: _realityGeometry(
          depthDispersion: 0.5367,
          planarCoherence: 0.2642,
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY'),
      );
    });

    test('known archive90 textile VIDEO false positive is also guarded', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.035485313241234995,
          spatial: 6,
          harmonic: 9,
          row: 9,
        ),
        ml: _videoMl(
          probability: 0.9586,
          scores: const <int>[96, 89],
        ),
        passiveOptical: _optical(
          score: 20,
          flat: true,
          lowMicro: true,
          rgbPhase: 0.0,
        ),
        passiveSceneContext: _realityGeometry(
          depthDispersion: 0.5948,
          planarCoherence: 0.1943,
        ),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('VIDEO_STRONG_ML_CONFLICT_WITH_POSITIVE_MULTI_DEPTH_REALITY'),
      );
    });

    test('missing HFR cannot activate the new contradiction guard', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: null,
        ml: _videoMl(
          probability: 0.99,
          scores: const <int>[99, 98],
        ),
        passiveOptical: _optical(
          score: 20,
          flat: true,
          lowMicro: true,
          rgbPhase: 0.0,
        ),
        passiveSceneContext: _realityGeometry(
          depthDispersion: 0.8,
          planarCoherence: 0.1,
        ),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY'),
      );
    });
  });
}

Map<String, dynamic> _hfr({
  required int display,
  required int reality,
  required int periodic,
  required int stable,
  required double median,
  required int spatial,
  required int harmonic,
  required int row,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': 'COMPARABLE',
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'displayLikeCellCount': display,
        'realityLikeCellCount': reality,
        'spatialFamilyCellCount': spatial,
        'harmonicAwareSpatialFamilyCellCount': harmonic,
        'rowTimeFamilyCellCount': row,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': periodic,
        'stableCellCount': stable,
        'medianCellPeriodicityStrength': median,
      },
    };

Map<String, dynamic> _videoMl({
  required double probability,
  required List<int> scores,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (final score in scores)
          <String, dynamic>{
            'predictedClass': 'SCREEN_MONITOR',
            'signals': <String, dynamic>{
              'fullFrameRiskScore': score,
              'contentAreaRiskScore': score,
            },
          },
      ],
    };

Map<String, dynamic> _optical({
  required int score,
  required bool flat,
  required bool lowMicro,
  required double rgbPhase,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'scanMode': 'EVERY_15_SECONDS_FAST_SAMPLE',
      'screenReplayRiskScore': score,
      'signals': <String, dynamic>{
        'flatSceneUniformity': flat,
        'lowMicroVariation': lowMicro,
        'rgbPhaseConsistencyScore': rgbPhase,
        'strongDisplayTrace': false,
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
      },
    };

Map<String, dynamic> _realityGeometry({
  required double depthDispersion,
  required double planarCoherence,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_PASSIVE_SCENE_CONTEXT_CAPTURE_V1',
      'analysisStatus': 'ANALYZED',
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'REALITY',
        'realityEvidence': true,
        'planarEvidence': false,
        'depthDispersion': depthDispersion,
        'planarCoherence': planarCoherence,
        'reasons': const <String>[
          'MULTI_DEPTH_PARALLAX_DETECTED',
          'NON_PLANAR_CAMERA_MOTION_RESPONSE',
        ],
      },
      'sensorSignals': const <String, dynamic>{
        'signalsRecorded': true,
      },
    };

Map<String, dynamic> _unknownGeometry() => const <String, dynamic>{
      'type': 'SIGILLUM_PASSIVE_SCENE_CONTEXT_CAPTURE_V1',
      'analysisStatus': 'ANALYZED',
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'UNKNOWN',
        'realityEvidence': false,
        'planarEvidence': false,
        'reasons': <String>['GEOMETRY_RESPONSE_AMBIGUOUS'],
      },
    };
