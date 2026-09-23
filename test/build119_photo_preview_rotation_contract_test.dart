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

  test('BUILD128 video shares photo orientation and uncropped 1x frame', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains('if (ok)'));
    expect(source, contains('OrientationBuilder('));
    expect(source, contains('fit: BoxFit.contain'));
    expect(source, isNot(contains('OverflowBox(')));
    expect(source, isNot(contains('fit: BoxFit.cover')));
  });

  test('BUILD119 photo cycle and rotation survive BUILD126 video FOV alignment', () {
    final cameraSource = File('lib/camera_page.dart').readAsStringSync();
    final temporalSource =
        File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

    expect(
      cameraSource,
      contains('return ResolutionPreset.high;'),
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
