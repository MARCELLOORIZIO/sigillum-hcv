import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('archive 42 iOS watermark retries alternate system font locations', () {
    final source =
        File('lib/hcv_location_video_watermark.dart').readAsStringSync();

    expect(source, contains("'/System/Library/Fonts/Avenir.ttc'"));
    expect(source, contains("'/System/Library/Fonts/Core/Avenir.ttc'"));
    expect(source, contains("'/System/Library/Fonts/Helvetica.ttc'"));
    expect(source, contains("'/System/Library/Fonts/Core/Helvetica.ttc'"));
    expect(source, contains('for (final fontFile in _fontCandidates())'));
    expect(source, contains('_isFontResolutionFailure(logs)'));
  });

  test('archive 42 does not expose the complete FFmpeg banner in camera UI', () {
    final source =
        File('lib/hcv_location_video_watermark.dart').readAsStringSync();

    expect(source, contains('_summarizeFfmpegFailure'));
    expect(source, contains("!lower.startsWith('ffmpeg version')"));
    expect(source, contains("!lower.startsWith('configuration:')"));
    expect(
      source,
      isNot(contains(r"'SIGILLUM watermark failed:\n$logs'")),
    );
  });

  test('archive 42 patch does not change video codec or camera orchestration', () {
    final watermark =
        File('lib/hcv_location_video_watermark.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(watermark, contains("'-c:v libx264 '"));
    expect(watermark, contains("'-preset veryfast '"));
    expect(watermark, contains("'-crf 23 '"));
    expect(camera, contains('includeTemporalVideoProbe: false'));
    expect(camera, contains('HCVLocationVideoWatermark().createPublishedVideo'));
  });
}
