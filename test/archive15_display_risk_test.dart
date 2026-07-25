import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('Display-risk archive regressions', () {
    test('archive 15 monitor photo remains non-conclusive', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            localFlicker: 0.489,
            refresh: 0.095,
            fineStripe: 0.398,
            fineGrid: 0.653,
            moire: 0.34,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN'));
    });

    test('archive 15 monitor video remains non-conclusive', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            localFlicker: 0.403,
            refresh: 0.111,
            fineStripe: 0.470,
            fineGrid: 0.771,
            moire: 0.34,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN'));
    });

    test('archive 16 monitor video remains non-conclusive', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            frames: 38,
            localFlicker: 0.3976,
            refresh: 0.094,
            fineStripe: 0.3985,
            fineGrid: 1.0,
            moire: 0.521,
            dynamicChallenge: 0.0882,
            persistent: 0.9888,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN'));
    });

    test('archive 16 monitor photo uses persistent display texture', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            frames: 38,
            localFlicker: 0.2806,
            refresh: 0.0889,
            fineStripe: 0.3802,
            fineGrid: 1.0,
            moire: 0.5215,
            dynamicChallenge: 0.069,
            persistent: 0.989,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('LIVE_PERSISTENT_DISPLAY_TEXTURE'));
      expect(result.strongSources, isEmpty);
    });

    test('real photo stays at no display evidence below refresh gate', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            localFlicker: 0.50,
            refresh: 0.069,
            fineStripe: 0.50,
            fineGrid: 0.80,
            moire: 0.45,
            dynamicChallenge: 0.20,
            persistent: 0.75,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
      expect(
        result.reasons,
        isNot(contains('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN')),
      );
      expect(
        result.reasons,
        isNot(contains('LIVE_PERSISTENT_DISPLAY_TEXTURE')),
      );
    });

    test('real video stays at no display evidence below refresh gate', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            localFlicker: 0.50,
            refresh: 0.084,
            fineStripe: 0.50,
            fineGrid: 0.80,
            moire: 0.45,
            dynamicChallenge: 0.20,
            persistent: 0.75,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
      expect(
        result.reasons,
        isNot(contains('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN')),
      );
      expect(
        result.reasons,
        isNot(contains('LIVE_PERSISTENT_DISPLAY_TEXTURE')),
      );
    });

    test('close paper pattern does not pass persistent display texture', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            frames: 38,
            localFlicker: 0.1246,
            refresh: 0.1009,
            fineStripe: 0.2546,
            fineGrid: 0.9863,
            moire: 0.294,
            dynamicChallenge: 0.062,
            persistent: 0.9602,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
      expect(
        result.reasons,
        isNot(contains('LIVE_PERSISTENT_DISPLAY_TEXTURE')),
      );
    });
  });
}

Map<String, dynamic> _liveProbe({
  required double localFlicker,
  required double refresh,
  required double fineStripe,
  required double fineGrid,
  required double moire,
  int frames = 45,
  double dynamicChallenge = 1,
  double persistent = 0,
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': 30,
    'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
    'framesAnalyzed': frames,
    'localTemporalFlickerScore': localFlicker,
    'refreshBandScore': refresh,
    'fineStripeScore': fineStripe,
    'fineGridScore': fineGrid,
    'moireFrequencyScore': moire,
    'dynamicChallengeScore': dynamicChallenge,
    'persistentPatternScore': persistent,
    'signals': const <String, dynamic>{},
  };
}
