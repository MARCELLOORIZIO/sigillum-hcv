import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_photo_object_framing_policy.dart';

/// Field evidence observed from the 14 October 2026 owner-approved audit.
/// These tests protect against claiming to have solved object detection solely
/// by changing a threshold or trusting PHOTO's semantic class. They do not
/// imply that a static certificate replays live HFR/optics.
Map<String, dynamic> photo(String predicted) => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'decisionRole': 'DIAGNOSTIC_ONLY',
  'predictedClass': predicted,
};

Map<String, dynamic> embedded() => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'sceneFraming': 'DISPLAY_IN_REAL_SCENE',
  'positiveEmbeddedRealityEvidence': true,
};

Map<String, dynamic> risk(String decision) => <String, dynamic>{
  'decision': decision,
};

void main() {
  test('A3AA physical laptop: semantic full-frame cannot prove recapture', () {
    // Human visual ground truth: keyboard and bezel visible; original final HIGH.
    // This case will NOT be resolved without an independent object geometry
    // detector; the semantic PHOTO model classified it as full-frame.
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: photo('POSSIBLE_FULL_FRAME_DISPLAY'),
      photoFramingEvidence: null,
      legacyDisplayRisk: risk('STRONG_DISPLAY_RISK'),
    );
    expect(result['decisionRole'], 'DIAGNOSTIC_ONLY');
    expect(result['physicalRecaptureProven'], isFalse);
    expect(result['legacyDisplayRiskDecisionUnchanged'], 'STRONG_DISPLAY_RISK');
  });

  test('F3EE monitor crop: embedded-depth conflict cannot prove real object', () {
    // Human visual ground truth: device edges absent; previous NON_CONCLUSIVE.
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: photo('POSSIBLE_FULL_FRAME_DISPLAY'),
      photoFramingEvidence: embedded(),
      legacyDisplayRisk: risk('NON_CONCLUSIVE'),
    );
    expect(result['framing'], HCVPhotoObjectFramingPolicy.unresolved);
    expect(result['screenObjectVisible'], isNot(true));
    expect(result['physicalRecaptureProven'], isFalse);
  });

  test('7056 monitors on desk: visible screen does not mean recapture', () {
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: photo('DISPLAY_IN_REAL_SCENE'),
      photoFramingEvidence: null,
      legacyDisplayRisk: risk('NO_DISPLAY_EVIDENCE'),
    );
    expect(result['framing'], HCVPhotoObjectFramingPolicy.unresolved);
    expect(result['physicalRecaptureProven'], isFalse);
  });
}
