import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'photo keeps live evidence primary and requires structural corroboration',
    () {
      final camera = File('lib/camera_page.dart').readAsStringSync();

      expect(camera, contains('combinePhotoDisplayRiskFromPreCaptureEvidence'));
      expect(camera, contains('liveCaptureOnly: true'));
      expect(
        camera,
        contains(
          'if (!_hasLiveTemporalScreenCorroboration(liveProbe)) return preCapture;',
        ),
      );
      expect(
        camera,
        contains(
          'final corroborated = HCVDisplayRiskFusion.combine(analyses);',
        ),
      );
      expect(
        camera,
        contains("'decisionRole': 'POST_CAPTURE_DIAGNOSTIC_ONLY'"),
      );
    },
  );
}
