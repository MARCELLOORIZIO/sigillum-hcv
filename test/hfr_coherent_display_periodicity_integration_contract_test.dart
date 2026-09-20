import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo and video final decisions both consume HFR physical evidence',
      () {
    final cameraSource = File('lib/camera_page.dart').readAsStringSync();
    final policySource =
        File('lib/hcv_context_free_display_policy.dart').readAsStringSync();

    expect(
      RegExp(r'HCVContextFreeDisplayPolicy\.resolvePhoto\(')
          .allMatches(cameraSource)
          .length,
      equals(1),
    );
    expect(
      RegExp(r'HCVContextFreeDisplayPolicy\.resolveVideo\(')
          .allMatches(cameraSource)
          .length,
      equals(1),
    );
    expect(
      RegExp(r'temporalFrequencyProbe:\s*temporalFrequencyProbe')
          .allMatches(cameraSource)
          .length,
      greaterThanOrEqualTo(2),
    );

    expect(policySource, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
    expect(policySource, contains('displayLike >= 7'));
    expect(policySource, contains('realityLike == 0'));
    expect(policySource, contains('periodic >= 7'));
    expect(policySource, contains('stable >= 7'));
    expect(policySource, contains('spatial == 9'));
    expect(policySource, contains('harmonic == 9'));
    expect(policySource, contains('rowTime == 9'));
  });
}
