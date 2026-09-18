import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD118 keeps photo high resolution and video medium resolution', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(
      source,
      contains(
        'return isPhotoMode ? ResolutionPreset.high : ResolutionPreset.medium;',
      ),
    );
    expect(
      source,
      contains('_resolutionPresetForMode(photoMode)'),
    );
    expect(
      source,
      contains('_resolutionPresetForMode(nextPhotoMode)'),
    );
  });

  test('BUILD118 photo preview shows the complete frame instead of cover crop', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains('if (ok && photoMode)'));
    expect(source, contains('fit: BoxFit.contain'));
    expect(source, contains('if (ok && !photoMode)'));
    expect(source, contains('fit: BoxFit.cover'));
  });

  test('BUILD118 mode switch reinitializes the controller before composition', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains('Future<void> _setCaptureMode(bool nextPhotoMode)'));
    expect(source, contains('await _setCaptureMode(false);'));
    expect(source, contains('await _setCaptureMode(true);'));
    expect(source, contains('CAMERA_MODE_REINITIALIZATION_FAILED'));
  });

  test('BUILD118 does not alter the accepted 1.5 second three-frame photo temporal cycle', () {
    final source =
        File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

    expect(
      source,
      contains(
        'static const Duration defaultDuration = Duration(milliseconds: 1500)',
      ),
    );
    expect(source, contains('static const int photoMlFrameLimit = 3'));
  });
}
