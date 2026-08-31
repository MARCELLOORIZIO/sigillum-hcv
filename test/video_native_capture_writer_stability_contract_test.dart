import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native video capture skips disposable temporal mini-video', () {
    final core = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(core, contains('bool includeTemporalVideoProbe = true'));
    expect(core, contains('SKIPPED_FOR_NATIVE_VIDEO_CAPTURE'));
    expect(
      core,
      contains('NATIVE_VIDEO_CAPTURE_USES_POST_CAPTURE_TEMPORAL_ANALYSIS'),
    );
    expect(camera, contains('includeTemporalVideoProbe: false'));
    expect(camera, contains('await _settleCameraAfterLiveProbe();'));
  });

  test('photo path keeps temporal video probe enabled by default', () {
    final core = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    expect(
      core,
      contains('? await const HCVTemporalCaptureProbe().analyze(controller)'),
    );
    expect(
      core,
      contains('VIDEO_EQUIVALENT_PRE_CAPTURE_TEMPORAL_ANALYSIS'),
    );
  });

  test('video stop failure clears recording UI state', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    expect(camera, contains('pendingVideoCapturedAt = null;'));
    expect(camera, contains('recording = false;'));
  });
}
