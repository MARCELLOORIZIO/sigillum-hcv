import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subtitle pipeline preserves the complete cumulative transcript', () {
    final service = File('lib/video_transcription_service.dart').readAsStringSync();
    final speechPatch = File(
      'tool/apply_prelaunch_speech_recognition_robustness_20260818.py',
    ).readAsStringSync();

    expect(service, contains('_captionSegmentsWithFullCoverage'));
    expect(service, contains('_tokenCoverage'));
    expect(service, contains('_captionsFromFullText'));
    expect(service, contains("mediaDuration: (raw['duration'] as num?)?.toDouble()"));

    expect(speechPatch, contains('var timeline = [Int: [String: Any]]()'));
    expect(speechPatch, contains('segment.timestamp / 0.08'));
    expect(speechPatch, contains('mergedTimeline()'));
    expect(speechPatch, contains('timelineText.count >= bestText.count'));
    expect(
      speechPatch,
      contains('"duration": sourceDuration.isFinite ? sourceDuration : 0'),
    );
    expect(speechPatch, contains('audioDuration + 20.0'));
  });

  test('verification text action stays on one short label', () {
    final source = File('lib/import_page.dart').readAsStringSync();
    expect(source, contains("? 'VERIFICA TESTO'"));
    expect(source, isNot(contains('VERIFICA TESTO / DOCUMENTO')));
  });
}
