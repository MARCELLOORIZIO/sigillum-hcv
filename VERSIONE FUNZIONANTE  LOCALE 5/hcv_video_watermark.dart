import 'dart:io';

import 'package:path/path.dart' as p;

/// Versione stabile senza FFmpeg.
///
/// Per ora non modifica i pixel del video: crea una COPIA pubblicabile con
/// nome HCV e certifica quella copia. In questo modo l'hash del certificato
/// corrisponde al file che viene condiviso/pubblicato.
///
/// Il watermark visivo/QR lo aggiungeremo dopo con una soluzione nativa stabile.
class HCVVideoWatermark {
  Future<String> createPublishedVideo({
    required String inputPath,
    required String hcvId,
    String? verificationUrl,
  }) async {
    final inputFile = File(inputPath);

    if (!await inputFile.exists()) {
      throw Exception("Video non trovato: $inputPath");
    }

    final ext = p.extension(inputPath).toLowerCase();

    // Se non è un video reale, lo lasciamo com'è. Serve per il TEST emulator.
    if (ext != ".mp4" && ext != ".mov" && ext != ".m4v") {
      return inputPath;
    }

    final outputDir = await _getOutputDirectory();
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final baseName = p.basenameWithoutExtension(inputPath)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

    final outputPath = p.join(
      outputDir.path,
      "${baseName}_HCV_$hcvId$ext",
    );

    final outputFile = File(outputPath);

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    await inputFile.copy(outputPath);

    return outputPath;
  }

  Future<Directory> _getOutputDirectory() async {
    if (Platform.isAndroid) {
      return Directory("/storage/emulated/0/Download");
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment["USERPROFILE"];
      if (userProfile != null && userProfile.isNotEmpty) {
        return Directory(p.join(userProfile, "Documents"));
      }
    }

    return Directory.systemTemp;
  }
}
