import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVSocialFingerprint {
  Future<Map<String, dynamic>> buildFromVideo(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      throw Exception('Video non trovato: $videoPath');
    }

    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
          tempDir.path, 'hcv_social_${DateTime.now().millisecondsSinceEpoch}'),
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

    final frames = workDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList()
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
