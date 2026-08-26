import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'camera preserves the original monitor probe and adds safe confirmation',
    () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      expect(camera, contains('await _analyzeLiveScreenProbeWithoutFlash()'));
      expect(camera, contains('await _showCaptureReadyMessage()'));
      expect(camera, contains('combineVideoDisplayRiskFromCaptureEvidence'));
      expect(camera, isNot(contains('_captureProbeReady')));
      expect(camera, isNot(contains('geometryOverride')));
      expect(camera, isNot(contains('waitForSufficientMovement')));
    },
  );

  test('coordinates are optional visible and signed capture metadata', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final location = File('lib/hcv_capture_location.dart').readAsStringSync();
    final photo = File('lib/hcv_location_image_watermark.dart')
        .readAsStringSync();
    final video = File('lib/hcv_location_video_watermark.dart')
        .readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(camera, contains('_printCoordinates = false'));
    expect(camera, contains('Icons.location_on'));
    expect(camera, contains('captureLocation?.toJson()'));
    expect(camera, contains('locationPrinted'));
    expect(location, contains('Geolocator.requestPermission()'));
    expect(photo, contains('captureLocation.watermarkText'));
    expect(video, contains('captureLocation.watermarkText'));
    expect(info, contains('NSLocationWhenInUseUsageDescription'));
  });
}
