import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_illumination_response_probe.dart';

List<List<double>> phase(double value) =>
    List.generate(8, (_) => List.filled(9, value));

void main() {
  test('strong reversible torch response is marked reflective', () {
    final result = const HCVIlluminationResponseProbe().analyzeNativeCapture({
      'analysisStatus': 'CAPTURED',
      'phaseFrames': [phase(0.20), phase(0.34), phase(0.205)],
      'configuredFrameRate': 60.0,
    });
    expect(result['analysisStatus'], 'ANALYZED');
    expect(result['strongReflectiveResponseCandidate'], true);
    expect(result['reflectiveCellsAt20Percent'], 9);
  });

  test('weak torch response stays inconclusive', () {
    final result = const HCVIlluminationResponseProbe().analyzeNativeCapture({
      'analysisStatus': 'CAPTURED',
      'phaseFrames': [phase(0.40), phase(0.43), phase(0.402)],
    });
    expect(result['strongReflectiveResponseCandidate'], false);
  });
}
