import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_photo_framing_evidence.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

Map<String, dynamic> _strongMl() => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'predictedClass': 'SCREEN_MONITOR',
  'screenProbability': 0.98,
  'signals': <String, dynamic>{
    'fullFrameRiskScore': 98,
    'contentAreaRiskScore': 91,
  },
};

void main() {
  group('PHOTO framing with corroborated scene context', () {
    test('positive embedded scene geometry is not full-frame DISPLAY', () {
      final evidence = HCVPhotoFramingEvidence.fromSceneContext(
        <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'contextClass': 'DISPLAY_EMBEDDED_IN_REALITY',
          'positiveRealityEvidence': true,
        },
      );
      expect(evidence['sceneFraming'],
          HCVPhotoFramingEvidence.displayInRealScene);
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        stillMl: _strongMl(),
        temporalMl: null,
        photoFramingEvidence: evidence,
      );
      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.reasons,
          contains('PHOTO_EMBEDDED_REAL_SCENE_CONTRADICTS_FULL_FRAME_DISPLAY'));
    });

    test('same strong ML without corroborated framing retains old verdict', () {
      final evidence = HCVPhotoFramingEvidence.fromSceneContext(null);
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: null,
        stillMl: _strongMl(),
        temporalMl: null,
        photoFramingEvidence: evidence,
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('bare embedded text without positive geometry is UNKNOWN', () {
      final evidence = HCVPhotoFramingEvidence.fromSceneContext(
        <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'contextClass': 'DISPLAY_EMBEDDED_IN_REALITY',
          'positiveRealityEvidence': false,
        },
      );
      expect(evidence['sceneFraming'], HCVPhotoFramingEvidence.unknown);
      expect(HCVPhotoFramingEvidence.isCorroboratedEmbedded(evidence), isFalse);
    });

    test('strong HFR with corroborated real-scene framing is conflict, not red', () {
      final evidence = HCVPhotoFramingEvidence.fromSceneContext(
        <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'contextClass': 'DISPLAY_EMBEDDED_IN_REALITY',
          'positiveRealityEvidence': true,
        },
      );
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'hfrSpatialComparability': 'COMPARABLE',
          'displayRealityEvidenceV3': <String, dynamic>{
            'fullFrameDisplay': true,
          },
        },
        stillMl: _strongMl(),
        temporalMl: null,
        photoFramingEvidence: evidence,
      );
      expect(result.decision, 'NON_CONCLUSIVE');
    });
  });
}
