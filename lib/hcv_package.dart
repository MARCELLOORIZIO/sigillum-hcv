import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVPackage {
  Future<String> createPackage({
    required String videoPath,
    required String hcvPath,
  }) {
    return createContentPackage(
      contentPath: videoPath,
      hcvPath: hcvPath,
    );
  }

  Future<String> createContentPackage({
    required String contentPath,
    required String hcvPath,
  }) async {
    final contentFile = File(contentPath);
    final hcvFile = File(hcvPath);
    if (!await contentFile.exists()) {
      throw Exception('Contenuto non trovato: $contentPath');
    }
    if (!await hcvFile.exists()) {
      throw Exception('Certificato HCV non trovato: $hcvPath');
    }

    final contentBytes = await contentFile.readAsBytes();
    final hcvBytes = await hcvFile.readAsBytes();
    final certificate = jsonDecode(utf8.decode(hcvBytes));
    if (certificate is! Map<String, dynamic>) {
      throw const FormatException('Certificato HCV non valido');
    }
    final contentType = certificate['content'] is Map
        ? (certificate['content']['type']?.toString() ?? 'binary')
        : 'binary';
    final hcvId = certificate['meta'] is Map
        ? certificate['meta']['hcvId']?.toString() ?? ''
        : '';
    final originalName = p.basename(contentPath);
    final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final archiveContentPath = 'content/$safeName';

    final contentSha256 = sha256.convert(contentBytes).toString();
    final certificateSha256 = sha256.convert(hcvBytes).toString();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final packageId = sha256
        .convert(utf8.encode('$contentSha256|$certificateSha256|$createdAt'))
        .toString();

    final isVideo = contentType == 'video';
    final meta = <String, dynamic>{
      'type': 'HCV_PACKAGE',
      'version': 3,
      'packageId': packageId,
      'createdAt': createdAt,
      'hcvId': hcvId,
      'contentType': contentType,
      'contentFile': archiveContentPath,
      'certificateFile': 'certificate.hcv',
      'originalContentName': originalName,
      'originalCertificateName': p.basename(hcvPath),
      'contentSha256': contentSha256,
      'certificateSha256': certificateSha256,
      'hashAlgorithm': 'SHA256',
      'certificateFormat': 'HCV',
      if (isVideo) 'legacyCompatibilityFile': 'video.mp4',
    };

    final archive = Archive()
      ..addFile(ArchiveFile(
        archiveContentPath,
        contentBytes.length,
        contentBytes,
      ))
      ..addFile(ArchiveFile(
        'certificate.hcv',
        hcvBytes.length,
        hcvBytes,
      ));

    if (isVideo && archiveContentPath != 'video.mp4') {
      archive.addFile(ArchiveFile(
        'video.mp4',
        contentBytes.length,
        contentBytes,
      ));
    }

    final metaBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(meta),
    );
    archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception('Errore creazione HCVPACK');

    final outputDir = await _getOutputDirectory();
    if (!await outputDir.exists()) await outputDir.create(recursive: true);
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final outputPath = p.join(
      outputDir.path,
      safeId.isEmpty
          ? 'package_${DateTime.now().millisecondsSinceEpoch}.hcvpack'
          : 'hcvpack_$safeId.hcvpack',
    );
    await File(outputPath).writeAsBytes(zipBytes, flush: true);
    return outputPath;
  }

  Future<Directory> _getOutputDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    }
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return Directory(p.join(userProfile, 'Documents'));
      }
    }
    return getApplicationDocumentsDirectory();
  }
}
