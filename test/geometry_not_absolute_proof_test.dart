import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('probe documentation does not claim absolute screen proof', () {
    final source = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    expect(source, isNot(contains('absolute proof')));
    expect(source, contains('only corroborates other display evidence'));
  });
}
