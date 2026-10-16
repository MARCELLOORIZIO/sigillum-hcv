import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

Map<String, dynamic> _embedded() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'sceneFraming': 'DISPLAY_IN_REAL_SCENE',
      'positiveEmbeddedRealityEvidence': true,
    };

Map<String, dynamic> _hfr(String comparability) => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': comparability,
      'displayRealityEvidenceV3': <String, dynamic>{'fullFrameDisplay': true},
    };

Map<String, dynamic> _ml() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.98,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 98,
        'contentAreaRiskScore': 91,
      },
    };

void main() {
  group('PHOTO branch arbitration contracts (synthetic evidence)', () {
    test('comparable full-frame HFR survives embedded-geometry conflict', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr('COMPARABLE'),
        stillMl: _ml(),
        temporalMl: null,
        photoFramingEvidence: _embedded(),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
    });

    test('without comparable HFR, embedded geometry prevents ML-only red', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr('NOT_COMPARABLE'),
        stillMl: _ml(),
        temporalMl: null,
        photoFramingEvidence: _embedded(),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.reasons,
          contains('PHOTO_EMBEDDED_REAL_SCENE_CONTRADICTS_FULL_FRAME_DISPLAY'));
    });

    test('no HFR and no corroborated geometry leaves strong ML decisive', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        stillMl: _ml(),
        temporalMl: null,
        photoFramingEvidence: null,
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons, contains('BUILD124_PHOTO_STILL_STRONG_DISPLAY'));
    });
  });
}
