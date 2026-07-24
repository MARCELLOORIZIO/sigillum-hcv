import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('Unified display signature matrix', () {
    const monitorCases = <String, List<double>>{
      'archive 13 photo': [0.6672, 0.1600, 0.4396, 0.8782, 0.5103],
      'archive 13 video': [0.4922, 0.1962, 0.3769, 0.8002, 0.4169],
      'archive 15 photo': [0.4890, 0.0950, 0.3980, 0.6530, 0.3400],
      'archive 15 video': [0.4030, 0.1110, 0.4700, 0.7710, 0.3400],
      'archive 16 photo': [0.2806, 0.0889, 0.3802, 1.0000, 0.5215],
      'archive 16 video': [0.3976, 0.0940, 0.3985, 1.0000, 0.5210],
      'archive 17 photo': [0.2829, 0.1112, 0.1987, 0.7340, 0.2084],
      'archive 17 video': [0.2277, 0.0995, 0.2146, 0.7648, 0.2360],
      'archive 18 photo': [0.7659, 0.1328, 0.3733, 0.8622, 0.4752],
      'archive 18 video': [0.6757, 0.1026, 0.2964, 0.8173, 0.3637],
    };

    for (final entry in monitorCases.entries) {
      test('${entry.key} remains non-conclusive', () {
        final result = HCVDisplayRiskFusion.combine(
          [_probe(entry.value)],
          liveCaptureOnly: true,
        );

        expect(result.decision, 'NON_CONCLUSIVE');
        expect(result.score, 45);
        expect(result.reasons, contains('LIVE_UNIFIED_DISPLAY_SIGNATURE'));
        expect(result.strongSources, isEmpty);
      });
    }

    const physicalCases = <String, List<double>>{
      'real photo': [0.5000, 0.0690, 0.5000, 0.8000, 0.4500],
      'real video': [0.5000, 0.0840, 0.5000, 0.8000, 0.4500],
      'paper pattern': [0.1246, 0.1009, 0.2546, 0.9863, 0.2940],
      'desk': [0.2688, 0.0512, 0.1805, 0.7872, 0.3345],
      'archive 13 selfie photo': [0.1871, 0.1459, 0.5100, 0.8783, 0.4704],
      'archive 13 selfie video': [0.1936, 0.1460, 0.5079, 0.8716, 0.4676],
      'archive 11 selfie': [0.4364, 0.0640, 0.2334, 0.5254, 0.3464],
      'strong flicker without structure': [0.6800, 0.1030, 0.2000, 0.5200, 0.2000],
    };

    for (final entry in physicalCases.entries) {
      test('${entry.key} remains no display evidence', () {
        final result = HCVDisplayRiskFusion.combine(
          [_probe(entry.value)],
          liveCaptureOnly: true,
        );

        expect(result.decision, 'NO_DISPLAY_EVIDENCE');
        expect(result.score, 20);
        expect(
          result.reasons,
          isNot(contains('LIVE_UNIFIED_DISPLAY_SIGNATURE')),
        );
      });
    }
  });
}

Map<String, dynamic> _probe(List<double> values) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': 20,
    'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
    'framesAnalyzed': 45,
    'localTemporalFlickerScore': values[0],
    'refreshBandScore': values[1],
    'fineStripeScore': values[2],
    'fineGridScore': values[3],
    'moireFrequencyScore': values[4],
    'dynamicChallengeScore': 0.5,
    'persistentPatternScore': 0.5,
    'signals': const <String, dynamic>{},
  };
}
