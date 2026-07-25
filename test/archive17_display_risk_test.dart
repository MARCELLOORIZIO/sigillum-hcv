import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('Archive 17 display risk', () {
    test('monitor video remains a cautious warning', () {
      final result = HCVDisplayRiskFusion.combine([
        _live(
          localFlicker: 0.2277,
          refresh: 0.0995,
          fineStripe: 0.2146,
          fineGrid: 0.7648,
          moire: 0.2360,
          dynamicChallenge: 0.1695,
          persistent: 0.7144,
          dynamicTrace: true,
        ),
      ], liveCaptureOnly: true);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('LIVE_LOW_EMISSION_TEXTURE_PATTERN'));
      expect(result.strongSources, isEmpty);
    });

    test('monitor photo remains a cautious warning', () {
      final result = HCVDisplayRiskFusion.combine([
        _live(
          localFlicker: 0.2829,
          refresh: 0.1112,
          fineStripe: 0.1987,
          fineGrid: 0.7340,
          moire: 0.2084,
          dynamicChallenge: 0.2176,
          persistent: 0.7006,
        ),
      ], liveCaptureOnly: true);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('LIVE_LOW_EMISSION_TEXTURE_PATTERN'));
      expect(result.strongSources, isEmpty);
    });

    test('known desk negative is not promoted', () {
      final result = HCVDisplayRiskFusion.combine([
        _live(
          localFlicker: 0.2688,
          refresh: 0.0512,
          fineStripe: 0.1805,
          fineGrid: 0.7872,
          moire: 0.3345,
          dynamicChallenge: 0.3373,
          persistent: 0.5479,
        ),
      ], liveCaptureOnly: true);

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
    });

    test('known paper-pattern negative is not promoted', () {
      final result = HCVDisplayRiskFusion.combine([
        _live(
          localFlicker: 0.1246,
          refresh: 0.1009,
          fineStripe: 0.2546,
          fineGrid: 0.9863,
          moire: 0.2940,
          dynamicChallenge: 0.0620,
          persistent: 0.9602,
        ),
      ], liveCaptureOnly: true);

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
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
  bool dynamicTrace = false,
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
    'signals': {
      'uncorroboratedDisplayPattern': true,
      'dynamicScreenChallengeTrace': dynamicTrace,
    },
  };
}
