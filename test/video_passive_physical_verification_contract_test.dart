import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'video active probe precedes REC and passive verification covers final video',
      () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final temporal =
        File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();
    final microtexture =
        File('lib/hcv_display_microtexture_probe.dart').readAsStringSync();

    final activeProbeIndex = camera.indexOf('captureActiveVideoPhysicalProbe');
    final realRecIndex = camera.indexOf(
      'await controller!.startVideoRecording();',
      activeProbeIndex,
    );
    expect(activeProbeIndex, greaterThanOrEqualTo(0));
    expect(realRecIndex, greaterThan(activeProbeIndex));

    expect(
      camera,
      contains('analyzePassiveRecordedVideoPhysical(savedVideoPath)'),
    );
    expect(camera, contains('"passivePhysicalVideoVerification"'));
    expect(
      temporal,
      contains('analyzePassiveRecordedVideoPhysical'),
    );
    expect(
      microtexture,
      contains("scanMode': 'WHOLE_RECORDING_DISTRIBUTED_NATIVE_3X3'"),
    );
    expect(microtexture, contains('FFprobeKit.getMediaInformation(videoPath)'));
    expect(
      microtexture,
      contains("'shutterChangedDuringRecordedVideo': false"),
    );
    expect(
      microtexture,
      contains("'zoomChangedDuringRecordedVideo': false"),
    );

    final passiveStart = microtexture.indexOf(
      'Future<Map<String, dynamic>> analyzeRecordedVideoPassive',
    );
    final passiveEnd = microtexture.indexOf(
      'Future<bool> discardCapture',
      passiveStart,
    );
    expect(passiveStart, greaterThanOrEqualTo(0));
    expect(passiveEnd, greaterThan(passiveStart));
    final passiveMethod = microtexture.substring(passiveStart, passiveEnd);
    expect(passiveMethod, isNot(contains('applyShortExposure')));
    expect(passiveMethod, isNot(contains('setZoomLevel')));
  });
}
