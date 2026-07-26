import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active probe V5 signs illumination, geometry, and temporal evidence', () {
    final source =
        File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();

    expect(source, contains("'activeProbeVersion': 5"));
    expect(source, contains("'sceneClass': sceneClass"));
    expect(source, contains("'geometryChallenge': geometry.toJson()"));
    expect(source, contains("'geometricRealityEvidence'"));
    expect(source, contains("'planarSceneEvidence'"));
    expect(source, contains("'ACTIVE_V5'"));
    expect(source, contains('HCVTemporalCaptureProbe'));
    expect(
      source,
      contains("'VIDEO_EQUIVALENT_PRE_CAPTURE_TEMPORAL_ANALYSIS'"),
    );
  });
}
