import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('reality versus temporal-only display evidence', () {
    test('real photo profile C2AC resolves as no display evidence', () {
      final analyses = <Map<String, dynamic>?>[
        _liveRealityTemporal(score: 75),
        _passiveTemporalOnly(score: 69),
        _mlReality(score: 15, confidence: 0.8025),
      ];

      final result = HCVDisplayRiskFusion.combine(analyses);
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(
        result.reasons,
        contains(
          'INDEPENDENT_REALITY_AGREEMENT_OVERRIDES_TEMPORAL_ONLY_SIGNAL',
        ),
      );

      // Photo policy may ignore positive post-capture display claims, but the
      // same low-screen ML result is allowed to corroborate REALITY geometry.
      final photoPreCapture = HCVDisplayRiskFusion.combine(
        analyses,
        liveCaptureOnly: true,
      );
      expect(photoPreCapture.decision, 'NO_DISPLAY_EVIDENCE');
      expect(photoPreCapture.risk, 'LOW');
    });

    test('real video profile with moderate REALITY ML also resolves low', () {
      final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        _liveRealityTemporal(score: 72),
        _passiveTemporalOnly(score: 69),
        _mlReality(score: 25, confidence: 0.6632),
      ]);

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
    });

    test('static structural display evidence blocks the reality override', () {
      final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        _liveRealityTemporal(score: 45, confirmedTemporal: false),
        _passiveStructural(score: 70),
        _mlReality(score: 15, confidence: 0.90),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
    });

    test('active emissive evidence blocks the reality override', () {
      final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        _liveRealityTemporal(
          score: 45,
          confirmedTemporal: false,
          activeDisplay: true,
        ),
        _mlReality(score: 15, confidence: 0.90),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('ACTIVE_DISPLAY_GEOMETRY_CONFLICT'),
      );
    });

    test('SCREEN ML plus REALITY geometry remains a conflict', () {
      final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
        _liveRealityTemporal(score: 20, confirmedTemporal: false),
        _mlScreen(score: 100, confidence: 0.9973),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
      expect(result.reasons, contains('ML_GEOMETRY_CONFLICT'));
    });
  });
}

Map<String, dynamic> _liveRealityTemporal({
  required int score,
  bool confirmedTemporal = true,
  bool activeDisplay = false,
}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'framesAnalyzed': 45,
    'screenReplayRiskScore': score,
    'displayRiskDecision': confirmedTemporal
        ? 'STRONG_DISPLAY_RISK'
        : score >= 45
            ? 'NON_CONCLUSIVE'
            : 'NO_DISPLAY_EVIDENCE',
    'localTemporalFlickerScore': confirmedTemporal ? 0.48 : 0.20,
    'refreshBandScore': confirmedTemporal ? 0.18 : 0.08,
    'fineStripeScore': 0.40,
    'fineGridScore': 0.82,
    'moireFrequencyScore': 0.41,
    'persistentPatternScore': 0.70,
    'dynamicChallengeScore': 0.30,
    'geometryChallenge': const <String, dynamic>{'sceneClass': 'REALITY'},
    'signals': <String, dynamic>{
      'geometricRealityEvidence': true,
      'sceneRealityEvidence': true,
      'reflectedRealityEvidence': false,
      'planarSceneEvidence': false,
      'activeIlluminationDisplayEvidence': activeDisplay,
      'rawActiveDisplayEvidence': activeDisplay,
      'confirmedDisplayTrace': confirmedTemporal,
      'periodicLightTrace': confirmedTemporal,
      'pairedFlickerTrace': confirmedTemporal,
      'horizontalRefreshBands': confirmedTemporal,
    },
  };
}

Map<String, dynamic> _passiveTemporalOnly({required int score}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
    'screenReplayRiskScore': score,
    'signals': const <String, dynamic>{
      'strongDisplayTrace': true,
      'structuralDisplayTrace': false,
      'confirmedDisplayTrace': false,
    },
  };
}

Map<String, dynamic> _passiveStructural({required int score}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
    'screenReplayRiskScore': score,
    'signals': const <String, dynamic>{
      'strongDisplayTrace': true,
      'structuralDisplayTrace': true,
      'confirmedDisplayTrace': false,
    },
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
    'predictedClass': 'REALITY_OUTDOOR',
    'predictedClassConfidence': confidence,
  };
}

Map<String, dynamic> _mlScreen({
  required int score,
  required double confidence,
}) {
  return <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'predictedClass': 'SCREEN_MONITOR',
    'predictedClassConfidence': confidence,
  };
}
