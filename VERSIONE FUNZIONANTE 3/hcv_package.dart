import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class HCVPackage {
  Future<String> createPackage({
    required String videoPath,
    required String hcvPath,
  }) async {
    final videoFile = File(videoPath);
    final hcvFile = File(hcvPath);

    if (!await videoFile.exists()) {
      throw Exception("Video non trovato: $videoPath");
    }

    if (!await hcvFile.exists()) {
      throw Exception("Certificato HCV non trovato: $hcvPath");
    }

    final videoBytes = await videoFile.readAsBytes();
    final hcvBytes = await hcvFile.readAsBytes();

    final videoSha256 = sha256.convert(videoBytes).toString();
    final certificateSha256 = sha256.convert(hcvBytes).toString();

    final createdAt = DateTime.now().toIso8601String();

    final packageIdSource = "$videoSha256|$certificateSha256|$createdAt";
    final packageId = sha256.convert(utf8.encode(packageIdSource)).toString();

    final meta = {
      "type": "HCV_PACKAGE",
      "version": 2,
      "packageId": packageId,
      "createdAt": createdAt,
      "videoFile": "video.mp4",
      "certificateFile": "certificate.hcv",
      "originalVideoName": p.basename(videoPath),
      "originalCertificateName": p.basename(hcvPath),
      "videoSha256": videoSha256,
      "certificateSha256": certificateSha256,
      "hashAlgorithm": "SHA256",
      "certificateFormat": "HCV",
    };

    final archive = Archive();

    archive.addFile(
      ArchiveFile(
        "video.mp4",
        videoBytes.length,
        videoBytes,
      ),
    );

    archive.addFile(
      ArchiveFile(
        "certificate.hcv",
        hcvBytes.length,
        hcvBytes,
      ),
    );

    final metaBytes = utf8.encode(
      const JsonEncoder.withIndent("  ").convert(meta),
    );

    archive.addFile(
      ArchiveFile(
        "meta.json",
        metaBytes.length,
        metaBytes,
      ),
    );

    final zipBytes = ZipEncoder().encode(archive);

    if (zipBytes == null) {
      throw Exception("Errore creazione ZIP HCVPACK");
    }

    final outputDir = await _getOutputDirectory();

    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final outputPath = p.join(
      outputDir.path,
      "package_${DateTime.now().millisecondsSinceEpoch}.hcvpack",
    );

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(zipBytes);

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