import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo display decision remains pre-capture live only', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(
      camera,
      contains('HCVDisplayRiskFusion.combine(analyses, liveCaptureOnly: true)'),
    );
    expect(camera, contains("'decisionRole': 'POST_CAPTURE_DIAGNOSTIC_ONLY'"));
    expect(camera, contains('combinePhotoDisplayRiskFromPreCaptureEvidence'));
  });
}
