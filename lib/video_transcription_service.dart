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

  Future<VideoTranscriptionResult> transcribe(
    String videoPath, {
    String languageCode = 'it',
  }) async {
    if (!Platform.isIOS) {
      throw PlatformException(
        code: 'TRANSCRIPTION_UNAVAILABLE',
        message: 'La trascrizione automatica è disponibile su iPhone.',
      );
    }

    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'transcribeVideo',
      {
        'path': videoPath,
        'languageCode': languageCode,
      },
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

    final captions = _captionSegmentsWithFullCoverage(
      wordSegments,
      fullText: text,
      mediaDuration: (raw['duration'] as num?)?.toDouble(),
    );
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

  List<VideoTranscriptSegment> _captionSegmentsWithFullCoverage(
    List<VideoTranscriptSegment> words, {
    required String fullText,
    double? mediaDuration,
  }) {
    final normalCaptions = _captionSegments(words, fallbackText: fullText);
    final complete = fullText.trim();
    if (complete.isEmpty) return normalCaptions;

    final captionText = normalCaptions.map((segment) => segment.text).join(' ');
    final fullTokens = _normalizedTokens(complete);
    final captionTokens = _normalizedTokens(captionText);
    if (fullTokens.isEmpty) return normalCaptions;

    final covered = _tokenCoverage(fullTokens, captionTokens);
    if (covered >= 0.97) return normalCaptions;

    // Apple Speech can revise partial hypotheses. Keep the most complete
    // cumulative transcript as the source of truth for wording: if timed
    // segments omit words, rebuild timed captions from the complete text so
    // spoken words are not silently lost from the derived subtitle video.
    final start = words.isEmpty ? 0.0 : words.first.start.clamp(0.0, 359999.0);
    var end = words.isEmpty
        ? 0.0
        : words.map((word) => word.end).reduce((a, b) => a > b ? a : b);
    if (mediaDuration != null && mediaDuration > end) end = mediaDuration;
    if (end <= start) end = start + 10.0;

    return _captionsFromFullText(complete, start: start, end: end);
  }

  List<String> _normalizedTokens(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9à-öø-ÿ]+', caseSensitive: false), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  double _tokenCoverage(List<String> expected, List<String> actual) {
    if (expected.isEmpty) return 1.0;
    final available = <String, int>{};
    for (final token in actual) {
      available[token] = (available[token] ?? 0) + 1;
    }
    var matched = 0;
    for (final token in expected) {
      final count = available[token] ?? 0;
      if (count > 0) {
        matched++;
        available[token] = count - 1;
      }
    }
    return matched / expected.length;
  }

  List<VideoTranscriptSegment> _captionsFromFullText(
    String text, {
    required double start,
    required double end,
  }) {
    final words =
        text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return const [];

    final groups = <String>[];
    var current = <String>[];
    for (final word in words) {
      final proposed = [...current, word].join(' ');
      if (current.isNotEmpty && (current.length >= 7 || proposed.length > 58)) {
        groups.add(current.join(' '));
        current = <String>[];
      }
      current.add(word);
    }
    if (current.isNotEmpty) groups.add(current.join(' '));

    final totalDuration = (end - start).clamp(1.0, 359999.0).toDouble();
    final perGroup = totalDuration / groups.length;
    return [
      for (var i = 0; i < groups.length; i++)
        VideoTranscriptSegment(
          text: groups[i],
          start: start + (perGroup * i),
          duration: perGroup.clamp(0.9, 5.0).toDouble(),
        ),
    ];
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

    final ordered = [...words]..sort((a, b) => a.start.compareTo(b.start));
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
          duration: (currentEnd - currentStart).clamp(0.9, 4.6).toDouble(),
        ),
      );
      currentText = '';
      currentStart = 0;
      currentEnd = 0;
    }

    for (final word in ordered) {
      final token = word.text.trim();
      if (token.isEmpty) continue;

      final wordEnd = word.end;
      final pause = currentText.isEmpty ? 0.0 : word.start - currentEnd;
      final proposed = _appendWord(currentText, token);
      final proposedStart = currentText.isEmpty ? word.start : currentStart;
      final proposedDuration = wordEnd - proposedStart;
      final sentenceBoundary = currentText.isNotEmpty &&
          RegExp(r'[.!?…]$').hasMatch(currentText.trim());
      final mustSplit = currentText.isNotEmpty &&
          (pause > 0.75 ||
              proposed.length > 64 ||
              proposedDuration > 4.2 ||
              sentenceBoundary);

      if (mustSplit) {
        flush();
      }
      if (currentText.isEmpty) currentStart = word.start;
      currentText = _appendWord(currentText, token);
      currentEnd = wordEnd;
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
      final end =
          segment.start + (segment.duration <= 0 ? 1.0 : segment.duration);
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
