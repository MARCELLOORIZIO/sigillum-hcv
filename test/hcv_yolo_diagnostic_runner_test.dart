import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_yolo_diagnostic_runner.dart';

void main() {
  test('missing model always returns NOT_ANALYZED and no verdict', () async {
    final result = await HCVYoloDiagnosticRunner.inspectImage(
      modelFilePath: '/nonexistent/sigillum-screen-model.tflite',
      imageFilePath: '/nonexistent/image.jpg',
      useScreenDetection: true,
    );
    expect(result['analysisStatus'], 'NOT_ANALYZED');
    expect(result['reason'], 'MODEL_NOT_FOUND');
    expect(result['devicePresent'], isNull);
    expect(result['displayRiskDecision'], isNull);
    expect(result['physicalRecaptureProven'], isFalse);
  });

  test('phone model is also fail-closed when not available', () async {
    final result = await HCVYoloDiagnosticRunner.inspectImage(
      modelFilePath: '/nonexistent/phone-device-v4.tflite',
      imageFilePath: '/nonexistent/image.jpg',
      useScreenDetection: false,
    );
    expect(result['analysisStatus'], 'NOT_ANALYZED');
    expect(result['devicePresent'], isNull);
    expect(result['displayRiskDecision'], isNull);
  });
}
