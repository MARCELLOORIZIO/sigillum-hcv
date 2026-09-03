import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera capture no longer asks the user for manual parallax', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, isNot(contains("_c('physicalProbe')")));
    expect(source, isNot(contains('_hasRequiredParallax')));
    expect(source, isNot(contains('_showCaptureReadyMessage')));
    expect(source, isNot(contains("_c('parallaxRequired')")));
    expect(source, contains('PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT'));
  });
}
