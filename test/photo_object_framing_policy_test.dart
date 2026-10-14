import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_photo_object_framing_policy.dart';

Map<String, dynamic> semantic(String cls) => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'decisionRole': 'DIAGNOSTIC_ONLY',
  'predictedClass': cls,
};
Map<String, dynamic> embedded() => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'sceneFraming': 'DISPLAY_IN_REAL_SCENE',
  'positiveEmbeddedRealityEvidence': true,
};
Map<String, dynamic> legacy(String decision) => <String, dynamic>{'decision': decision};

void main() {
  test('corroborated physical monitor remains an object, not a recapture', () {
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: semantic('DISPLAY_IN_REAL_SCENE'),
      photoFramingEvidence: embedded(),
      legacyDisplayRisk: legacy('NO_DISPLAY_EVIDENCE'),
    );
    expect(result['framing'], HCVPhotoObjectFramingPolicy.objectInScene);
    expect(result['physicalRecaptureProven'], false);
    expect(result['legacyDisplayRiskDecisionUnchanged'], 'NO_DISPLAY_EVIDENCE');
  });
  test('full-frame semantic display is not proof of screen recapture', () {
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: semantic('POSSIBLE_FULL_FRAME_DISPLAY'),
      photoFramingEvidence: null,
      legacyDisplayRisk: legacy('NO_DISPLAY_EVIDENCE'),
    );
    expect(result['framing'], HCVPhotoObjectFramingPolicy.possibleFullFrame);
    expect(result['physicalRecaptureProven'], false);
    expect(result['decisionRole'], 'DIAGNOSTIC_ONLY');
  });
  test('blue texture conflicting with embedded geometry stays undetermined', () {
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: semantic('POSSIBLE_FULL_FRAME_DISPLAY'),
      photoFramingEvidence: embedded(),
      legacyDisplayRisk: legacy('NON_CONCLUSIVE'),
    );
    expect(result['framing'], HCVPhotoObjectFramingPolicy.unresolved);
    expect(result['reason'], 'EMBEDDED_GEOMETRY_CONFLICTS_WITH_SEMANTIC_FULL_FRAME');
  });
  test('strong physical display and embedded scene conflict, never green', () {
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: semantic('DISPLAY_IN_REAL_SCENE'),
      photoFramingEvidence: embedded(),
      legacyDisplayRisk: legacy('STRONG_DISPLAY_RISK'),
    );
    expect(result['framing'], HCVPhotoObjectFramingPolicy.unresolved);
  });
  test('without independent geometry, a visible display class is ambiguous', () {
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: semantic('DISPLAY_IN_REAL_SCENE'),
      photoFramingEvidence: null,
      legacyDisplayRisk: legacy('NO_DISPLAY_EVIDENCE'),
    );
    expect(result['framing'], HCVPhotoObjectFramingPolicy.unresolved);
  });
  test('physical balcony scene is not a recapture', () {
    final result = HCVPhotoObjectFramingPolicy.evaluate(
      semanticPhoto: semantic('PHYSICAL_SURFACE_OR_SCENE'),
      photoFramingEvidence: null,
      legacyDisplayRisk: legacy('NO_DISPLAY_EVIDENCE'),
    );
    expect(result['framing'], HCVPhotoObjectFramingPolicy.physicalScene);
  });
}
