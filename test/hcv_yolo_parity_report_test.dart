import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_yolo_parity_report.dart';

void main() {
  test('absent source image never gets synthetic detections', () async {
    final result = await HCVYoloParityReport.generate(
      imagePaths: ['/definitely/not/a/real/HCV-image.jpg'],
      screenModelPath: '/missing/screen.tflite',
      phoneModelPath: '/missing/phone.tflite',
    );
    expect(result['type'], 'SIGILLUM_YOLO_FLUTTER_PARITY');
    expect(result['decisionRole'], 'DIAGNOSTIC_ONLY');
    final images = result['images'] as List;
    expect(images.length, 1);
    final row = images.single as Map;
    expect(row['analysisStatus'], 'NOT_ANALYZED');
    expect(row['imageSha256'], isNull);
    expect((row['models'] as Map).isEmpty, isTrue);
  });
}
