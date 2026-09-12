import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo temporal capture is 1.5 seconds with three 0.6 second ML samples', () {
    final source = File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();
    expect(source, contains('Duration(milliseconds: 1500)'));
    expect(source, contains('photoMlFrameIntervalSeconds = 0.6'));
    expect(source, contains('photoMlFrameLimit = 3'));
  });

  test('camera certificate note reports the active 1.5 second clip', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('disposable 1.5 s clip'));
    expect(source, isNot(contains('disposable 2.4 s clip')));
  });
}
