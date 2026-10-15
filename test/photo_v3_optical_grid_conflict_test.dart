import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

Map<String, dynamic> _ml({bool veto = true}) => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'predictedClass': 'SCREEN_MONITOR',
  'screenProbability': 0.9437,
  'signals': <String, dynamic>{
    'fullFrameRiskScore': 94,
    'contentAreaRiskScore': 98,
    'v3RealityVeto': veto,
  },
};

Map<String, dynamic> _optics({
  bool grid = true,
  bool physicalTexture = false,
}) => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'signals': <String, dynamic>{
    'uniformPixelGrid': grid,
    'structuralDisplayTrace': grid,
    'physicalRepeatingTextureLikely': physicalTexture,
  },
};

void main() {
  test('A032: independent pixel grid conflicts with V3 veto: yellow, not red', () {
    final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
      temporalFrequencyProbe: null,
      stillMl: _ml(),
      temporalMl: null,
      stillOptical: _optics(),
    );
    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.reasons,
        contains('PHOTO_V3_VETO_CONFLICT_WITH_INDEPENDENT_PIXEL_GRID'));
  });

  test('no confirmed optical pixel grid keeps the existing V3 veto decision', () {
    final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
      temporalFrequencyProbe: null,
      stillMl: _ml(),
      temporalMl: null,
      stillOptical: _optics(grid: false),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons,
        contains('BUILD127_V3_RESIDUAL_VETO_NO_CORROBORATED_DISPLAY_EVIDENCE'));
  });

  test('physical repeating texture does not trigger the new conflict', () {
    final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
      temporalFrequencyProbe: null,
      stillMl: _ml(),
      temporalMl: null,
      stillOptical: _optics(physicalTexture: true),
    );
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    expect(result.reasons,
        isNot(contains('PHOTO_V3_VETO_CONFLICT_WITH_INDEPENDENT_PIXEL_GRID')));
  });

  test('independent full frame HFR keeps red precedence over V3 conflict', () {
    final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
      temporalFrequencyProbe: <String, dynamic>{
        'analysisStatus': 'ANALYZED',
        'hfrSpatialComparability': 'COMPARABLE',
        'displayRealityEvidenceV3': <String, dynamic>{'fullFrameDisplay': true},
      },
      stillMl: _ml(),
      temporalMl: null,
      stillOptical: _optics(),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
  });
}
