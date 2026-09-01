import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _geometryRealityLive() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': 20,
      'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
      'activeProbeVersion': 4,
      'signals': {
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'activeChallengeIndeterminate': true,
      },
      'geometryChallenge': {
        'sceneClass': 'REALITY',
        'realityEvidence': true,
        'planarEvidence': false,
      },
    };

Map<String, dynamic> _photoMonitorMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRiskScore': 98,
      'screenProbability': 0.9827,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.949,
      'signals': {
        'fullFrameRiskScore': 98,
        'contentAreaRiskScore': 94,
      },
    };

Map<String, dynamic> _videoMonitorMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 4,
      'screenReplayRiskScore': 97,
      'screenProbability': 0.9746,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.9064,
      'maxFrameScreenReplayRiskScore': 97,
      'averageScreenReplayRiskScore': 94.0,
      'strongScreenFrameCount': 4,
      'mediumScreenFrameCount': 4,
      'signals': {
        'fullFrameRiskScore': 97,
        'contentAreaRiskScore': 99,
      },
    };

Map<String, dynamic> _photoRealMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRiskScore': 45,
      'screenProbability': 0.4458,
      'predictedClass': 'REALITY_ROOM',
      'predictedClassConfidence': 0.4621,
      'signals': {
        'fullFrameRiskScore': 45,
        'contentAreaRiskScore': 8,
      },
    };

Map<String, dynamic> _videoRealMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'screenReplayRiskScore': 38,
      'screenProbability': 0.3792,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.3749,
      'maxFrameScreenReplayRiskScore': 38,
      'averageScreenReplayRiskScore': 21.6667,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'signals': {
        'fullFrameRiskScore': 38,
        'contentAreaRiskScore': 62,
      },
    };

void main() {
  group('Phase C ML/geometry corroboration regressions', () {
    test('PHOTO monitor dual-region ML agreement resolves geometry conflict',
        () {
      final result = HCVDisplayRiskFusion.combine([
        _geometryRealityLive(),
        _photoMonitorMl(),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(result.score, greaterThanOrEqualTo(85));
      expect(
        result.reasons,
        contains('ML_SCREEN_DUAL_REGION_CONFIRMED'),
      );
      expect(
        result.reasons,
        contains(
          'ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE',
        ),
      );
    });

    test('VIDEO monitor persistent strong ML frames resolve geometry conflict',
        () {
      final result = HCVDisplayRiskFusion.combine([
        _geometryRealityLive(),
        _videoMonitorMl(),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(result.score, greaterThanOrEqualTo(85));
      expect(
        result.reasons,
        contains('ML_SCREEN_MULTI_FRAME_PERSISTENCE_CONFIRMED'),
      );
      expect(
        result.reasons,
        contains(
          'ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE',
        ),
      );
    });

    test('PHOTO real scene is not promoted by the geometry-conflict exception',
        () {
      final result = HCVDisplayRiskFusion.combine([
        _geometryRealityLive(),
        _photoRealMl(),
      ]);

      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
      expect(
        result.reasons,
        isNot(contains('ML_SCREEN_DUAL_REGION_CONFIRMED')),
      );
    });

    test('VIDEO real scene with weak inconsistent ML is not promoted', () {
      final result = HCVDisplayRiskFusion.combine([
        _geometryRealityLive(),
        _videoRealMl(),
      ]);

      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
      expect(
        result.reasons,
        isNot(contains('ML_SCREEN_MULTI_FRAME_PERSISTENCE_CONFIRMED')),
      );
    });

    test('active reflected-reality evidence still blocks ML override', () {
      final live = _geometryRealityLive();
      live['signals'] = {
        ...Map<String, dynamic>.from(live['signals'] as Map),
        'reflectedRealityEvidence': true,
      };

      final result = HCVDisplayRiskFusion.combine([
        live,
        _videoMonitorMl(),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('ML_SCREEN_AND_REFLECTED_REALITY_CONFLICT'),
      );
    });
  });
}
