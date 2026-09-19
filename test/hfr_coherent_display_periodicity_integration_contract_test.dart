import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PHOTO and VIDEO final decisions consume context-free HFR evidence', () {
    final cameraSource = File('lib/camera_page.dart').readAsStringSync();
    final policySource =
        File('lib/hcv_context_free_display_policy.dart').readAsStringSync();

    // BUILD123 replaces the historical _promoteWithCoherentHfr... capture
    // wiring. The helper remains for legacy analysis contracts but neither
    // final certificate decision may use it or the Scene Context override.
    expect(
      'HCVContextFreeDisplayPolicy.resolve('
          .allMatches(cameraSource)
          .length,
      2,
    );
    expect(cameraSource, isNot(contains('HCVDisplayFinalPolicy.resolve(')));
    expect(
      policySource,
      contains('BUILD123_HFR_7_OF_9_PHYSICAL_DISPLAY'),
    );
    expect(policySource, contains("grid['displayLikeCellCount']"));
    expect(policySource, contains("temporal['periodicCellCount']"));
    expect(policySource, contains("grid['rowTimeFamilyCellCount']"));
  });
}
