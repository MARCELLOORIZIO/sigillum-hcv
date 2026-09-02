import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _livePlanarMonitor() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRisk': 'MEDIUM',
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'displayProbability': 0.378,
      'sceneClass': 'UNKNOWN',
      'reason':
          'ACTIVE_V5|ACTIVE_ILLUMINATION_CHALLENGE_NOT_VALID|OFF_PHASES_NOT_REPEATABLE|ACTIVE_ELECTRONIC_CUES_UNCORROBORATED|ACTIVE_CHALLENGE_INDETERMINATE|COHERENT_PLANAR_MOTION_DETECTED|PLANARITY_IS_CORROBORATION_ONLY|GEOM=PLANAR',
      'geometryChallenge': const <String, dynamic>{
        'sceneClass': 'PLANAR',
        'realityEvidence': false,
        'planarEvidence': true,
        'motionMagnitude': 0.1667,
        'flowReliability': 0.6991,
        'directionCoherence': 1.0,
        'depthDispersion': 0.0,
        'planarCoherence': 0.677,
      },
      'signals': const <String, dynamic>{
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'sceneRealityEvidence': false,
        'geometricRealityEvidence': false,
        'planarSceneEvidence': true,
        'activeChallengeIndeterminate': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'strongRefreshTrace': false,
        'displayBandTrace': false,
        'opticalStripeTrace': false,
        'opticalCorroboratedTrace': false,
        'moireFrequencyTrace': true,
        'globalDisplayPulse': true,
        'pairedFlickerTrace': false,
        'uncorroboratedDisplayPattern': true,
        'globalFlicker': true,
        'localRefreshFlicker': true,
        'horizontalRefreshBands': false,
        'movingRefreshBands': false,
      },
      'videoEquivalentAvailable': false,
    };

Map<String, dynamic> _mlPlanarMonitor() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'screenReplayRisk': 'HIGH',
      'screenReplayRiskScore': 99,
      'screenProbability': 0.9932,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.9924,
      'maxFrameScreenReplayRiskScore': 99,
      'strongScreenFrameCount': 2,
      'mediumScreenFrameCount': 3,
      'averageScreenReplayRiskScore': 96.3333,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 99,
        'contentAreaRiskScore': 99,
      },
    };

Map<String, dynamic> _planarRealityControl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 38,
      'screenProbability': 0.3792,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.3749,
      'maxFrameScreenReplayRiskScore': 38,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 21.6667,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 38,
        'contentAreaRiskScore': 62,
      },
    };

void main() {
  group('Build 66 PLANAR multi-frame regression', () {
    test('corroborated PLANAR monitor is promoted to strong display risk', () {
      final result = HCVDisplayRiskFusion.combine([
        _livePlanarMonitor(),
        _mlPlanarMonitor(),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(result.score, 99);
      expect(
        result.reasons,
        contains('ML_SCREEN_MULTI_FRAME_CONSISTENCY_CONFIRMED'),
      );
      expect(
        result.reasons,
        contains(
          'ML_PLANAR_GEOMETRY_CORROBORATED_BY_MULTI_FRAME_SCREEN_EVIDENCE',
        ),
      );
    });

    test('PLANAR geometry alone never promotes weak ML screen evidence', () {
      final result = HCVDisplayRiskFusion.combine([
        _livePlanarMonitor(),
        _planarRealityControl(),
      ]);

      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
      expect(result.score, lessThan(85));
    });
  });
}
