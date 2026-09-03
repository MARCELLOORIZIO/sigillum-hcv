import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera signs compatibility scene fields without manual parallax capture', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, isNot(contains("String captureMode = 'studio'")));
    expect(source, isNot(contains("const Text('STUDIO')")));
    expect(source, isNot(contains("const Text('FIELD')")));
    expect(source, contains('"captureMode": "STANDARD"'));
    expect(source, contains('"physicalSceneClass"'));
    expect(source, contains('"geometryChallenge"'));
    expect(source, isNot(contains("_c('physicalProbe')")));
    expect(source, isNot(contains('_analyzeLiveScreenProbeWithoutFlash')));
    expect(source, contains('combinePhotoDisplayRiskFromPreCaptureEvidence'));
    expect(source, contains('liveCaptureOnly: true'));
    expect(source, contains('PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT'));
    expect(source, contains("'decisionRole': 'POST_CAPTURE_DIAGNOSTIC_ONLY'"));
  });
}
