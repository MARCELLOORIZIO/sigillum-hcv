import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_secure_media_vault.dart';

class HCVSecurePreviewService {
  const HCVSecurePreviewService({
    this.vault = const HCVSecureMediaVault(),
  });

  final HCVSecureMediaVault vault;

  Future<Directory> _previewDirectory() async {
    final tempRoot = await getTemporaryDirectory();
    final dir = Directory(p.join(tempRoot.path, 'sigillum_secure_previews'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File?> thumbnail(HCVSecureOriginalRecord record) async {
    final dir = await _previewDirectory();
    final target = File(
      p.join(
        dir.path,
        '${record.hcvId}_${record.mediaSha256.substring(0, 12)}.jpg',
      ),
    );
    if (await target.exists() && await target.length() > 0) {
      return target;
    }

    File? clear;
    try {
      clear = await vault.materializeOriginal(record, purpose: 'preview');
      if (record.mediaType == 'video') {
        final ok = await _videoThumbnail(clear, target);
        return ok ? target : null;
      }
      return await _photoThumbnail(clear, target);
    } finally {
      if (clear != null) await vault.deleteMaterialized(clear);
    }
  }

  Future<File?> _photoThumbnail(File source, File target) async {
    final decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) return null;
    final resized = decoded.width > 560
        ? img.copyResize(decoded, width: 560)
        : decoded;
    await target.writeAsBytes(
      img.encodeJpg(resized, quality: 78),
      flush: true,
    );
    return await target.exists() && await target.length() > 0 ? target : null;
  }

  Future<bool> _videoThumbnail(File source, File target) async {
    if (await target.exists()) await target.delete();
    final command =
        "-hide_banner -loglevel error -y -ss 0.2 -i '${_escapePath(source.path)}' "
        "-frames:v 1 -vf scale=480:-2 -q:v 4 '${_escapePath(target.path)}'";
    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();
    return code != null &&
        ReturnCode.isSuccess(code) &&
        await target.exists() &&
        await target.length() > 0;
  }

  String _escapePath(String value) => value.replaceAll("'", r"'\''");

  Future<void> clearCache() async {
    try {
      final tempRoot = await getTemporaryDirectory();
      final dir = Directory(p.join(tempRoot.path, 'sigillum_secure_previews'));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
