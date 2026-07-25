import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V4 probe preserves cautious display semantics', () {
    final probe = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    final fusion = File('lib/hcv_display_risk_fusion.dart').readAsStringSync();

    expect(probe, contains('HCVSceneDecisionFusion.fuse'));
    expect(fusion, contains("decision = 'NON_CONCLUSIVE'"));
    expect(fusion, contains('liveCaptureOnly'));
  });
}
