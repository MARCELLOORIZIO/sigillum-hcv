import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _photoRealityLive() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRisk': 'MEDIUM',
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'sceneClass': 'UNKNOWN',
      'localTemporalFlickerScore': 0.5854,
      'refreshBandScore': 0.1755,
      'fineStripeScore': 0.0198,
      'fineGridScore': 0.9799,
      'moireFrequencyScore': 0.4976,
      'dynamicChallengeScore': 0.3885,
      'persistentPatternScore': 0.9857,
      'globalFlickerScore': 0.20,
      'reason':
          'ACTIVE_V5|EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH|ELECTRONIC_DISPLAY_CUES_PRESENT|GEOMETRY_RESPONSE_AMBIGUOUS|GEOM=UNKNOWN',
      'geometryChallenge': const <String, dynamic>{
        'sceneClass': 'UNKNOWN',
        'realityEvidence': false,
        'planarEvidence': false,
        'motionMagnitude': 0.6667,
        'flowReliability': 0.7672,
        'depthDispersion': 0.2438,
        'planarCoherence': 0.5649,
      },
      'signals': const <String, dynamic>{
        'rawActiveDisplayEvidence': true,
        'activeIlluminationDisplayEvidence': true,
        'reflectedRealityEvidence': false,
        'sceneRealityEvidence': false,
        'geometricRealityEvidence': false,
        'planarSceneEvidence': false,
        'activeChallengeIndeterminate': false,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'strongRefreshTrace': false,
        'displayBandTrace': false,
        'opticalStripeTrace': false,
        'opticalCorroboratedTrace': false,
        'moireFrequencyTrace': true,
        'globalDisplayPulse': true,
        'pairedFlickerTrace': true,
        'uncorroboratedDisplayPattern': false,
        'globalFlicker': true,
        'localRefreshFlicker': true,
        'horizontalRefreshBands': true,
        'movingRefreshBands': false,
      },
    };

Map<String, dynamic> _photoRealityPassive() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 15,
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 20,
      'signals': const <String, dynamic>{
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'strongDisplayTrace': false,
      },
    };

Map<String, dynamic> _photoRealityTemporalMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 1,
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 0,
      'screenProbability': 0.0033,
      'predictedClass': 'REALITY_OUTDOOR',
      'predictedClassConfidence': 0.7358,
      'maxFrameScreenReplayRiskScore': 0,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 0.0,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 0,
        'contentAreaRiskScore': 8,
      },
    };

Map<String, dynamic> _videoRealityLive() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRisk': 'MEDIUM',
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'sceneClass': 'UNKNOWN',
      'localTemporalFlickerScore': 0.1151,
      'refreshBandScore': 0.2309,
      'fineStripeScore': 0.0294,
      'fineGridScore': 0.6863,
      'moireFrequencyScore': 0.6004,
      'dynamicChallengeScore': 0.1677,
      'persistentPatternScore': 0.9857,
      'globalFlickerScore': 0.0152,
      'reason':
          'ACTIVE_V5|EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH|ELECTRONIC_DISPLAY_CUES_PRESENT|MULTI_DEPTH_PARALLAX_DETECTED|NON_PLANAR_CAMERA_MOTION_RESPONSE|ILLUMINATION_AND_GEOMETRY_EVIDENCE_CONFLICT|GEOM=REALITY',
      'geometryChallenge': const <String, dynamic>{
        'sceneClass': 'REALITY',
        'realityEvidence': true,
        'planarEvidence': false,
        'motionMagnitude': 0.1667,
        'flowReliability': 0.6197,
        'depthDispersion': 0.3532,
        'planarCoherence': 0.3146,
        'reasons': <String>[
          'MULTI_DEPTH_PARALLAX_DETECTED',
          'NON_PLANAR_CAMERA_MOTION_RESPONSE',
        ],
      },
      'signals': const <String, dynamic>{
        'rawActiveDisplayEvidence': true,
        'activeIlluminationDisplayEvidence': true,
        'reflectedRealityEvidence': false,
        'sceneRealityEvidence': true,
        'geometricRealityEvidence': true,
        'planarSceneEvidence': false,
        'activeChallengeIndeterminate': false,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'strongRefreshTrace': true,
        'displayBandTrace': false,
        'opticalStripeTrace': false,
        'opticalCorroboratedTrace': false,
        'moireFrequencyTrace': true,
        'globalDisplayPulse': false,
        'pairedFlickerTrace': false,
        'uncorroboratedDisplayPattern': false,
        'globalFlicker': false,
        'localRefreshFlicker': false,
        'horizontalRefreshBands': true,
        'movingRefreshBands': false,
      },
    };

Map<String, dynamic> _videoRealityPassive() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 15,
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 0,
      'signals': const <String, dynamic>{
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'strongDisplayTrace': false,
      },
    };

Map<String, dynamic> _videoRealityMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 4,
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 45,
      'screenProbability': 0.4504,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.4441,
      'maxFrameScreenReplayRiskScore': 45,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 11.5,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 45,
        'contentAreaRiskScore': 35,
      },
      'videoFrameAnalyses': <Map<String, dynamic>>[
        {
          'analysisStatus': 'ANALYZED',
          'screenReplayRiskScore': 45,
          'screenProbability': 0.4504,
          'predictedClass': 'SCREEN_MONITOR',
          'predictedClassConfidence': 0.4441,
        },
        {
          'analysisStatus': 'ANALYZED',
          'screenReplayRiskScore': 1,
          'screenProbability': 0.008,
          'predictedClass': 'REALITY_OUTDOOR',
          'predictedClassConfidence': 0.7474,
        },
        {
          'analysisStatus': 'ANALYZED',
          'screenReplayRiskScore': 0,
          'screenProbability': 0.0004,
          'predictedClass': 'REALITY_ROOM',
          'predictedClassConfidence': 0.8184,
        },
        {
          'analysisStatus': 'ANALYZED',
          'screenReplayRiskScore': 0,
          'screenProbability': 0.003,
          'predictedClass': 'REALITY_OUTDOOR',
          'predictedClassConfidence': 0.4327,
        },
      ],
    };

Map<String, dynamic> _strongMonitorMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 4,
      'screenReplayRisk': 'HIGH',
      'screenReplayRiskScore': 99,
      'screenProbability': 0.994,
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.99,
      'maxFrameScreenReplayRiskScore': 99,
      'strongScreenFrameCount': 4,
      'mediumScreenFrameCount': 4,
      'averageScreenReplayRiskScore': 96.0,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 99,
        'contentAreaRiskScore': 99,
      },
      'videoFrameAnalyses': List<Map<String, dynamic>>.generate(
        4,
        (_) => const <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'screenReplayRiskScore': 99,
          'screenProbability': 0.994,
          'predictedClass': 'SCREEN_MONITOR',
          'predictedClassConfidence': 0.99,
        },
      ),
    };

void main() {
  test('HCV-729930 photo reality overrides uncorroborated ACTIVE texture cues', () {
    final result = HCVDisplayRiskFusion.combine([
      _photoRealityLive(),
      _photoRealityPassive(),
      _photoRealityTemporalMl(),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
    expect(
      result.reasons,
      contains('CROSS_MODAL_REALITY_AGREEMENT_OVERRIDES_UNCORROBORATED_ACTIVE_SIGNAL'),
    );
  });

  test('HCV-90C4 video reality uses multi-frame REALITY consistency', () {
    final result = HCVDisplayRiskFusion.combine([
      _videoRealityLive(),
      _videoRealityPassive(),
      _videoRealityMl(),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
    expect(result.reasons, contains('ML_REALITY_MULTI_FRAME_CONSISTENCY_CONFIRMED'));
    expect(
      result.reasons,
      contains('CROSS_MODAL_REALITY_AGREEMENT_OVERRIDES_UNCORROBORATED_ACTIVE_SIGNAL'),
    );
  });

  test('strong corroborated monitor still overrides geometric REALITY', () {
    final result = HCVDisplayRiskFusion.combine([
      _videoRealityLive(),
      _videoRealityPassive(),
      _strongMonitorMl(),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, greaterThanOrEqualTo(85));
    expect(
      result.reasons,
      contains('ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'),
    );
  });
}
