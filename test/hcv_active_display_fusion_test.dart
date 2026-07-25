import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('Active display evidence fusion', () {
    test('active emissive evidence produces a cautious display warning', () {
      final result = HCVDisplayRiskFusion.combine(
        [_activeProbe(displayEvidence: true)],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.evidenceSources, contains('ACTIVE_ILLUMINATION'));
      expect(result.reasons, contains('ACTIVE_EMISSIVE_DISPLAY_EVIDENCE'));
    });

    test('reflected reality evidence suppresses passive monitor-like texture', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _activeProbe(
            reflectedReality: true,
            localFlicker: 0.50,
            refresh: 0.16,
            fineStripe: 0.38,
            fineGrid: 0.86,
            moire: 0.46,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
      expect(result.reasons, contains('ACTIVE_REFLECTED_REALITY_EVIDENCE'));
      expect(result.evidenceSources, isNot(contains('LIVE_PREVIEW')));
    });

    test('indeterminate active challenge never becomes no display evidence', () {
      final result = HCVDisplayRiskFusion.combine(
        [_activeProbe(indeterminate: true)],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('ACTIVE_CHALLENGE_INDETERMINATE'));
    });
  });
}

Map<String, dynamic> _activeProbe({
  bool displayEvidence = false,
  bool reflectedReality = false,
  bool indeterminate = false,
  double localFlicker = 0.10,
  double refresh = 0.05,
  double fineStripe = 0.12,
  double fineGrid = 0.25,
  double moire = 0.10,
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'activeProbeVersion': 2,
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore':
        displayEvidence || indeterminate ? 45 : 20,
    'displayRiskDecision':
        displayEvidence || indeterminate ? 'NON_CONCLUSIVE' : 'NO_DISPLAY_EVIDENCE',
    'framesAnalyzed': 45,
    'localTemporalFlickerScore': localFlicker,
    'refreshBandScore': refresh,
    'fineStripeScore': fineStripe,
    'fineGridScore': fineGrid,
    'moireFrequencyScore': moire,
    'dynamicChallengeScore': 0.5,
    'persistentPatternScore': 0.5,
    'signals': {
      'activeIlluminationDisplayEvidence': displayEvidence,
      'reflectedRealityEvidence': reflectedReality,
      'activeChallengeIndeterminate': indeterminate,
    },
  };
}
