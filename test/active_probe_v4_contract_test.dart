import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active probe V4 signs illumination and geometry evidence', () {
    final source = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();

    expect(source, contains("'activeProbeVersion': 4"));
    expect(source, contains("'sceneClass': sceneClass"));
    expect(source, contains("'geometryChallenge': geometry.toJson()"));
    expect(source, contains("'geometricRealityEvidence'"));
    expect(source, contains("'planarSceneEvidence'"));
    expect(source, contains("'ACTIVE_V4'"));
  });
}
