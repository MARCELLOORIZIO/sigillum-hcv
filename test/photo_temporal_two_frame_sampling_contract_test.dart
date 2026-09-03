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

  test('photo Temporal V2 captures 2.4s and requests up to four ML frames', () {
    final source = File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

    expect(
      source,
      contains(
        'static const Duration defaultDuration = Duration(milliseconds: 2400)',
      ),
    );
    expect(source, contains('Future<HCVTemporalCaptureClip> capture('));
    expect(source, contains('Future<Map<String, dynamic>> analyzeCapturedClip('));
    expect(source, contains('frameIntervalSeconds: 1'));
    expect(source, contains('maxFrames: 4'));
    expect(source, contains('PHOTO_TECHNICAL_MINI_VIDEO_V2'));
  });
}
