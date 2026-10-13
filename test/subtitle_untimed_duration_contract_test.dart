import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('untimed transcript captions use media duration rather than ten-second fallback', () {
    final source = File('lib/video_transcription_service.dart').readAsStringSync();
    final fullCoverage = source.split('List<VideoTranscriptSegment> _captionSegmentsWithFullCoverage(')[1].split('List<String> _normalizedTokens(')[0];
    expect(fullCoverage, contains('if (words.isEmpty &&'));
    expect(fullCoverage, contains('mediaDuration.isFinite'));
    expect(fullCoverage, contains('mediaDuration > 0'));
    expect(fullCoverage, contains('_captionsFromFullText(complete, start: 0, end: mediaDuration)'));
  });
}
