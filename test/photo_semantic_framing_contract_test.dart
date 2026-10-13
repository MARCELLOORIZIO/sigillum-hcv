import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_photo_semantic_framing_contract.dart';

void main() {
  test('without a parity-tested model the verdict stays unknown', () {
    final result = HCVPhotoSemanticFramingContract.diagnosticProbabilities(
      <double>[0.01, 0.02, 0.97], modelParityVerified: false,
    );
    expect(result['sceneFraming'], 'UNKNOWN');
    expect(result['analysisStatus'], 'NOT_ANALYZED');
  });

  test('valid visual probabilities remain diagnostic, never DISPLAY verdict', () {
    final result = HCVPhotoSemanticFramingContract.diagnosticProbabilities(
      <double>[0.01, 0.02, 0.97], modelParityVerified: true,
    );
    expect(result['predictedClass'], 'POSSIBLE_FULL_FRAME_DISPLAY');
    expect(result['decisionRole'], 'DIAGNOSTIC_ONLY');
    expect(result['sceneFraming'], 'UNKNOWN');
    expect(result.containsKey('displayRiskDecision'), false);
  });

  test('invalid model outputs are rejected', () {
    expect(
      HCVPhotoSemanticFramingContract.diagnosticProbabilities(
        <double>[0.5, 0.5], modelParityVerified: true,
      )['analysisStatus'],
      'NOT_ANALYZED',
    );
    expect(
      HCVPhotoSemanticFramingContract.diagnosticProbabilities(
        <double>[0.9, 0.9, 0.9], modelParityVerified: true,
      )['reason'],
      'MODEL_PROBABILITIES_NOT_NORMALIZED',
    );
  });
}
