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

  double get end => start + (duration <= 0 ? 0.8 : duration);

  factory VideoTranscriptSegment.fromMap(Map<dynamic, dynamic> map) {
    return VideoTranscriptSegment(
      text: map['text']?.toString() ?? '',
      start: (map['start'] as num?)?.toDouble() ?? 0,
      duration: (map['duration'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'start': start,
        'duration': duration,
      };
}

class VideoTranscriptionResult {
  const VideoTranscriptionResult({
    required this.text,
    required this.segments,
    required this.subtitlePath,
    required this.captionedVideoPath,
  });

  final String text;
  final List<VideoTranscriptSegment> segments;
  final String subtitlePath;

  /// Derived copy with synchronized subtitles burned into the image.
  /// The certified source video is never modified or replaced.
  final String captionedVideoPath;
}

class VideoTranscriptionService {
  const VideoTranscriptionService();

  static const MethodChannel _channel = MethodChannel('hcv.media');

  Future<VideoTranscriptionResult> transcribe(String videoPath) async {
    if (!Platform.isIOS) {
      throw PlatformException(
        code: 'TRANSCRIPTION_UNAVAILABLE',
        message: 'La trascrizione automatica è disponibile su iPhone.',
      );
    }

    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'transcribeVideo',
      {'path': videoPath},
    );
    if (raw == null) {
      throw PlatformException(
        code: 'TRANSCRIPTION_EMPTY',
        message: 'Nessuna trascrizione restituita.',
      );
    }

    final text = raw['text']?.toString().trim() ?? '';
    final rawSegments = raw['segments'];
    final wordSegments = <VideoTranscriptSegment>[];
    if (rawSegments is List) {
      for (final item in rawSegments) {
        if (item is Map) {
          final segment = VideoTranscriptSegment.fromMap(item);
          if (segment.text.trim().isNotEmpty) wordSegments.add(segment);
        }
      }
    }

    if (text.isEmpty && wordSegments.isEmpty) {
      throw PlatformException(
        code: 'NO_SPEECH',
        message: 'Non è stato rilevato parlato nel video.',
      );
    }

    final captions = _captionSegments(wordSegments, fallbackText: text);
    final directory = await getApplicationDocumentsDirectory();
    final base = p.basenameWithoutExtension(videoPath).replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        );

    final subtitlePath = p.join(directory.path, '${base}_sigillum.srt');
    await File(subtitlePath).writeAsString(
      _toSrt(captions, fallbackText: text),
      flush: true,
    );

    final captionedVideoPath = p.join(
      directory.path,
      '${base}_sottotitolato.mp4',
    );
    final captionedFile = File(captionedVideoPath);
    if (await captionedFile.exists()) {
      await captionedFile.delete();
    }

    final burned = await _channel.invokeMapMethod<String, dynamic>(
      'burnSubtitles',
      {
        'path': videoPath,
        'outputPath': captionedVideoPath,
        'segments': captions.map((segment) => segment.toMap()).toList(),
      },
    );
    final returnedPath = burned?['path']?.toString() ?? captionedVideoPath;
    if (!await File(returnedPath).exists()) {
      throw PlatformException(
        code: 'SUBTITLE_EXPORT_MISSING',
        message: 'Il video sottotitolato non è stato creato.',
      );
    }

    return VideoTranscriptionResult(
      text: text,
      segments: captions,
      subtitlePath: subtitlePath,
      captionedVideoPath: returnedPath,
    );
  }

  List<VideoTranscriptSegment> _captionSegments(
    List<VideoTranscriptSegment> words, {
    required String fallbackText,
  }) {
    if (words.isEmpty) {
      return [
        VideoTranscriptSegment(
          text: fallbackText,
          start: 0,
          duration: 10,
        ),
      ];
    }

    final captions = <VideoTranscriptSegment>[];
    var currentText = '';
    var currentStart = 0.0;
    var currentEnd = 0.0;

    void flush() {
      final clean = currentText.trim();
      if (clean.isEmpty) return;
      captions.add(
        VideoTranscriptSegment(
          text: clean,
          start: currentStart,
          duration: (currentEnd - currentStart).clamp(0.7, 4.0).toDouble(),
        ),
      );
      currentText = '';
    }

    for (final word in words) {
      final token = word.text.trim();
      if (token.isEmpty) continue;
      final proposed = _appendWord(currentText, token);
      final wordEnd = word.end;
      final proposedStart = currentText.isEmpty ? word.start : currentStart;
      final proposedDuration = wordEnd - proposedStart;
      final mustSplit = currentText.isNotEmpty &&
          (proposed.length > 44 || proposedDuration > 3.2);

      if (mustSplit) {
        flush();
        currentStart = word.start;
        currentEnd = wordEnd;
        currentText = token;
      } else {
        if (currentText.isEmpty) currentStart = word.start;
        currentText = proposed;
        currentEnd = wordEnd;
      }
    }
    flush();

    return captions;
  }

  String _appendWord(String current, String next) {
    if (current.isEmpty) return next;
    if (RegExp(r'^[,.;:!?%)\]}]').hasMatch(next)) {
      return '$current$next';
    }
    return '$current $next';
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
