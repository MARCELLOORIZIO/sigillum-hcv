import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('Photo video-equivalent decision method', () {
    test('photo uses embedded video result instead of active-only ambiguity', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbeWithVideoEquivalent(
            decision: 'NO_DISPLAY_EVIDENCE',
            score: 30,
            risk: 'LOW',
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
      expect(result.reasons, contains('PHOTO_VIDEO_EQUIVALENT_METHOD'));
    });

    test('photo preserves the video non-conclusive monitor result', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbeWithVideoEquivalent(
            decision: 'NON_CONCLUSIVE',
            score: 45,
            risk: 'MEDIUM',
            evidenceSources: const ['STATIC_OPTICAL'],
            reasons: const ['STATIC_SCORE_UNCORROBORATED'],
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.evidenceSources, contains('STATIC_OPTICAL'));
      expect(result.reasons, contains('PHOTO_VIDEO_EQUIVALENT_METHOD'));
    });

    test('normal video fusion ignores the embedded photo shortcut', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbeWithVideoEquivalent(
          decision: 'NO_DISPLAY_EVIDENCE',
          score: 30,
          risk: 'LOW',
          activeDisplayEvidence: true,
        ),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        isNot(contains('PHOTO_VIDEO_EQUIVALENT_METHOD')),
      );
    });
  });
}

Map<String, dynamic> _liveProbeWithVideoEquivalent({
  required String decision,
  required int score,
  required String risk,
  bool activeDisplayEvidence = false,
  List<String> evidenceSources = const [],
  List<String> strongSources = const [],
  List<String> reasons = const [],
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'activeProbeVersion': 5,
    'analysisStatus': 'ANALYZED',
    'screenReplayRisk': 'MEDIUM',
    'screenReplayRiskScore': 45,
    'displayRiskDecision': 'NON_CONCLUSIVE',
    'framesAnalyzed': 45,
    'localTemporalFlickerScore': 0.40,
    'refreshBandScore': 0.10,
    'fineStripeScore': 0.40,
    'fineGridScore': 0.70,
    'moireFrequencyScore': 0.34,
    'dynamicChallengeScore': 0.20,
    'persistentPatternScore': 0.50,
    'signals': {
      'activeIlluminationDisplayEvidence': activeDisplayEvidence,
      'reflectedRealityEvidence': false,
      'activeChallengeIndeterminate': false,
    },
    'videoEquivalentAvailable': true,
    'videoEquivalentDisplayRisk': {
      'risk': risk,
      'score': score,
      'decision': decision,
      'analysisStatus': 'COMPLETE',
      'evidenceSources': evidenceSources,
      'strongSources': strongSources,
      'reasons': reasons,
    },
  };
}
