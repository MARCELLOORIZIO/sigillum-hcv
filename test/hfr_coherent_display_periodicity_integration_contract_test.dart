import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo and video final decisions both consume strict HFR evidence', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('HFR_COHERENT_DISPLAY_PERIODICITY'));
    expect(source, contains('HFR_FULL_FRAME_COHERENT_DISPLAY_PERIODICITY'));
    expect(
      RegExp(r'_promoteWithCoherentHfrDisplayPeriodicity\(')
          .allMatches(source)
          .length,
      greaterThanOrEqualTo(3),
    );
    expect(
      RegExp(r'baseDisplayRisk,\s*temporalFrequencyProbe,')
          .allMatches(source)
          .length,
      equals(2),
    );
  });
}
