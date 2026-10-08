import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subtitle transcription retries uncovered media tail', () {
    final service =
        File('lib/video_transcription_service.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(service, contains('while (wordSegments.isNotEmpty && attempts < 6)'));
    expect(service, contains('final remaining = mediaDuration - lastEnd;'));
    expect(service, contains("startSeconds: tailStart"));
    expect(service, contains("if (error.code == 'NO_SPEECH') break;"));
    expect(service, contains('final merged = _mergeSegments('));

    expect(scene, contains('startSeconds: Double'));
    expect(
      scene,
      contains('"start": startSeconds + segment.timestamp'),
    );
    expect(scene, contains('exporter.timeRange = CMTimeRange('));
    expect(
      scene,
      contains('sourceDuration - startSeconds'),
    );
  });

  test('full-text fallback cannot end early because of a 5 second cap', () {
    final service =
        File('lib/video_transcription_service.dart').readAsStringSync();

    expect(
      service,
      isNot(contains('duration: perGroup.clamp(0.9, 5.0).toDouble()')),
    );
    expect(
      service,
      contains('(i == groups.length - 1)'),
    );
    expect(
      service,
      contains('end - (start + (perGroup * i))'),
    );
  });

  test('burn-in remains full source duration and uses supplied timing', () {
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(
      scene,
      contains(
        'insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration)',
      ),
    );
    expect(
      scene,
      contains(
        'instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)',
      ),
    );
    expect(
      scene,
      contains('visibility.beginTime = AVCoreAnimationBeginTimeAtZero + max(0, start)'),
    );
    expect(scene, contains('visibility.duration = duration'));
  });
}
