import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe camera flow keeps the original monitor probe', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    expect(camera, contains('await _analyzeLiveScreenProbeWithoutFlash()'));
    expect(camera, contains('await _showCaptureReadyMessage()'));
    expect(camera, isNot(contains('_captureProbeReady')));
    expect(camera, isNot(contains('geometryOverride')));
    expect(camera, isNot(contains('waitForSufficientMovement')));
  });
}
