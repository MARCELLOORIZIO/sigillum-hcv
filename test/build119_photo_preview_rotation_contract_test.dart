import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD119 photo preview follows device orientation without crop', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains('OrientationBuilder('));
    expect(
      source,
      contains('final isPortrait = orientation == Orientation.portrait;'),
    );
    expect(
      source,
      contains(
        'isPortrait ? previewSize.height : previewSize.width',
      ),
    );
    expect(
      source,
      contains(
        'isPortrait ? previewSize.width : previewSize.height',
      ),
    );
    expect(source, contains('fit: BoxFit.contain'));
  });

  test('BUILD119 keeps video preview behavior unchanged', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains('if (ok && !photoMode)'));
    expect(source, contains('OverflowBox('));
    expect(source, contains('fit: BoxFit.cover'));
  });

  test('BUILD119 keeps BUILD118 photo resolution and temporal cycle', () {
    final cameraSource = File('lib/camera_page.dart').readAsStringSync();
    final temporalSource =
        File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

    expect(
      cameraSource,
      contains(
        'return isPhotoMode ? ResolutionPreset.high : ResolutionPreset.medium;',
      ),
    );
    expect(
      temporalSource,
      contains(
        'static const Duration defaultDuration = Duration(milliseconds: 1500)',
      ),
    );
    expect(
      temporalSource,
      contains('static const int photoMlFrameLimit = 3'),
    );
  });
}
