import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVAudioFingerprint {
  const HCVAudioFingerprint._();

  static const String type = 'SIGILLUM_AUDIO_FINGERPRINT';
  static const int version = 1;
  static const String algorithm = 'SIGILLUM_AUDIO_ACF_ENVELOPE_V1';
  static const String policy = 'SIGILLUM_AUDIO_FINGERPRINT_REQUIRED_V1';
  static const int sampleRate = 8000;
  static const int windowMs = 1000;
  static const int hopMs = 500;
  static const int featureBytes = 24;
  static const int _windowSamples = sampleRate;
  static const int _hopSamples = sampleRate ~/ 2;
  static const int _minimumFrameSamples = sampleRate ~/ 4;
  static const int _maxFrames = 29;
  static const double _maxFrameDistance = 18.0;
  static const List<int> _correlationLags = <int>[
    8,
    12,
    16,
    24,
    32,
    48,
    64,
    96,
    128,
    192,
    256,
    384,
    512,
    768,
    1024,
    1536,
  ];

  static Future<Map<String, dynamic>> buildFromVideo(String videoPath) async {
    final source = File(videoPath);
    if (!await source.exists()) {
      throw Exception('Video non trovato per fingerprint audio: $videoPath');
    }

    final tempDir = await getTemporaryDirectory();
    final rawFile = File(
      p.join(
        tempDir.path,
        'hcv_audio_fp_${DateTime.now().microsecondsSinceEpoch}.pcm',
      ),
    );
    final safeInput = _escapePath(videoPath);
    final safeOutput = _escapePath(rawFile.path);

    try {
      final command = "-y -i '$safeInput' -vn -ac 1 -ar $sampleRate "
          "-acodec pcm_s16le -f s16le '$safeOutput'";
      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();
      if (code == null || !ReturnCode.isSuccess(code)) {
        final logs = await session.getAllLogsAsString();
        throw Exception('Audio fingerprint extraction failed: ${logs ?? ''}');
      }
      if (!await rawFile.exists() || await rawFile.length() < 4000) {
        throw Exception('Audio track unavailable or too short for fingerprint');
      }

      final bytes = await rawFile.readAsBytes();
      final samples = List<int>.filled(bytes.length ~/ 2, 0);
      for (var i = 0, sampleIndex = 0;
          i + 1 < bytes.length;
          i += 2, sampleIndex++) {
        var value = bytes[i] | (bytes[i + 1] << 8);
        if (value >= 0x8000) value -= 0x10000;
        samples[sampleIndex] = value;
      }
      return buildFromPcm16Samples(samples);
    } finally {
      try {
        if (await rawFile.exists()) await rawFile.delete();
      } catch (_) {}
    }
  }

  static Map<String, dynamic> buildFromPcm16Samples(List<int> samples) {
    if (samples.length < _minimumFrameSamples) {
      throw ArgumentError('PCM audio too short for fingerprint');
    }

    final hashes = <String>[];
    for (var start = 0;
        start < samples.length && hashes.length < _maxFrames;
        start += _hopSamples) {
      final end = min(samples.length, start + _windowSamples);
      if (end - start < _minimumFrameSamples) break;
      hashes.add(_frameFingerprint(samples.sublist(start, end)));
    }
    if (hashes.isEmpty) {
      throw ArgumentError('No analyzable PCM audio frames');
    }

    return <String, dynamic>{
      'type': type,
      'version': version,
      'algorithm': algorithm,
      'sampleRate': sampleRate,
      'windowMs': windowMs,
      'hopMs': hopMs,
      'featureBytes': featureBytes,
      'frameCount': hashes.length,
      'frameHashes': hashes,
      'combinedHash': sha256.convert(hashes.join('|').codeUnits).toString(),
    };
  }

  static bool isValidFingerprint(Map<dynamic, dynamic>? value) {
    if (value == null ||
        value['type'] != type ||
        value['version'] != version ||
        value['algorithm'] != algorithm ||
        value['sampleRate'] != sampleRate ||
        value['windowMs'] != windowMs ||
        value['hopMs'] != hopMs ||
        value['featureBytes'] != featureBytes) {
      return false;
    }
    final hashes = value['frameHashes'];
    final frameCount = (value['frameCount'] as num?)?.toInt();
    if (hashes is! List ||
        hashes.isEmpty ||
        frameCount != hashes.length ||
        hashes.length > _maxFrames) {
      return false;
    }
    final pattern = RegExp(r'^[a-f0-9]{48}$');
    return hashes.every((item) => pattern.hasMatch(item.toString()));
  }

  static bool matches(
    Map<dynamic, dynamic> expected,
    Map<dynamic, dynamic> current,
  ) {
    if (!isValidFingerprint(expected) || !isValidFingerprint(current)) {
      return false;
    }
    final expectedHashes = (expected['frameHashes'] as List)
        .map((value) => value.toString())
        .toList();
    final currentHashes = (current['frameHashes'] as List)
        .map((value) => value.toString())
        .toList();
    final comparable = min(expectedHashes.length, currentHashes.length);
    if (comparable == 0) return false;

    final used = <int>{};
    var matched = 0;
    for (var i = 0; i < expectedHashes.length; i++) {
      final low = max(0, i - 3);
      final high = min(currentHashes.length - 1, i + 3);
      var bestIndex = -1;
      var bestDistance = double.infinity;
      for (var j = low; j <= high; j++) {
        if (used.contains(j)) continue;
        final distance = frameDistance(expectedHashes[i], currentHashes[j]);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = j;
        }
      }
      if (bestIndex >= 0 && bestDistance <= _maxFrameDistance) {
        used.add(bestIndex);
        matched++;
      }
    }

    final requiredMatches = comparable <= 2
        ? comparable
        : max(3, (comparable * 0.50).ceil());
    return matched >= requiredMatches;
  }

  static double frameDistance(String left, String right) {
    if (left.length != featureBytes * 2 || right.length != featureBytes * 2) {
      return double.infinity;
    }
    var total = 0;
    for (var i = 0; i < left.length; i += 2) {
      final a = int.tryParse(left.substring(i, i + 2), radix: 16);
      final b = int.tryParse(right.substring(i, i + 2), radix: 16);
      if (a == null || b == null) return double.infinity;
      total += (a - b).abs();
    }
    return total / featureBytes;
  }

  static String _frameFingerprint(List<int> samples) {
    final mean = samples.fold<double>(0.0, (sum, value) => sum + value) /
        samples.length;
    final features = <int>[];

    for (final lag in _correlationLags) {
      var numerator = 0.0;
      var energyA = 0.0;
      var energyB = 0.0;
      if (lag < samples.length) {
        for (var i = lag; i < samples.length; i++) {
          final a = samples[i] - mean;
          final b = samples[i - lag] - mean;
          numerator += a * b;
          energyA += a * a;
          energyB += b * b;
        }
      }
      final denominator = sqrt(energyA * energyB);
      final correlation = denominator > 1e-9
          ? (numerator / denominator).clamp(-1.0, 1.0).toDouble()
          : 0.0;
      features.add(((correlation + 1.0) * 127.5).round().clamp(0, 255).toInt());
    }

    final envelope = <double>[];
    for (var bin = 0; bin < 8; bin++) {
      final start = samples.length * bin ~/ 8;
      final end = samples.length * (bin + 1) ~/ 8;
      var squareSum = 0.0;
      for (var i = start; i < end; i++) {
        final centered = samples[i] - mean;
        squareSum += centered * centered;
      }
      final count = max(1, end - start);
      final rms = sqrt(squareSum / count);
      envelope.add(log(rms + 1.0));
    }
    final envelopeMedian = _median(envelope);
    for (final value in envelope) {
      final delta = (value - envelopeMedian).clamp(-2.0, 2.0).toDouble();
      features.add((((delta + 2.0) / 4.0) * 255.0).round().clamp(0, 255).toInt());
    }

    return features
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  static String _escapePath(String value) {
    return value.replaceAll("'", r"'\\''");
  }
}
