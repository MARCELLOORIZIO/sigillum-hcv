import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

Map<String, dynamic> _ml({bool veto = false}) => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'predictedClass': 'SCREEN_MONITOR',
  'screenProbability': 0.8765,
  'v3RealityVeto': veto,
  'signals': <String, dynamic>{
    'fullFrameRiskScore': 88,
    'contentAreaRiskScore': 77,
    'v3RealityVeto': veto,
  },
};

const _high = <String, dynamic>{
  'decision': 'STRONG_DISPLAY_RISK',
  'risk': 'HIGH',
};

Map<String, dynamic> _optical({bool trace = false, bool texture = false}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'signals': <String, dynamic>{
        'strongDisplayTrace': trace,
        'physicalRepeatingTextureLikely': texture,
        'repetitiveTextureScore': texture ? 0.8 : 0.0,
        'rgbPhaseConsistencyScore': texture ? 0.1 : 1.0,
        'latticeDefectScore': texture ? 0.7 : 0.0,
      },
    };

Map<String, dynamic> _hfr({int reality = 0}) => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'hfrSpatialComparability': 'COMPARABLE',
  'displayRealityEvidenceV3': <String, dynamic>{
    'fullFrameDisplay': false,
    'displayLikeCellCount': 0,
    'realityLikeCellCount': reality,
  },
};

void main() {
  group('PHOTO physically corroborated temporal recovery', () {
    test('strong temporal optical trace can confirm a true screen', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(),
        stillMl: _ml(),
        temporalMl: null,
        temporalOptical: _optical(trace: true),
        videoEquivalentDisplayRisk: _high,
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons,
          contains('PHOTO_TEMPORAL_OPTICAL_STRONG_DISPLAY_TRACE'));
    });

    test('handwriting/texture with semantic temporal HIGH stays non-red', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        stillMl: _ml(),
        temporalMl: null,
        temporalOptical: _optical(),
        videoEquivalentDisplayRisk: _high,
      );
      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    });

    test('comparable HFR reality cells prevent newly recovered red', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(reality: 3),
        stillMl: _ml(),
        temporalMl: null,
        temporalOptical: _optical(trace: true),
        videoEquivalentDisplayRisk: _high,
      );
      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    });

    test('V3 veto prevents temporal optical red recovery', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(),
        stillMl: _ml(veto: true),
        temporalMl: null,
        temporalOptical: _optical(trace: true),
        videoEquivalentDisplayRisk: _high,
      );
      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    });

    test('physical repeating texture guard precedes recovery', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(),
        stillMl: _ml(),
        temporalMl: null,
        stillOptical: _optical(texture: true),
        temporalOptical: _optical(),
        videoEquivalentDisplayRisk: _high,
      );
      expect(result.decision, 'NON_CONCLUSIVE');
    });
  });
}
