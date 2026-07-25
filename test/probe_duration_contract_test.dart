import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('physical probe keeps a short capture delay', () {
    final source = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    expect(source, contains('Duration(milliseconds: 3000)'));
    expect(source, contains('maxFrames = 45'));
  });
}
