import 'dart:convert';
import 'dart:io';
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

    final legacy = _averageHash(
      img.copyResize(
        decoded,
        width: 16,
        height: 16,
        interpolation: img.Interpolation.average,
      ),
    );
    final spatial = _spatialDescriptor(decoded);

    return <String, dynamic>{
      'algorithm': 'SIGILLUM_SOCIAL_IMAGE_SPATIAL_V2',
      'legacyAlgorithm': 'SIGILLUM_SOCIAL_IMAGE_AHASH_V1',
      'imageHash': legacy,
      ...spatial,
      'combinedHash': sha256
          .convert(
            utf8.encode(
              <String>[
                legacy,
                ...List<String>.from(spatial['tileHashes'] as List),
                jsonEncode(spatial['tone']),
              ].join('|'),
            ),
          )
          .toString(),
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

    final legacyHashes = <String>[];
    final frameDescriptors = <Map<String, dynamic>>[];

    for (final frame in frames) {
      final bytes = await frame.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      final normalized = _normalizeVideoFrame(decoded);
      final legacyHash = _averageHash(normalized);
      legacyHashes.add(legacyHash);
      frameDescriptors.add(<String, dynamic>{
        'legacyHash': legacyHash,
        ..._spatialDescriptor(decoded),
      });
    }

    try {
      await workDir.delete(recursive: true);
    } catch (_) {}

    final combined = <String>[
      ...legacyHashes,
      ...frameDescriptors.map(jsonEncode),
    ].join('|');

    return <String, dynamic>{
      'algorithm': 'SIGILLUM_SOCIAL_VIDEO_SPATIAL_V2',
      'legacyAlgorithm': 'SIGILLUM_SOCIAL_AHASH_V1',
      'frameCount': legacyHashes.length,
      'frameHashes': legacyHashes,
      'frameDescriptors': frameDescriptors,
      'combinedHash': sha256.convert(utf8.encode(combined)).toString(),
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

  Map<String, dynamic> _spatialDescriptor(img.Image source) {
    const rows = 4;
    const cols = 4;
    final tileHashes = <String>[];

    for (var row = 0; row < rows; row++) {
      final y0 = (source.height * row / rows).floor();
      final y1 = (source.height * (row + 1) / rows).floor();
      for (var col = 0; col < cols; col++) {
        final x0 = (source.width * col / cols).floor();
        final x1 = (source.width * (col + 1) / cols).floor();
        final crop = img.copyCrop(
          source,
          x: x0,
          y: y0,
          width: max(1, x1 - x0),
          height: max(1, y1 - y0),
        );
        tileHashes.add(
          _averageHash(
            img.copyResize(
              crop,
              width: 16,
              height: 16,
              interpolation: img.Interpolation.average,
            ),
          ),
        );
      }
    }

    return <String, dynamic>{
      'spatialPolicy': 'SIGILLUM_SPATIAL_4X4_TONE_V1',
      'tileRows': rows,
      'tileCols': cols,
      'tileHashes': tileHashes,
      'tone': _toneDescriptor(source),
    };
  }

  Map<String, dynamic> _toneDescriptor(img.Image source) {
    final sampleWidth = min(160, source.width);
    final sampleHeight = max(
      1,
      (source.height * sampleWidth / max(source.width, 1)).round(),
    );
    final sampled = img.copyResize(
      source,
      width: sampleWidth,
      height: sampleHeight,
      interpolation: img.Interpolation.average,
    );

    var count = 0;
    var sumLuma = 0.0;
    var sumLumaSq = 0.0;
    var sumChroma = 0.0;
    var sumRG = 0.0;
    var sumBG = 0.0;

    for (var y = 0; y < sampled.height; y++) {
      for (var x = 0; x < sampled.width; x++) {
        final pixel = sampled.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final luma = img.getLuminance(pixel).toDouble();
        final maxC = max(r, max(g, b));
        final minC = min(r, min(g, b));
        count++;
        sumLuma += luma;
        sumLumaSq += luma * luma;
        sumChroma += maxC - minC;
        sumRG += r - g;
        sumBG += b - g;
      }
    }

    if (count == 0) {
      return const <String, dynamic>{
        'meanLuma': 0,
        'stdLuma': 0,
        'meanChroma': 0,
        'meanRMinusG': 0,
        'meanBMinusG': 0,
      };
    }

    final meanLuma = sumLuma / count;
    final variance = max(0.0, (sumLumaSq / count) - meanLuma * meanLuma);
    double q(double value) => (value * 10).roundToDouble() / 10.0;

    return <String, dynamic>{
      'meanLuma': q(meanLuma),
      'stdLuma': q(sqrt(variance)),
      'meanChroma': q(sumChroma / count),
      'meanRMinusG': q(sumRG / count),
      'meanBMinusG': q(sumBG / count),
    };
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
