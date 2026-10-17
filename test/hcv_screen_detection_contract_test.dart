import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_screen_detection_contract.dart';

void main() {
  test('Screen Detection expected 608 NCHW float32 layout', () {
    expect(HCVScreenDetectionContract.supportsTensorLayout(
      actualInputShape: [1, 3, 608, 608],
      actualOutputShape: [1, 9, 7581],
      inputType: 'float32',
      outputType: 'float32',
    ), isTrue);
    expect(HCVScreenDetectionContract.supportsTensorLayout(
      actualInputShape: [1, 608, 608, 3],
      actualOutputShape: [1, 9, 7581],
      inputType: 'float32',
      outputType: 'float32',
    ), isFalse);
    expect(HCVScreenDetectionContract.supportsTensorLayout(
      actualInputShape: [1, 3, 608, 608],
      actualOutputShape: [1, 5, 3549],
      inputType: 'float32',
      outputType: 'float32',
    ), isFalse);
    expect(HCVScreenDetectionContract.supportsTensorLayout(
      actualInputShape: [1, 3, 608, 608],
      actualOutputShape: [1, 9, 7581],
      inputType: 'uint8',
      outputType: 'float32',
    ), isFalse);
  });

  test('five classes and known model digest remain separate from V4', () {
    expect(HCVScreenDetectionContract.classNames,
      ['desktop', 'laptop', 'phone', 'tablet', 'tv']);
    expect(HCVScreenDetectionContract.expectedSha256.length, 64);
  });

  test('model absence cannot imply safe scene or detected device', () {
    final absent = HCVScreenDetectionContract.report(
      modelAvailable: false,
      tensorLayoutVerified: false,
    );
    expect(absent['analysisStatus'], 'NOT_ANALYZED');
    expect(absent['devicePresent'], isNull);
    expect(absent['displayRiskDecision'], isNull);
    expect(absent['physicalRecaptureProven'], false);

    final checked = HCVScreenDetectionContract.report(
      modelAvailable: true,
      tensorLayoutVerified: true,
    );
    expect(checked['analysisStatus'], 'CONTRACT_VERIFIED');
    expect(checked['devicePresent'], isNull);
    expect(checked['displayRiskDecision'], isNull);
  });
}
