import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

      hashes.add(_averageHash(decoded));
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

    const seconds = [0.5, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0];

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
            p.join(workDir.path, 'frame_${i.toString().padLeft(3, '0')}.jpg'));
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
