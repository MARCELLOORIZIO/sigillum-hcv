import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic video ML sampling keeps the existing 3-second default', () {
    final source =
        File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

    expect(source, contains('int frameIntervalSeconds = 3'));
    expect(source, contains('int maxFrames = 8'));
    expect(source, contains('fps=1/\$samplingIntervalSeconds'));
    expect(source, contains('-frames:v \$frameLimit'));
    expect(
      source,
      contains(
        "worst['videoFrameSamplingIntervalSeconds'] = samplingIntervalSeconds;",
      ),
    );
  });

  test('photo mini-video requests two ML frames one second apart', () {
    final source = File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

    expect(source, contains('frameIntervalSeconds: 1'));
    expect(source, contains('maxFrames: 2'));
    expect(
      source,
      contains('static const Duration defaultDuration = Duration(milliseconds: 1800)'),
    );
  });
}
