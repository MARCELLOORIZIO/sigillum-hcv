import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo uses one-tap Temporal V2 and video starts native recording directly', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(camera, isNot(contains('_analyzeLiveScreenProbeWithoutFlash')));
    expect(camera, isNot(contains('_showCaptureReadyMessage')));
    expect(camera, isNot(contains('_hasRequiredParallax')));
    expect(camera, contains('await temporalProbeEngine.capture('));
    expect(camera, contains('await controller!.takePicture();'));
    expect(camera, contains('await activeController.startVideoRecording();'));
    expect(camera, contains('PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT'));
  });
}
