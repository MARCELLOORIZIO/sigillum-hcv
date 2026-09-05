import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native video capture starts directly without disposable pre-probe', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(camera, isNot(contains('includeTemporalVideoProbe: false')));
    expect(camera, isNot(contains('_analyzeLiveScreenProbeWithoutFlash')));
    expect(camera, isNot(contains('_showCaptureReadyMessage')));
    expect(camera, contains('await _settleCameraAfterLiveProbe();'));
    expect(camera, contains('await activeController.startVideoRecording();'));
  });

  test('photo path captures temporal clip before still and analyzes it after', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final temporal = File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

    final miniVideo = camera.indexOf('await temporalProbeEngine.capture(');
    final still = camera.indexOf('await controller!.takePicture();', miniVideo);
    final analysis = camera.indexOf(
      'temporalProbeEngine.analyzeCapturedClip(',
      still,
    );

    expect(miniVideo, greaterThanOrEqualTo(0));
    expect(still, greaterThan(miniVideo));
    expect(analysis, greaterThan(still));
    expect(temporal, contains('Duration(milliseconds: 2400)'));
    expect(
      temporal,
      contains('static const double photoMlFrameIntervalSeconds = 0.6'),
    );
    expect(temporal, contains('static const int photoMlFrameLimit = 4'));
    expect(
      temporal,
      contains('frameSamplingIntervalSeconds: photoMlFrameIntervalSeconds'),
    );
    expect(temporal, contains('maxFrames: photoMlFrameLimit'));
  });

  test('video stop failure clears recording UI state', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final stop = camera.indexOf('Future<void> stop() async');
    final nextMethod = camera.indexOf(
      'Map<String, dynamic> _photoTemporalV2Unavailable',
      stop,
    );
    final stopSource = camera.substring(stop, nextMethod);

    expect(stopSource, contains('pendingVideoCapturedAt = null;'));
    expect(
      stopSource,
      contains('_setCaptureLifecycle(HCVCaptureLifecycle.idle);'),
    );
    expect(camera, isNot(contains('_videoFinalizeInProgress')));
  });
}
