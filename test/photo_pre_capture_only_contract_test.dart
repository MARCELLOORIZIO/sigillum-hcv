import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'photo Temporal V2 keeps pre-capture temporal evidence primary over one still false negative',
    () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      final normalizedCamera = camera.replaceAll(RegExp(r'\s+'), ' ');

      expect(camera, contains('combinePhotoDisplayRiskFromPreCaptureEvidence'));
      expect(camera, contains('liveCaptureOnly: true'));
      expect(
        normalizedCamera,
        contains(
          "liveProbe?['photoDecisionMethod'] == 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT'",
        ),
      );
      expect(
        camera,
        contains(
          "if (isTemporalV2 && legacy.decision == 'STRONG_DISPLAY_RISK')",
        ),
      );
      expect(
        camera,
        contains("'decisionRole': 'POST_CAPTURE_DIAGNOSTIC_ONLY'"),
      );
      expect(camera, isNot(contains('_showCaptureReadyMessage')));
    },
  );
}
