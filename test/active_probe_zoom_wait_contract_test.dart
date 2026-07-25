import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active probe restores zoom before returning', () {
    final source = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    final restore = source.indexOf('setZoomLevel(restoreZoomLevel)');
    final wait = source.indexOf('Duration(milliseconds: 500)', restore);

    expect(restore, greaterThanOrEqualTo(0));
    expect(wait, greaterThan(restore));
  });
}
