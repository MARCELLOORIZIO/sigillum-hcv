import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> _photoLive() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'sceneClass': 'UNKNOWN',
      'globalFlickerScore': 0.3187,
      'localTemporalFlickerScore': 0.4271,
      'refreshBandScore': 0.1888,
      'fineStripeScore': 0.0321,
      'fineGridScore': 0.6025,
      'moireFrequencyScore': 0.1278,
      'persistentPatternScore': 0.3771,
      'dynamicChallengeScore': 0.0,
      'videoEquivalentAvailable': true,
      'videoEquivalentDisplayRisk': {
        'risk': 'MEDIUM',
        'score': 45,
        'decision': 'NON_CONCLUSIVE',
        'analysisStatus': 'COMPLETE',
        'evidenceSources': ['ACTIVE_ILLUMINATION', 'LIVE_PREVIEW'],
        'strongSources': <String>[],
        'reasons': ['ML_REALITY_REQUIRES_INDEPENDENT_CORROBORATION'],
      },
      'photoTemporalVideoProbe': {
        'mlScreenReplayAnalysis': {
          'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
          'analysisStatus': 'ANALYZED',
          'screenReplayRiskScore': 1,
          'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
          'predictedClass': 'REALITY_ROOM',
          'predictedClassConfidence': 0.9933,
          'screenProbability': 0.005,
          'framesAnalyzed': 1,
          'strongScreenFrameCount': 0,
          'mediumScreenFrameCount': 0,
          'averageScreenReplayRiskScore': 1.0,
          'maxFrameScreenReplayRiskScore': 1,
          'signals': {
            'fullFrameRiskScore': 1,
            'contentAreaRiskScore': 1,
          },
        },
      },
      'geometryChallenge': {
        'sceneClass': 'PLANAR',
        'realityEvidence': false,
        'planarEvidence': true,
      },
      'signals': {
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'planarSceneEvidence': true,
        'activeChallengeIndeterminate': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'pairedFlickerTrace': true,
        'displayBandTrace': true,
        'horizontalRefreshBands': true,
        'uncorroboratedDisplayPattern': true,
      },
    };

Map<String, dynamic> _photoPassive() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_IMAGE_ANALYSIS_V1',
      'screenReplayRiskScore': 0,
      'framesAnalyzed': 1,
      'signals': {
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'horizontalRefreshBands': true,
      },
    };

Map<String, dynamic> _photoMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'screenReplayRiskScore': 1,
      'predictedClass': 'REALITY_ROOM',
      'predictedClassConfidence': 0.9854,
      'screenProbability': 0.013,
      'framesAnalyzed': 1,
      'signals': {
        'fullFrameRiskScore': 1,
        'contentAreaRiskScore': 3,
      },
    };

Map<String, dynamic> _videoLive() => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': 45,
      'displayRiskDecision': 'NON_CONCLUSIVE',
      'sceneClass': 'UNKNOWN',
      'globalFlickerScore': 0.1244,
      'localTemporalFlickerScore': 0.1595,
      'refreshBandScore': 0.1603,
      'fineStripeScore': 0.0544,
      'fineGridScore': 0.9434,
      'moireFrequencyScore': 0.6537,
      'persistentPatternScore': 0.0,
      'dynamicChallengeScore': 0.0,
      'videoEquivalentAvailable': false,
      'geometryChallenge': {
        'sceneClass': 'UNKNOWN',
        'realityEvidence': false,
        'planarEvidence': false,
      },
      'signals': {
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'planarSceneEvidence': false,
        'activeChallengeIndeterminate': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'pairedFlickerTrace': true,
        'displayBandTrace': true,
        'horizontalRefreshBands': true,
        'uncorroboratedDisplayPattern': true,
      },
    };

Map<String, dynamic> _videoPassive() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'screenReplayRiskScore': 100,
      'framesAnalyzed': 15,
      'signals': {
        'localRefreshFlicker': true,
        'horizontalRefreshBands': true,
        'pairedLocalRefresh': true,
        'temporalScreenPulse': true,
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'strongDisplayTrace': true,
      },
    };

Map<String, dynamic> _videoMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'screenReplayRiskScore': 7,
      'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
      'predictedClass': 'REALITY_ROOM',
      'predictedClassConfidence': 0.7462,
      'screenProbability': 0.0681,
      'framesAnalyzed': 3,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 5.6667,
      'maxFrameScreenReplayRiskScore': 7,
      'signals': {
        'fullFrameRiskScore': 7,
        'contentAreaRiskScore': 14,
      },
    };

void main() {
  test('build69 photo final wrapper preserves resolved dual-ML REALITY', () {
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
      _photoLive(),
      _photoPassive(),
      _photoMl(),
    ]);
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
    expect(
      result.reasons,
      contains('PHOTO_DUAL_REALITY_ML_AGREEMENT_OVERRIDES_ACTIVE_ONLY_SIGNAL'),
    );
  });

  test(
      'build69 video resolves UNKNOWN geometry with strong multi-frame REALITY',
      () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _videoLive(),
      _videoPassive(),
      _videoMl(),
    ]);
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
    expect(
      result.reasons,
      contains('MULTI_FRAME_REALITY_RESOLVES_UNCORROBORATED_TEMPORAL_SIGNAL'),
    );
  });

  test(
      'temporal-only passive score cannot by itself defeat multi-frame REALITY',
      () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _videoLive(),
      _videoPassive(),
      _videoMl(),
    ]);
    expect(result.strongSources, isNot(contains('STATIC_OPTICAL')));
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });
}
