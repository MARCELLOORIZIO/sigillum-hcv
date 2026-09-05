import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('illumination response is captured before photo and video final capture',
      () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('HCVIlluminationResponseProbe().capture'));
    expect(source, contains('pendingIlluminationResponseProbe'));
    expect(
      RegExp(r'"illuminationResponseProbe": illuminationResponseProbe')
          .allMatches(source)
          .length,
      2,
    );
    expect(
      source,
      contains('temporalFrequencyProbe: temporalFrequencyProbe'),
    );
  });

  test('illumination probe locks exposure and restores camera state', () {
    final source =
        File('lib/hcv_illumination_response_probe.dart').readAsStringSync();
    expect(source, contains('setExposureMode(ExposureMode.locked)'));
    expect(source, contains('setFlashMode(FlashMode.off)'));
    expect(source, contains('setFlashMode(FlashMode.torch)'));
    expect(source, contains('setExposureMode(ExposureMode.auto)'));
    expect(source, contains('setFocusMode(FocusMode.auto)'));
    expect(source,
        contains("'strongReflectiveResponse': strongReflectiveResponse"));
  });
}
