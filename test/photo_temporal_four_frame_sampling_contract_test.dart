import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic video ML sampling keeps the existing 3-second default', () {
    final source =
        File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

    expect(source, contains('int frameIntervalSeconds = 3'));
    expect(source, contains('double? frameSamplingIntervalSeconds'));
    expect(source, contains('int maxFrames = 8'));
    expect(source, contains('fps=1/\$samplingIntervalSeconds'));
    expect(source, contains('-frames:v \$frameLimit'));
    expect(
      source,
      contains(
        'frameSamplingIntervalSeconds == null\n'
        '          ? max(1, frameIntervalSeconds)\n'
        '          : max(0.1, frameSamplingIntervalSeconds)',
      ),
    );
    expect(
      source,
      contains(
        "worst['videoFrameSamplingIntervalSeconds'] = samplingIntervalSeconds;",
      ),
    );
  });

  test('photo Temporal V2 captures 2.4s and requests four 0.6s ML samples', () {
    final source = File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

    expect(
      source,
      contains(
        'static const Duration defaultDuration = Duration(milliseconds: 2400)',
      ),
    );
    expect(
      source,
      contains('static const double photoMlFrameIntervalSeconds = 0.6'),
    );
    expect(
      source,
      contains('static const int photoMlFrameLimit = 4'),
    );
    expect(source, contains('Future<HCVTemporalCaptureClip> capture('));
    expect(source, contains('Future<Map<String, dynamic>> analyzeCapturedClip('));
    expect(
      source,
      contains(
        'frameSamplingIntervalSeconds: photoMlFrameIntervalSeconds',
      ),
    );
    expect(source, contains('maxFrames: photoMlFrameLimit'));
    expect(source, isNot(contains('frameIntervalSeconds: 1')));
    expect(source, contains('PHOTO_TECHNICAL_MINI_VIDEO_V2'));
  });
}
