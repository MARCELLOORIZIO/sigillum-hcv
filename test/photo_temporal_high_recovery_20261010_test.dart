import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

Map<String, dynamic> still({
  double probability = 0.8765,
  bool veto = false,
  bool screen = true,
}) => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': screen ? 'SCREEN_MONITOR' : 'REALITY_ROOM',
      'screenProbability': probability,
      'v3RealityVeto': veto,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 88,
        'contentAreaRiskScore': 77,
        'v3RealityVeto': veto,
      },
    };

Map<String, dynamic> equivalent({bool high = true}) =>
    <String, dynamic>{
      'decision': high ? 'STRONG_DISPLAY_RISK' : 'NO_DISPLAY_EVIDENCE',
      'risk': high ? 'HIGH' : 'LOW',
      'score': high ? 95 : 20,
    };

void main() {
  group('PHOTO temporal HIGH recovery without legacy regression', () {
    test('new 0.8765 SCREEN_MONITOR with temporal HIGH is red', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        stillMl: still(),
        temporalMl: null,
        videoEquivalentDisplayRisk: equivalent(),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.score, greaterThanOrEqualTo(90));
      expect(result.reasons,
          contains('PHOTO_STILL_SCREEN_PROBABILITY_AT_LEAST_0_80'));
    });

    test('BMW/172A V3 reality veto is never bypassed by temporal HIGH', () {
      for (final probability in <double>[0.9396, 0.9996]) {
        final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
          temporalFrequencyProbe: null,
          stillMl: still(probability: probability, veto: true),
          temporalMl: null,
          videoEquivalentDisplayRisk: equivalent(),
        );
        expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
      }
    });

    test('temporal LOW cannot trigger new red recovery', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        stillMl: still(),
        temporalMl: null,
        videoEquivalentDisplayRisk: equivalent(high: false),
      );
      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    });

    test('REALITY classifier cannot trigger new red recovery', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        stillMl: still(screen: false),
        temporalMl: null,
        videoEquivalentDisplayRisk: equivalent(),
      );
      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    });

    test('only the explicitly documented temporal HIGH code is eligible', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        stillMl: still(),
        temporalMl: null,
        videoEquivalentDisplayRisk: <String, dynamic>{
          'decision': 'STRONG_DISPLAY_RISK',
          'risk': 'MEDIUM',
        },
      );
      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    });
  });
}
