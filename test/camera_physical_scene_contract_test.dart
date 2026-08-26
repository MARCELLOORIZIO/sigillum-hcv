import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera exposes only photo/video and signs physical scene evidence', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, isNot(contains("String captureMode = 'studio'")));
    expect(source, isNot(contains("const Text('STUDIO')")));
    expect(source, isNot(contains("const Text('FIELD')")));
    expect(source, contains('"captureMode": "STANDARD"'));
    expect(source, contains('"physicalSceneClass"'));
    expect(source, contains('"geometryChallenge"'));
    expect(source, contains("_c('physicalProbe')"));
    expect(source, contains('combinePhotoDisplayRiskFromPreCaptureEvidence'));
    expect(source, contains('liveCaptureOnly: true'));
    expect(source, contains('_hasLiveTemporalScreenCorroboration'));
    expect(source, contains("'decisionRole': 'POST_CAPTURE_DIAGNOSTIC_ONLY'"));
  });
}
