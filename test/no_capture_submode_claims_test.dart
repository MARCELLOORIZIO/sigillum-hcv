import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera no longer emits studio or field capture modes', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, isNot(contains('"captureMode": captureMode')));
    expect(source, isNot(contains("captureMode = 'field'")));
    expect(source, isNot(contains("captureMode = 'studio'")));
    expect(source, contains('"captureMode": "STANDARD"'));
  });
}
