import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic video ML retries one-frame captures at one-second cadence', () {
    final source = File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

    expect(source, contains('int frameIntervalSeconds = 3'));
    expect(
      source,
      contains('frames.length < 2 && frameSamplingIntervalSeconds == null'),
    );
    expect(source, contains('fallbackSamplingIntervalSeconds = 1.0'));
    expect(source, contains("'fallback_%03d.jpg'"));
    expect(source, contains("'videoFrameSamplingFallbackUsed'"));
  });

  test('photo Temporal V2 explicit sampling is excluded from fallback', () {
    final source = File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

    expect(
      source,
      contains('frameSamplingIntervalSeconds == null'),
      reason: 'fallback must apply only to generic video analysis',
    );
  });
}
