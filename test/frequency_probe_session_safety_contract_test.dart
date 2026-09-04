import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'frequency probe never mutates active camera format behind Flutter session',
      () {
    final source =
        File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
    expect(source, isNot(contains("'configureTemporalFrequencyProbe'")));
    expect(source, isNot(contains("'lockTemporalProbeOptics'")));
    expect(source, contains("'applyShortExposure'"));
    expect(source, contains("'PLUGIN_ACTIVE_FORMAT_PRESERVED_SESSION_SAFE'"));
    expect(source, contains("..remove('activeFormatIndex')"));
    expect(source, contains("..remove('activeVideoMinFrameDurationSeconds')"));
    expect(source, contains("..remove('activeVideoMaxFrameDurationSeconds')"));
    expect(source, contains('await controller.startVideoRecording()'));
  });

  test('frequency probe remains shadow-only', () {
    final source =
        File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
    expect(source, contains("'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL'"));
    expect(source, contains("'productionDecisionChanged': false"));
  });
}
