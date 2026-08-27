import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('current device monitor versus reality profiles', () {
    test('monitor photo mini-video profile resolves as strong display risk', () {
      final live = _liveMonitorPhoto();
      final videoEquivalent = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        live,
        _passiveOptical(score: 20),
        _mlScreen(
          score: 54,
          screenProbability: 0.9944,
          confidence: 0.9943,
          maxFrameScore: 99,
          averageFrameScore: 99.0,
        ),
      ]);

      expect(videoEquivalent.decision, 'STRONG_DISPLAY_RISK');
      expect(videoEquivalent.risk, 'HIGH');
      expect(
        videoEquivalent.reasons,
        contains('ML_SCREEN_AND_LIVE_OPTICAL_PATTERN_CONFIRMED'),
      );
      expect(
        videoEquivalent.reasons,
        contains('ML_STRONG_FRAME_EVIDENCE_SURVIVES_AGGREGATE_DOWNWEIGHT'),
      );

      final photoLive = <String, dynamic>{
        ...live,
        'videoEquivalentAvailable': true,
        'videoEquivalentDisplayRisk': videoEquivalent.toJson(),
      };
      final photoResult = HCVDisplayRiskFusion.combine(
        <Map<String, dynamic>?>[
          photoLive,
          _passiveOptical(score: 0),
          _mlScreen(
            score: 100,
            screenProbability: 0.9993,
            confidence: 0.9992,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(photoResult.decision, 'STRONG_DISPLAY_RISK');
      expect(photoResult.risk, 'HIGH');
      expect(photoResult.score, greaterThanOrEqualTo(85));
      expect(photoResult.reasons, contains('PHOTO_VIDEO_EQUIVALENT_METHOD'));
    });

    test('real photo profile remains no display evidence', () {
      final live = _liveRealityPhoto();
      final videoEquivalent = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        live,
        _passiveOptical(score: 20),
        _mlScreen(
          score: 58,
          screenProbability: 0.5848,
          confidence: 0.4521,
          maxFrameScore: 58,
          averageFrameScore: 58.0,
        ),
      ]);

      expect(videoEquivalent.decision, 'NO_DISPLAY_EVIDENCE');
      expect(videoEquivalent.risk, 'LOW');

      final photoLive = <String, dynamic>{
        ...live,
        'videoEquivalentAvailable': true,
        'videoEquivalentDisplayRisk': videoEquivalent.toJson(),
      };
      final photoResult = HCVDisplayRiskFusion.combine(
        <Map<String, dynamic>?>[
          photoLive,
          _passiveOptical(score: 0),
          _mlReality(score: 13, confidence: 0.7202),
        ],
        liveCaptureOnly: true,
      );

      expect(photoResult.decision, 'NO_DISPLAY_EVIDENCE');
      expect(photoResult.risk, 'LOW');
    });

    test('monitor video profile resolves as strong display risk', () {
      final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        _liveMonitorVideo(),
        _passiveOptical(score: 20),
        _mlScreen(
          score: 99,
          screenProbability: 0.9913,
          confidence: 0.9894,
          maxFrameScore: 99,
          averageFrameScore: 96.5,
        ),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(result.score, greaterThanOrEqualTo(85));
      expect(
        result.reasons,
        contains('ML_SCREEN_AND_LIVE_OPTICAL_PATTERN_CONFIRMED'),
      );
    });

    test('real video temporal false positive remains low', () {
      final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        _liveRealityVideo(),
        _passiveTemporalOnly(score: 85),
        _mlReality(score: 7, confidence: 0.871),
      ]);

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(
        result.reasons,
        contains('SIGNED_GEOMETRIC_REALITY_OVERRIDES_UNCORROBORATED_DISPLAY_SIGNALS'),
      );
    });

    test('single SCREEN ML versus REALITY geometry still stays non-conclusive', () {
      final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        _liveRealityWithoutOpticalDisplayPattern(),
        _mlScreen(
          score: 100,
          screenProbability: 0.999,
          confidence: 0.9973,
        ),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
      expect(result.reasons, contains('ML_GEOMETRY_CONFLICT'));
    });
  });
}

Map<String, dynamic> _liveBase({
  required double localFlicker,
  required double refreshBand,
  required double globalFlicker,
  required double fineStripe,
  required double fineGrid,
  required double moire,
  required bool pairedFlicker,
  required bool horizontalBands,
}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'activeProbeVersion': 5,
    'analysisStatus': 'ANALYZED',
    'framesAnalyzed': 45,
    'screenReplayRisk': 'LOW',
    'screenReplayRiskScore': 20,
    'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
    'sceneClass': 'REALITY',
    'localTemporalFlickerScore': localFlicker,
    'refreshBandScore': refreshBand,
    'globalFlickerScore': globalFlicker,
    'fineStripeScore': fineStripe,
    'fineGridScore': fineGrid,
    'moireFrequencyScore': moire,
    'persistentPatternScore': 0.90,
    'dynamicChallengeScore': 0.0,
    'reason':
        'ACTIVE_V5|MULTI_DEPTH_PARALLAX_DETECTED|NON_PLANAR_CAMERA_MOTION_RESPONSE|GEOMETRIC_REALITY_WITHOUT_DISPLAY_CONFLICT',
    'geometryChallenge': const <String, dynamic>{
      'sceneClass': 'REALITY',
      'realityEvidence': true,
      'planarEvidence': false,
    },
    'signals': <String, dynamic>{
      'geometricRealityEvidence': true,
      'sceneRealityEvidence': true,
      'reflectedRealityEvidence': false,
      'planarSceneEvidence': false,
      'activeIlluminationDisplayEvidence': false,
      'rawActiveDisplayEvidence': false,
      'confirmedDisplayTrace': false,
      'periodicLightTrace': false,
      'pairedFlickerTrace': pairedFlicker,
      'displayBandTrace': false,
      'horizontalRefreshBands': horizontalBands,
      'uncorroboratedDisplayPattern': true,
    },
  };
}

Map<String, dynamic> _liveMonitorPhoto() => _liveBase(
      localFlicker: 0.3851,
      refreshBand: 0.1391,
      globalFlicker: 0.1647,
      fineStripe: 0.2371,
      fineGrid: 0.2371,
      moire: 0.4168,
      pairedFlicker: false,
      horizontalBands: true,
    );

Map<String, dynamic> _liveRealityPhoto() => _liveBase(
      localFlicker: 0.1173,
      refreshBand: 0.0097,
      globalFlicker: 0.0388,
      fineStripe: 0.0067,
      fineGrid: 0.2596,
      moire: 0.0761,
      pairedFlicker: false,
      horizontalBands: false,
    );

Map<String, dynamic> _liveMonitorVideo() => _liveBase(
      localFlicker: 0.5949,
      refreshBand: 0.1602,
      globalFlicker: 0.2786,
      fineStripe: 0.2607,
      fineGrid: 0.2607,
      moire: 0.3946,
      pairedFlicker: true,
      horizontalBands: true,
    );

Map<String, dynamic> _liveRealityVideo() => _liveBase(
      localFlicker: 0.6764,
      refreshBand: 0.1155,
      globalFlicker: 0.3552,
      fineStripe: 0.0203,
      fineGrid: 0.4724,
      moire: 0.4109,
      pairedFlicker: false,
      horizontalBands: false,
    );

Map<String, dynamic> _liveRealityWithoutOpticalDisplayPattern() => _liveBase(
      localFlicker: 0.20,
      refreshBand: 0.08,
      globalFlicker: 0.05,
      fineStripe: 0.10,
      fineGrid: 0.20,
      moire: 0.10,
      pairedFlicker: false,
      horizontalBands: false,
    );

Map<String, dynamic> _passiveOptical({required int score}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'signals': const <String, dynamic>{
      'structuralDisplayTrace': false,
      'confirmedDisplayTrace': false,
      'strongDisplayTrace': false,
    },
  };
}

Map<String, dynamic> _passiveTemporalOnly({required int score}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'signals': const <String, dynamic>{
      'structuralDisplayTrace': false,
      'confirmedDisplayTrace': false,
      'strongDisplayTrace': true,
      'temporalScreenPulse': true,
    },
  };
}

Map<String, dynamic> _mlScreen({
  required int score,
  required double screenProbability,
  required double confidence,
  int? maxFrameScore,
  double? averageFrameScore,
}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'screenProbability': screenProbability,
    'predictedClass': 'SCREEN_MONITOR',
    'predictedClassConfidence': confidence,
    if (maxFrameScore != null) 'maxFrameScreenReplayRiskScore': maxFrameScore,
    if (averageFrameScore != null)
      'averageScreenReplayRiskScore': averageFrameScore,
  };
}

Map<String, dynamic> _mlReality({
  required int score,
  required double confidence,
}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'screenProbability': score / 100.0,
    'predictedClass': 'REALITY_ROOM',
    'predictedClassConfidence': confidence,
  };
}
