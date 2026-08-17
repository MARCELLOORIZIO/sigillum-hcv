import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VideoTranscriptSegment {
  const VideoTranscriptSegment({
    required this.text,
    required this.start,
    required this.duration,
  });

  final String text;
  final double start;
  final double duration;

  factory VideoTranscriptSegment.fromMap(Map<dynamic, dynamic> map) {
    return VideoTranscriptSegment(
      text: map['text']?.toString() ?? '',
      start: (map['start'] as num?)?.toDouble() ?? 0,
      duration: (map['duration'] as num?)?.toDouble() ?? 0,
    );
  }
}

class VideoTranscriptionResult {
  const VideoTranscriptionResult({
    required this.text,
    required this.segments,
    required this.subtitlePath,
  });

  final String text;
  final List<VideoTranscriptSegment> segments;
  final String subtitlePath;
}

class VideoTranscriptionService {
  const VideoTranscriptionService();

  static const MethodChannel _channel = MethodChannel('hcv.media');

  Future<VideoTranscriptionResult> transcribe(String videoPath) async {
    if (!Platform.isIOS) {
      throw const PlatformException(
        code: 'TRANSCRIPTION_UNAVAILABLE',
        message: 'La trascrizione automatica è disponibile su iPhone.',
      );
    }

    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'transcribeVideo',
      {'path': videoPath},
    );
    if (raw == null) {
      throw const PlatformException(
        code: 'TRANSCRIPTION_EMPTY',
        message: 'Nessuna trascrizione restituita.',
      );
    }

    final text = raw['text']?.toString().trim() ?? '';
    final rawSegments = raw['segments'];
    final segments = <VideoTranscriptSegment>[];
    if (rawSegments is List) {
      for (final item in rawSegments) {
        if (item is Map) segments.add(VideoTranscriptSegment.fromMap(item));
      }
    }

    if (text.isEmpty && segments.isEmpty) {
      throw const PlatformException(
        code: 'NO_SPEECH',
        message: 'Non è stato rilevato parlato nel video.',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final base = p.basenameWithoutExtension(videoPath).replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        );
    final subtitlePath = p.join(directory.path, '${base}_sigillum.srt');
    await File(subtitlePath).writeAsString(
      _toSrt(segments, fallbackText: text),
      flush: true,
    );

    return VideoTranscriptionResult(
      text: text,
      segments: segments,
      subtitlePath: subtitlePath,
    );
  }

  String _toSrt(
    List<VideoTranscriptSegment> segments, {
    required String fallbackText,
  }) {
    if (segments.isEmpty) {
      return '1\n00:00:00,000 --> 00:00:10,000\n$fallbackText\n';
    }

    final buffer = StringBuffer();
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final end = segment.start + (segment.duration <= 0 ? 1.0 : segment.duration);
      buffer
        ..writeln(index + 1)
        ..writeln('${_time(segment.start)} --> ${_time(end)}')
        ..writeln(segment.text.trim())
        ..writeln();
    }
    return buffer.toString();
  }

  String _time(double seconds) {
    final milliseconds = (seconds.clamp(0, 359999.0) * 1000).round();
    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds % 3600000) ~/ 60000;
    final secs = (milliseconds % 60000) ~/ 1000;
    final millis = milliseconds % 1000;
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${two(hours)}:${two(minutes)}:${two(secs)},${three(millis)}';
  }
}
