import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> _photoBuild65Live() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': 20,
      'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
      'sceneClass': 'REALITY',
      'reason':
          'ACTIVE_V5|MULTI_DEPTH_PARALLAX_DETECTED|NON_PLANAR_CAMERA_MOTION_RESPONSE|GEOMETRIC_REALITY_WITHOUT_DISPLAY_CONFLICT',
      'signals': const <String, dynamic>{
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'sceneRealityEvidence': true,
        'geometricRealityEvidence': true,
        'planarSceneEvidence': false,
        'activeChallengeIndeterminate': false,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'pairedFlickerTrace': false,
        'displayBandTrace': false,
        'horizontalRefreshBands': false,
      },
      'geometryChallenge': const <String, dynamic>{
        'sceneClass': 'REALITY',
        'realityEvidence': true,
        'planarEvidence': false,
      },
      'videoEquivalentAvailable': true,
      'videoEquivalentDisplayRisk': const <String, dynamic>{
        'risk': 'LOW',
        'score': 20,
        'decision': 'NO_DISPLAY_EVIDENCE',
        'analysisStatus': 'COMPLETE',
        'evidenceSources': <String>[],
        'strongSources': <String>[],
        'reasons': <String>[
          'SIGNED_GEOMETRIC_REALITY_OVERRIDES_UNCORROBORATED_DISPLAY_SIGNALS',
        ],
      },
    };

Map<String, dynamic> _photoBuild65Ml() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRiskScore': 99,
      'screenProbability': 0.9892,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.972,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 99,
        'contentAreaRiskScore': 99,
      },
      'decisionRole': 'POST_CAPTURE_DIAGNOSTIC_ONLY',
    };

Map<String, dynamic> _videoBuild65Live() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'sceneClass': 'UNKNOWN',
      'reason':
          'ACTIVE_V5|ACTIVE_CHALLENGE_INDETERMINATE|GEOMETRY_RESPONSE_AMBIGUOUS',
      'signals': const <String, dynamic>{
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'sceneRealityEvidence': false,
        'geometricRealityEvidence': false,
        'planarSceneEvidence': false,
        'activeChallengeIndeterminate': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'pairedFlickerTrace': false,
        'displayBandTrace': false,
        'horizontalRefreshBands': false,
      },
      'geometryChallenge': const <String, dynamic>{
        'sceneClass': 'UNKNOWN',
        'realityEvidence': false,
        'planarEvidence': false,
      },
      'videoEquivalentAvailable': false,
    };

Map<String, dynamic> _videoBuild65Ml() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 4,
      'screenReplayRiskScore': 91,
      'screenProbability': 0.9843,
      'predictedClass': 'SCREEN_PHONE',
      'predictedClassConfidence': 0.8432,
      'maxFrameScreenReplayRiskScore': 98,
      'averageScreenReplayRiskScore': 91.25,
      'strongScreenFrameCount': 1,
      'mediumScreenFrameCount': 4,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 98,
        'contentAreaRiskScore': 96,
      },
    };

Map<String, dynamic> _photoRealityMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRiskScore': 45,
      'screenProbability': 0.4458,
      'predictedClass': 'REALITY_ROOM',
      'predictedClassConfidence': 0.4621,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 45,
        'contentAreaRiskScore': 8,
      },
    };

Map<String, dynamic> _videoRealityMl() => {
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
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 38,
        'contentAreaRiskScore': 62,
      },
    };

void main() {
  group('Build 65 physical display recall regressions', () {
    test(
        'PHOTO monitor spatially corroborated ML survives false reality geometry',
        () {
      final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
        _photoBuild65Live(),
        _photoBuild65Ml(),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(result.score, greaterThanOrEqualTo(94));
      expect(result.reasons, contains('ML_SCREEN_DUAL_REGION_CONFIRMED'));
    });

    test(
        'VIDEO monitor 4-of-4 medium-or-strong screen frames resolves UNKNOWN geometry',
        () {
      final result = combineVideoDisplayRiskFromCaptureEvidence([
        _videoBuild65Live(),
        _videoBuild65Ml(),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(result.score, greaterThanOrEqualTo(94));
      expect(
        result.reasons,
        contains('ML_SCREEN_MULTI_FRAME_CONSISTENCY_CONFIRMED'),
      );
    });

    test('PHOTO real scene remains non-display under spatial exception', () {
      final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
        _photoBuild65Live(),
        _photoRealityMl(),
      ]);

      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    });

    test('VIDEO real scene with weak inconsistent ML remains non-display', () {
      final result = combineVideoDisplayRiskFromCaptureEvidence([
        _videoBuild65Live(),
        _videoRealityMl(),
      ]);

      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    });
  });
}
