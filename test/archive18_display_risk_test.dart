import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('Archive 18 display risk', () {
    test('monitor video is retained as non-conclusive', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _live(
            localFlicker: 0.6757,
            refresh: 0.1026,
            fineStripe: 0.2964,
            fineGrid: 0.8173,
            moire: 0.3637,
            dynamicChallenge: 0.5672,
            persistent: 0.4376,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('LIVE_HIGH_TEMPORAL_GRID_PATTERN'));
      expect(result.strongSources, isEmpty);
    });

    test('monitor photo remains non-conclusive through existing evidence', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _live(
            localFlicker: 0.7659,
            refresh: 0.1328,
            fineStripe: 0.3733,
            fineGrid: 0.8622,
            moire: 0.4752,
            dynamicChallenge: 0.5816,
            persistent: 0.5433,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.strongSources, isEmpty);
    });

    test('strong local flicker alone is not enough', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _live(
            localFlicker: 0.68,
            refresh: 0.103,
            fineStripe: 0.20,
            fineGrid: 0.52,
            moire: 0.20,
            dynamicChallenge: 0.56,
            persistent: 0.44,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
      expect(
        result.reasons,
        isNot(contains('LIVE_HIGH_TEMPORAL_GRID_PATTERN')),
      );
    });
  });
}

Map<String, dynamic> _live({
  required double localFlicker,
  required double refresh,
  required double fineStripe,
  required double fineGrid,
  required double moire,
  required double dynamicChallenge,
  required double persistent,
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': 20,
    'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
    'framesAnalyzed': 45,
    'localTemporalFlickerScore': localFlicker,
    'refreshBandScore': refresh,
    'fineStripeScore': fineStripe,
    'fineGridScore': fineGrid,
    'moireFrequencyScore': moire,
    'dynamicChallengeScore': dynamicChallenge,
    'persistentPatternScore': persistent,
    'signals': const {
      'uncorroboratedDisplayPattern': true,
    },
  };
}
