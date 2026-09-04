import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native V2 owns camera only after Flutter controller is disposed', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final start = camera.indexOf('_captureTemporalFrequencyNativeIsolated');
    final end =
        camera.indexOf('Future<void> _settleCameraAfterLiveProbe', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final helper = camera.substring(start, end);
    expect(helper, contains('await active.dispose()'));
    expect(helper, contains('captureNative('));
    expect(
      helper.indexOf('captureNative('),
      greaterThan(helper.indexOf('await active.dispose()')),
    );
    expect(helper, contains('await replacement.initialize()'));
  });

  test('native V2 no longer records a disposable Flutter video', () {
    final source =
        File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
    expect(source, isNot(contains("import 'package:camera/camera.dart'")));
    expect(source, isNot(contains('startVideoRecording()')));
    expect(source, isNot(contains('FFmpegKit')));
    expect(source, contains('captureTemporalFrequencyNative'));
  });

  test('frequency probe remains shadow-only', () {
    final source =
        File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
    expect(source, contains("'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL'"));
    expect(source, contains("'productionDecisionChanged': false"));
  });
}
