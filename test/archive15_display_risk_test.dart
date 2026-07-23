import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('Archive 15 display-risk regression', () {
    test('monitor photo remains non-conclusive', () {
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

    test('monitor video remains non-conclusive', () {
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

    test('real photo stays at no display evidence below refresh gate', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            localFlicker: 0.50,
            refresh: 0.069,
            fineStripe: 0.50,
            fineGrid: 0.80,
            moire: 0.45,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
      expect(result.reasons,
          isNot(contains('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN')));
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
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
      expect(result.reasons,
          isNot(contains('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN')));
    });
  });
}

Map<String, dynamic> _liveProbe({
  required double localFlicker,
  required double refresh,
  required double fineStripe,
  required double fineGrid,
  required double moire,
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': 30,
    'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
    'framesAnalyzed': 45,
    'localTemporalFlickerScore': localFlicker,
    'refreshBandScore': refresh,
    'fineStripeScore': fineStripe,
    'fineGridScore': fineGrid,
    'moireFrequencyScore': moire,
    'signals': const <String, dynamic>{},
  };
}
