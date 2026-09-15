from pathlib import Path

AUDIO_FILE = r'''import 'dart:io';
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
      final samples = <int>[];
      samples.length = bytes.length ~/ 2;
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
      features.add(((correlation + 1.0) * 127.5).round().clamp(0, 255));
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
      features.add((((delta + 2.0) / 4.0) * 255.0).round().clamp(0, 255));
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
'''

SOCIAL_FILE = r'''import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_audio_fingerprint.dart';

class HCVSocialFingerprint {
  static const MethodChannel _mediaChannel = MethodChannel('hcv.media');

  Future<Map<String, dynamic>> buildFromImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Immagine non trovata: $imagePath');
    }

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('Immagine non leggibile per fingerprint social');
    }

    final normalized = img.copyResize(
      decoded,
      width: 16,
      height: 16,
      interpolation: img.Interpolation.average,
    );
    final hash = _averageHash(normalized);

    return {
      'algorithm': 'SIGILLUM_SOCIAL_IMAGE_AHASH_V1',
      'imageHash': hash,
      'combinedHash': sha256.convert(hash.codeUnits).toString(),
    };
  }

  Future<Map<String, dynamic>> buildFromVideo(String videoPath) async {
    final visual = await buildVisualFromVideo(videoPath);
    final audio = await HCVAudioFingerprint.buildFromVideo(videoPath);
    return <String, dynamic>{
      ...visual,
      'audioFingerprintPolicy': HCVAudioFingerprint.policy,
      'audioFingerprint': audio,
    };
  }

  Future<Map<String, dynamic>> buildVisualFromVideo(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      throw Exception('Video non trovato: $videoPath');
    }

    final workDir = await _extractVideoFrames(videoPath);
    final frames = workDir.listSync().whereType<File>().where((f) {
      final lower = f.path.toLowerCase();
      return lower.endsWith('.png') || lower.endsWith('.jpg');
    }).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (frames.isEmpty) {
      throw Exception('Nessun frame estratto per fingerprint social');
    }

    final hashes = <String>[];

    for (final frame in frames) {
      final bytes = await frame.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) continue;

      hashes.add(_averageHash(_normalizeVideoFrame(decoded)));
    }

    try {
      await workDir.delete(recursive: true);
    } catch (_) {}

    final combined = hashes.join('|');

    return {
      'algorithm': 'SIGILLUM_SOCIAL_AHASH_V1',
      'frameCount': hashes.length,
      'frameHashes': hashes,
      'combinedHash': sha256.convert(combined.codeUnits).toString(),
    };
  }

  Future<Directory> _extractVideoFrames(String videoPath) async {
    if (Platform.isIOS) {
      return _extractVideoFramesNative(videoPath);
    }

    return _extractVideoFramesFfmpeg(videoPath);
  }

  Future<Directory> _extractVideoFramesNative(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempDir.path,
        'hcv_social_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    if (!await workDir.exists()) {
      await workDir.create(recursive: true);
    }

    const seconds = [0.0, 0.5, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0];

    for (var i = 0; i < seconds.length; i++) {
      try {
        final framePath = await _mediaChannel.invokeMethod<String>(
          'extractVideoFrame',
          {'path': videoPath, 'seconds': seconds[i]},
        );

        if (framePath == null || framePath.isEmpty) continue;

        final source = File(framePath);
        if (!await source.exists()) continue;

        await source.copy(
          p.join(workDir.path, 'frame_${i.toString().padLeft(3, '0')}.jpg'),
        );
      } catch (_) {}
    }

    return workDir;
  }

  Future<Directory> _extractVideoFramesFfmpeg(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempDir.path,
        'hcv_social_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    if (!await workDir.exists()) {
      await workDir.create(recursive: true);
    }

    final framePattern = p.join(workDir.path, 'frame_%03d.png');

    final command = "-y -i '$videoPath' "
        "-vf \"fps=1/2,scale=16:16:force_original_aspect_ratio=decrease,"
        "pad=16:16:(ow-iw)/2:(oh-ih)/2,format=gray\" "
        "-frames:v 8 '$framePattern'";

    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();

    if (code == null || !ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('Social fingerprint failed:\n$logs');
    }

    return workDir;
  }

  img.Image _normalizeVideoFrame(img.Image frame) {
    return img.copyResize(
      frame,
      width: 16,
      height: 16,
      interpolation: img.Interpolation.average,
    );
  }

  String _averageHash(img.Image image) {
    final values = <int>[];

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luma = img.getLuminance(pixel).round();
        values.add(luma);
      }
    }

    final avg = values.reduce((a, b) => a + b) / max(values.length, 1);

    final bits = values.map((v) => v >= avg ? '1' : '0').join();

    final chunks = <String>[];
    for (var i = 0; i < bits.length; i += 4) {
      final part = bits.substring(i, min(i + 4, bits.length));
      chunks.add(int.parse(part.padRight(4, '0'), radix: 2).toRadixString(16));
    }

    return chunks.join();
  }
}
'''

Path('lib/hcv_audio_fingerprint.dart').write_text(AUDIO_FILE, encoding='utf-8')
Path('lib/hcv_social_fingerprint.dart').write_text(SOCIAL_FILE, encoding='utf-8')

registry_path = Path('lib/registry_verify_page.dart')
source = registry_path.read_text(encoding='utf-8')

if "import 'hcv_audio_fingerprint.dart';" not in source:
    source = source.replace(
        "import 'hcv_social_fingerprint.dart';\n",
        "import 'hcv_social_fingerprint.dart';\nimport 'hcv_audio_fingerprint.dart';\n",
        1,
    )

helper_marker = 'HCVAudioFingerprintClaimState'
if helper_marker not in source:
    anchor = """bool? resolveHCVSocialFingerprintAvailability(
  Map<dynamic, dynamic> claims, {
  required String mediaType,
}) {
  switch (resolveHCVSocialFingerprintClaimState(
    claims,
    mediaType: mediaType,
  )) {
    case HCVSocialFingerprintClaimState.usable:
      return true;
    case HCVSocialFingerprintClaimState.legacyMissing:
      return null;
    case HCVSocialFingerprintClaimState.modernInvalid:
      return false;
  }
}

class RegistryVerifyPage extends StatefulWidget {
"""
    replacement = """bool? resolveHCVSocialFingerprintAvailability(
  Map<dynamic, dynamic> claims, {
  required String mediaType,
}) {
  switch (resolveHCVSocialFingerprintClaimState(
    claims,
    mediaType: mediaType,
  )) {
    case HCVSocialFingerprintClaimState.usable:
      return true;
    case HCVSocialFingerprintClaimState.legacyMissing:
      return null;
    case HCVSocialFingerprintClaimState.modernInvalid:
      return false;
  }
}

enum HCVAudioFingerprintClaimState {
  usable,
  legacyMissing,
  modernInvalid,
}

HCVAudioFingerprintClaimState resolveHCVAudioFingerprintClaimState(
  Map<dynamic, dynamic> claims,
) {
  final social = claims['socialFingerprint'];
  if (social is! Map || !social.containsKey('audioFingerprintPolicy')) {
    return HCVAudioFingerprintClaimState.legacyMissing;
  }
  if (social['audioFingerprintPolicy'] != HCVAudioFingerprint.policy) {
    return HCVAudioFingerprintClaimState.modernInvalid;
  }
  final audio = social['audioFingerprint'];
  if (audio is! Map || !HCVAudioFingerprint.isValidFingerprint(audio)) {
    return HCVAudioFingerprintClaimState.modernInvalid;
  }
  return HCVAudioFingerprintClaimState.usable;
}

bool? resolveHCVAudioFingerprintAvailability(Map<dynamic, dynamic> claims) {
  switch (resolveHCVAudioFingerprintClaimState(claims)) {
    case HCVAudioFingerprintClaimState.usable:
      return true;
    case HCVAudioFingerprintClaimState.legacyMissing:
      return null;
    case HCVAudioFingerprintClaimState.modernInvalid:
      return false;
  }
}

class RegistryVerifyPage extends StatefulWidget {
"""
    if anchor not in source:
        raise RuntimeError('audio helper anchor not found')
    source = source.replace(anchor, replacement, 1)

source = source.replace(
    "final current = await HCVSocialFingerprint().buildFromVideo(mediaPath!);",
    "final current = await HCVSocialFingerprint().buildVisualFromVideo(mediaPath!);",
    1,
)

if '_matchesCertifiedAudioFingerprint(' not in source:
    anchor = """  Future<bool?> _matchesCertifiedImageFingerprint(
    Map<String, dynamic> cert,
  ) async {
"""
    method = """  Future<bool?> _matchesCertifiedAudioFingerprint(
    Map<String, dynamic> cert,
  ) async {
    if (mediaPath == null) return null;
    final lowerPath = mediaPath!.toLowerCase();
    if (!lowerPath.endsWith('.mp4') &&
        !lowerPath.endsWith('.mov') &&
        !lowerPath.endsWith('.m4v')) {
      return null;
    }

    final claims = cert['claims'];
    if (claims is! Map) return null;
    final availability = resolveHCVAudioFingerprintAvailability(claims);
    if (availability != true) return availability;

    final social = claims['socialFingerprint'] as Map;
    final stored = Map<String, dynamic>.from(
      social['audioFingerprint'] as Map,
    );
    try {
      final current = await HCVAudioFingerprint.buildFromVideo(mediaPath!);
      return HCVAudioFingerprint.matches(stored, current);
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _matchesCertifiedImageFingerprint(
    Map<String, dynamic> cert,
  ) async {
"""
    if anchor not in source:
        raise RuntimeError('audio matcher anchor not found')
    source = source.replace(anchor, method, 1)

verify_anchor = """      final videoFingerprintMatches = await _matchesCertifiedVideoFingerprint(
        cert,
      );
      final imageFingerprintMatches = await _matchesCertifiedImageFingerprint(
        cert,
      );
"""
verify_replacement = """      final videoFingerprintMatches = await _matchesCertifiedVideoFingerprint(
        cert,
      );
      final audioFingerprintMatches = await _matchesCertifiedAudioFingerprint(
        cert,
      );
      final imageFingerprintMatches = await _matchesCertifiedImageFingerprint(
        cert,
      );
"""
if verify_anchor in source:
    source = source.replace(verify_anchor, verify_replacement, 1)
elif 'audioFingerprintMatches = await' not in source:
    raise RuntimeError('audio verification call anchor not found')

branch_anchor = """          if (contentType == 'video' && videoFingerprintMatches == true) {
            markVerified(
              hcvIdWasDetectedInMedia
                  ? 'SOCIAL VERIFIED OK\\nHCV-ID rilevato nel video, certificato Registry valido e fingerprint video compatibile. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.'
                  : 'SOCIAL VERIFIED OK\\nHCV-ID inserito, certificato Registry valido e fingerprint video compatibile. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.',
              'SOCIAL VERIFIED OK',
            );
"""
branch_replacement = """          if (contentType == 'video' &&
              videoFingerprintMatches == true &&
              audioFingerprintMatches == false) {
            status = hcvIdWasDetectedInMedia
                ? 'HCV-ID e fingerprint video compatibili, ma il fingerprint audio non corrisponde al contenuto certificato. Possibile audio sostituito, rimosso o alterato oltre la tolleranza di ricompressione.'
                : 'HCV-ID inserito e fingerprint video compatibile, ma il fingerprint audio non corrisponde al contenuto certificato. Il video selezionato non verifica la traccia audio certificata.';
            result = 'ID VALID / MEDIA NOT VERIFIED';
          } else if (contentType == 'video' && videoFingerprintMatches == true) {
            markVerified(
              audioFingerprintMatches == true
                  ? (hcvIdWasDetectedInMedia
                        ? 'SOCIAL VERIFIED OK\\nHCV-ID rilevato nel video, certificato Registry valido, fingerprint video compatibile e fingerprint audio compatibile dopo ricompressione.'
                        : 'SOCIAL VERIFIED OK\\nHCV-ID inserito, certificato Registry valido, fingerprint video compatibile e fingerprint audio compatibile dopo ricompressione.')
                  : (hcvIdWasDetectedInMedia
                        ? 'SOCIAL VERIFIED OK\\nHCV-ID rilevato nel video e fingerprint video compatibile. Certificato legacy precedente al fingerprint audio.'
                        : 'SOCIAL VERIFIED OK\\nHCV-ID inserito e fingerprint video compatibile. Certificato legacy precedente al fingerprint audio.'),
              'SOCIAL VERIFIED OK',
            );
"""
if branch_anchor in source:
    source = source.replace(branch_anchor, branch_replacement, 1)
elif 'fingerprint audio non corrisponde' not in source:
    raise RuntimeError('audio decision branch anchor not found')

required = [
    "import 'hcv_audio_fingerprint.dart';",
    'HCVAudioFingerprintClaimState',
    '_matchesCertifiedAudioFingerprint(',
    'audioFingerprintMatches = await',
    'fingerprint audio non corrisponde',
    'buildVisualFromVideo(mediaPath!)',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'missing BUILD113 audio token: {token}')

registry_path.write_text(source, encoding='utf-8')

TEST_FILE = r'''import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_audio_fingerprint.dart';
import 'package:sigillum_iphone/registry_verify_page.dart';

List<int> _baseSignal({bool different = false}) {
  const sampleRate = HCVAudioFingerprint.sampleRate;
  final samples = <int>[];
  for (var i = 0; i < sampleRate * 4; i++) {
    final t = i / sampleRate;
    final envelope = 0.65 +
        0.20 * sin(2 * pi * 1.7 * t) +
        0.10 * sin(2 * pi * 0.37 * t);
    final value = different
        ? envelope *
            (0.75 * sin(2 * pi * 440 * t) +
                0.35 * sin(2 * pi * 1200 * t) +
                0.20 * sin(2 * pi * 2800 * t))
        : envelope *
            (0.75 * sin(2 * pi * 220 * t) +
                0.45 * sin(2 * pi * 730 * t) +
                0.25 * sin(2 * pi * 1450 * t));
    samples.add((value * 12000).round().clamp(-32768, 32767));
  }
  return samples;
}

List<int> _recompressedLike(List<int> source) {
  const shift = 160; // 20 ms encoder delay-like offset at 8 kHz.
  final result = List<int>.filled(source.length, 0);
  for (var i = shift; i < result.length; i++) {
    final deterministicNoise = ((i * 31) % 47) - 23;
    result[i] = ((source[i - shift] * 0.62).round() + deterministicNoise)
        .clamp(-32768, 32767);
  }
  return result;
}

void main() {
  group('BUILD113 audio fingerprint', () {
    test('gain, quantization noise and small encoder delay remain compatible', () {
      final original = HCVAudioFingerprint.buildFromPcm16Samples(_baseSignal());
      final derived = HCVAudioFingerprint.buildFromPcm16Samples(
        _recompressedLike(_baseSignal()),
      );

      expect(HCVAudioFingerprint.isValidFingerprint(original), isTrue);
      expect(HCVAudioFingerprint.isValidFingerprint(derived), isTrue);
      expect(HCVAudioFingerprint.matches(original, derived), isTrue);
    });

    test('substantially different audio does not match', () {
      final original = HCVAudioFingerprint.buildFromPcm16Samples(_baseSignal());
      final other = HCVAudioFingerprint.buildFromPcm16Samples(
        _baseSignal(different: true),
      );

      expect(HCVAudioFingerprint.matches(original, other), isFalse);
    });

    test('malformed audio fingerprint fails closed', () {
      final valid = HCVAudioFingerprint.buildFromPcm16Samples(_baseSignal());
      final malformed = Map<String, dynamic>.from(valid)
        ..['frameHashes'] = <String>['abcd'];

      expect(HCVAudioFingerprint.isValidFingerprint(malformed), isFalse);
    });

    test('new audio policy requires a valid signed audio fingerprint', () {
      final fingerprint = HCVAudioFingerprint.buildFromPcm16Samples(
        _baseSignal(),
      );
      final claims = <String, dynamic>{
        'socialFingerprint': <String, dynamic>{
          'audioFingerprintPolicy': HCVAudioFingerprint.policy,
          'audioFingerprint': fingerprint,
        },
      };

      expect(resolveHCVAudioFingerprintAvailability(claims), isTrue);
      expect(
        resolveHCVAudioFingerprintClaimState(claims),
        HCVAudioFingerprintClaimState.usable,
      );
    });

    test('declared modern audio policy with missing fingerprint fails closed', () {
      final claims = <String, dynamic>{
        'socialFingerprint': <String, dynamic>{
          'audioFingerprintPolicy': HCVAudioFingerprint.policy,
        },
      };

      expect(resolveHCVAudioFingerprintAvailability(claims), isFalse);
      expect(
        resolveHCVAudioFingerprintClaimState(claims),
        HCVAudioFingerprintClaimState.modernInvalid,
      );
    });

    test('pre-audio-fingerprint certificate remains legacy compatible', () {
      final claims = <String, dynamic>{
        'socialFingerprint': <String, dynamic>{
          'algorithm': 'SIGILLUM_SOCIAL_AHASH_V1',
          'frameHashes': <String>[],
        },
      };

      expect(resolveHCVAudioFingerprintAvailability(claims), isNull);
      expect(
        resolveHCVAudioFingerprintClaimState(claims),
        HCVAudioFingerprintClaimState.legacyMissing,
      );
    });

    test('video social fingerprint signs audio policy and verifier separates axes', () {
      final socialSource = File('lib/hcv_social_fingerprint.dart').readAsStringSync();
      final registrySource = File('lib/registry_verify_page.dart').readAsStringSync();

      expect(socialSource, contains("'audioFingerprintPolicy': HCVAudioFingerprint.policy"));
      expect(socialSource, contains('HCVAudioFingerprint.buildFromVideo(videoPath)'));
      expect(socialSource, contains('buildVisualFromVideo'));
      expect(registrySource, contains('audioFingerprintMatches == false'));
      expect(registrySource, contains('fingerprint audio non corrisponde'));
      expect(registrySource, contains('buildVisualFromVideo(mediaPath!)'));
    });
  });
}
'''

Path('test/build113_audio_fingerprint_test.dart').write_text(TEST_FILE, encoding='utf-8')
print('BUILD113 audio fingerprint patch materialized')
