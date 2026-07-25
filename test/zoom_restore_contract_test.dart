import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo capture waits for zoom restoration after the live probe', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final probe = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();

    expect(camera, contains('_settleCameraAfterLiveProbe'));
    expect(camera, contains('await _settleCameraAfterLiveProbe();'));
    expect(camera, contains('Duration(milliseconds: 300)'));
    expect(probe, contains('await controller.setZoomLevel(restoreZoomLevel)'));
    expect(probe, contains('Duration(milliseconds: 500)'));
  });
}
