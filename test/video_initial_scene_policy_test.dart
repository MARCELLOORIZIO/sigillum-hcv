import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('VIDEO initial scene decision window', () {
    test('later monitor cannot redefine a REALITY opening', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.02,
        ),
        ml: _videoMl(<Map<String, dynamic>>[
          _frame(0, 'REALITY_ROOM', 0.12, 12),
          _frame(3, 'REALITY_ROOM', 0.18, 18),
          _frame(6, 'REALITY_ROOM', 0.16, 16),
          _frame(9, 'SCREEN_MONITOR', 0.99, 99),
          _frame(12, 'SCREEN_MONITOR', 0.98, 98),
          _frame(15, 'SCREEN_MONITOR', 0.97, 97),
        ]),
        passiveOptical: _optical(<Map<String, dynamic>>[
          _opticalSegment(0, 0, strong: false),
          _opticalSegment(15, 95, strong: true),
        ]),
        passiveSceneContext: _realityGeometry(),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('VIDEO_INITIAL_SCENE_NO_CORROBORATED_DISPLAY_EVIDENCE'),
      );
      expect(
        result.reasons,
        isNot(contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY')),
      );
    });

    test('monitor present in opening remains STRONG', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          median: 0.03,
        ),
        ml: _videoMl(<Map<String, dynamic>>[
          _frame(0, 'SCREEN_MONITOR', 0.98, 98),
          _frame(3, 'SCREEN_MONITOR', 0.97, 97),
          _frame(6, 'SCREEN_MONITOR', 0.96, 96),
          _frame(9, 'REALITY_ROOM', 0.10, 10),
        ]),
        passiveOptical: _optical(<Map<String, dynamic>>[
          _opticalSegment(0, 20, strong: false, flat: false),
        ]),
        passiveSceneContext: _unknownGeometry(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY'),
      );
    });

    test('HFR full-frame display remains STRONG even with REALITY context', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 9,
          reality: 0,
          periodic: 9,
          stable: 9,
          median: 0.30,
          fullFrame: true,
        ),
        ml: _videoMl(<Map<String, dynamic>>[
          _frame(0, 'REALITY_ROOM', 0.08, 8),
          _frame(3, 'REALITY_ROOM', 0.09, 9),
        ]),
        passiveOptical: _optical(<Map<String, dynamic>>[
          _opticalSegment(0, 0, strong: false, flat: false),
        ]),
        passiveSceneContext: _realityGeometry(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
    });

    test('historical partial-HFR TV stays STRONG without the full reality guard',
        () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 7,
          reality: 0,
          periodic: 8,
          stable: 7,
          median: 0.21,
        ),
        ml: _videoMl(<Map<String, dynamic>>[
          _frame(0, 'REALITY_OUTDOOR', 0.20, 20),
          _frame(3, 'REALITY_OUTDOOR', 0.30, 30),
        ]),
        passiveOptical: _optical(<Map<String, dynamic>>[
          _opticalSegment(0, 0, strong: false, flat: false),
        ]),
        passiveSceneContext: _unknownGeometry(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY'),
      );
    });

    test('Archive 1 HFR partial conflicts with REALITY opening and is amber', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          display: 8,
          reality: 0,
          periodic: 8,
          stable: 9,
          median: 0.2202752533674873,
        ),
        ml: _videoMl(<Map<String, dynamic>>[
          _frame(0, 'REALITY_ROOM', 0.2361, 24),
          _frame(3, 'REALITY_ROOM', 0.3747, 37),
          _frame(6, 'REALITY_ROOM', 0.1407, 14),
        ]),
        passiveOptical: _optical(<Map<String, dynamic>>[
          _opticalSegment(0, 0, strong: false, flat: false),
        ]),
        passiveSceneContext: _realityGeometry(),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
      expect(
        result.reasons,
        contains('VIDEO_INITIAL_SCENE_HFR_CONFLICT_WITH_MULTI_DEPTH_REALITY'),
      );
      expect(
        result.reasons,
        isNot(contains('BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY')),
      );
    });

    test('camera certificate declares initial scene and trimming policy', () {
      final camera = File('lib/camera_page.dart').readAsStringSync();

      expect(
        camera,
        contains('"type": "SIGILLUM_VIDEO_INITIAL_SCENE_POLICY_V1"'),
      );
      expect(camera, contains('"decisionWindowSeconds": 6'));
      expect(camera, contains('"laterVideoDisplayObservations": "DIAGNOSTIC_ONLY"'));
      expect(camera, contains('"initialSegmentPreservationRequired": true'));
    });
  });
}

Map<String, dynamic> _frame(
  double second,
  String predictedClass,
  double screenProbability,
  int score,
) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'approxVideoSecond': second,
      'predictedClass': predictedClass,
      'screenProbability': screenProbability,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': score,
        'contentAreaRiskScore': score,
      },
    };

Map<String, dynamic> _videoMl(List<Map<String, dynamic>> frames) {
  final all = <Map<String, dynamic>>[...frames];
  all.sort((a, b) => ((b['screenProbability'] as num).toDouble())
      .compareTo((a['screenProbability'] as num).toDouble()));
  final worst = all.first;
  return <String, dynamic>{
    ...worst,
    'analysisStatus': 'ANALYZED',
    'scanMode': 'VIDEO_MULTI_FRAME_ML_CLASSIFIER',
    'videoFrameAnalyses': all,
  };
}

Map<String, dynamic> _hfr({
  required int display,
  required int reality,
  required int periodic,
  required int stable,
  required double median,
  bool fullFrame = false,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': 'COMPARABLE',
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrame,
        'displayLikeCellCount': display,
        'realityLikeCellCount': reality,
        'spatialFamilyCellCount': 9,
        'harmonicAwareSpatialFamilyCellCount': 9,
        'rowTimeFamilyCellCount': 9,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': periodic,
        'stableCellCount': stable,
        'medianCellPeriodicityStrength': median,
      },
    };

Map<String, dynamic> _opticalSegment(
  int second,
  int score, {
  required bool strong,
  bool flat = true,
}) =>
    <String, dynamic>{
      'startSecond': second,
      'screenReplayRiskScore': score,
      'screenReplayRisk': score >= 70 ? 'HIGH' : 'LOW',
      'repetitiveTextureScore': 0.0,
      'latticeRegularityScore': 0.0,
      'latticeDefectScore': 0.0,
      'macroPatternScore': 0.0,
      'rgbPhaseConsistencyScore': 0.0,
      'physicalRepeatingTextureLikely': false,
      'signals': <String, dynamic>{
        'strongDisplayTrace': strong,
        'structuralDisplayTrace': strong,
        'confirmedDisplayTrace': strong,
        'flatSceneUniformity': flat,
        'lowMicroVariation': true,
        'rgbPhaseConsistencyScore': 0.0,
      },
    };

Map<String, dynamic> _optical(List<Map<String, dynamic>> segments) {
  final worst = [...segments]
    ..sort((a, b) => ((b['screenReplayRiskScore'] as num).toInt())
        .compareTo((a['screenReplayRiskScore'] as num).toInt()));
  return <String, dynamic>{
    ...worst.first,
    'analysisStatus': 'ANALYZED',
    'scanMode': 'EVERY_15_SECONDS_FAST_SAMPLE',
    'segments': segments,
  };
}

Map<String, dynamic> _realityGeometry() => const <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'REALITY',
        'realityEvidence': true,
        'planarEvidence': false,
        'reasons': <String>[
          'MULTI_DEPTH_PARALLAX_DETECTED',
          'NON_PLANAR_CAMERA_MOTION_RESPONSE',
        ],
      },
    };

Map<String, dynamic> _unknownGeometry() => const <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'geometryChallenge': <String, dynamic>{
        'sceneClass': 'UNKNOWN',
        'realityEvidence': false,
        'planarEvidence': false,
        'reasons': <String>['GEOMETRY_RESPONSE_AMBIGUOUS'],
      },
    };
