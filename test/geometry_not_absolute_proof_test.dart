import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('geometry remains corroborative evidence in the V5 probe', () {
    final source =
        File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();

    expect(source, isNot(contains('absolute proof')));
    expect(source, contains("'geometricRealityEvidence'"));
    expect(source, contains("'planarSceneEvidence'"));
    expect(source, contains("'geometryChallenge': geometry.toJson()"));
    expect(source, contains('low-resolution camera-motion geometry'));
  });
}
