import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVTextIntegritySnapshot {
  const HCVTextIntegritySnapshot({
    required this.exactTextSha256,
    required this.socialCanonicalSha256,
    required this.utf8ByteLength,
    required this.characterLength,
  });

  final String exactTextSha256;
  final String socialCanonicalSha256;
  final int utf8ByteLength;
  final int characterLength;

  Map<String, dynamic> toJson() => {
        'type': 'SIGILLUM_TEXT_INTEGRITY_V1',
        'exactTextSha256': exactTextSha256,
        'socialCanonicalSha256': socialCanonicalSha256,
        'utf8ByteLength': utf8ByteLength,
        'characterLength': characterLength,
        'normalization': 'WHITESPACE_ONLY_V1',
        'hashAlgorithm': 'SHA256',
      };
}

enum HCVTextMatchKind {
  exact,
  formattingOnly,
  modified,
  unsupportedCertificate,
}

class HCVTextMatchResult {
  const HCVTextMatchResult({
    required this.kind,
    required this.hcvId,
    required this.exactHash,
    required this.socialCanonicalHash,
    this.expectedExactHash,
    this.expectedSocialCanonicalHash,
  });

  final HCVTextMatchKind kind;
  final String? hcvId;
  final String exactHash;
  final String socialCanonicalHash;
  final String? expectedExactHash;
  final String? expectedSocialCanonicalHash;

  bool get verified =>
      kind == HCVTextMatchKind.exact ||
      kind == HCVTextMatchKind.formattingOnly;
}

class HCVTextIntegrity {
  HCVTextIntegrity._();

  static final RegExp hcvIdPattern =
      RegExp(r'HCV-[A-F0-9]{16}(?![A-F0-9])', caseSensitive: false);

  static String normalizeOriginal(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }

  static String socialCanonical(String text) {
    return normalizeOriginal(text)
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String exactSha256(String text) {
    return sha256.convert(utf8.encode(normalizeOriginal(text))).toString();
  }

  static String socialCanonicalSha256(String text) {
    return sha256.convert(utf8.encode(socialCanonical(text))).toString();
  }

  static HCVTextIntegritySnapshot fromText(String text) {
    final original = normalizeOriginal(text);
    final bytes = utf8.encode(original);
    return HCVTextIntegritySnapshot(
      exactTextSha256: sha256.convert(bytes).toString(),
      socialCanonicalSha256:
          sha256.convert(utf8.encode(socialCanonical(original))).toString(),
      utf8ByteLength: bytes.length,
      characterLength: original.runes.length,
    );
  }

  static String buildSocialText(String text, String hcvId) {
    final original = normalizeOriginal(text);
    final cleanedId = extractHcvId(hcvId) ?? hcvId.trim().toUpperCase();
    return '$original\n\n🔏 SIGILLUM $cleanedId';
  }

  static String? extractHcvId(String text) {
    return hcvIdPattern.firstMatch(text)?.group(0)?.toUpperCase();
  }

  static String stripSigillumMarker(String text) {
    var value = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final compactMarker = RegExp(
      r'(?:\n\s*)?(?:🔏\s*)?SIGILLUM\s+HCV-[A-F0-9]{16}\s*$',
      caseSensitive: false,
    );
    value = value.replaceFirst(compactMarker, '');

    final legacyMarker = RegExp(
      r'(?:\n\s*)?HCV\s+VERIFIED(?:\s*✔)?\s*\n\s*ID:\s*HCV-[A-F0-9]{16}(?:\s*\n\s*Verify\s+with\s+(?:HCV\s+App|SIGILLUM))?\s*$',
      caseSensitive: false,
    );
    value = value.replaceFirst(legacyMarker, '');

    return normalizeOriginal(value);
  }

  static HCVTextMatchResult comparePublishedText({
    required String publishedText,
    required Map<String, dynamic> certificate,
  }) {
    final textWithoutMarker = stripSigillumMarker(publishedText);
    final exactHash = exactSha256(textWithoutMarker);
    final canonicalHash = socialCanonicalSha256(textWithoutMarker);

    final meta = certificate['meta'];
    final hcvId = meta is Map ? extractHcvId(meta['hcvId']?.toString() ?? '') : null;

    final content = certificate['content'];
    final contentHash = content is Map ? content['hash']?.toString() : null;
    final claims = certificate['claims'];
    final integrity = claims is Map ? claims['textIntegrity'] : null;

    final expectedExact = integrity is Map
        ? integrity['exactTextSha256']?.toString()
        : contentHash;
    final expectedCanonical = integrity is Map
        ? integrity['socialCanonicalSha256']?.toString()
        : null;

    if (expectedExact == null || expectedExact.isEmpty) {
      return HCVTextMatchResult(
        kind: HCVTextMatchKind.unsupportedCertificate,
        hcvId: hcvId,
        exactHash: exactHash,
        socialCanonicalHash: canonicalHash,
      );
    }

    if (exactHash == expectedExact) {
      return HCVTextMatchResult(
        kind: HCVTextMatchKind.exact,
        hcvId: hcvId,
        exactHash: exactHash,
        socialCanonicalHash: canonicalHash,
        expectedExactHash: expectedExact,
        expectedSocialCanonicalHash: expectedCanonical,
      );
    }

    if (expectedCanonical != null &&
        expectedCanonical.isNotEmpty &&
        canonicalHash == expectedCanonical) {
      return HCVTextMatchResult(
        kind: HCVTextMatchKind.formattingOnly,
        hcvId: hcvId,
        exactHash: exactHash,
        socialCanonicalHash: canonicalHash,
        expectedExactHash: expectedExact,
        expectedSocialCanonicalHash: expectedCanonical,
      );
    }

    return HCVTextMatchResult(
      kind: HCVTextMatchKind.modified,
      hcvId: hcvId,
      exactHash: exactHash,
      socialCanonicalHash: canonicalHash,
      expectedExactHash: expectedExact,
      expectedSocialCanonicalHash: expectedCanonical,
    );
  }
}

class HCVTextArtifactStore {
  HCVTextArtifactStore._();

  static Future<Directory> outputDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (!await downloads.exists()) {
        await downloads.create(recursive: true);
      }
      return downloads;
    }

    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Sigillum', 'TextCertificates'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

class HCVTextPackage {
  HCVTextPackage._();

  static Future<String> create({
    required String textPath,
    required String hcvPath,
    required String hcvId,
    Directory? outputDirectory,
  }) async {
    final textFile = File(textPath);
    final certificateFile = File(hcvPath);
    if (!await textFile.exists()) {
      throw Exception('Testo originale non trovato: $textPath');
    }
    if (!await certificateFile.exists()) {
      throw Exception('Certificato HCV non trovato: $hcvPath');
    }

    final textBytes = await textFile.readAsBytes();
    final certificateBytes = await certificateFile.readAsBytes();
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final meta = <String, dynamic>{
      'type': 'HCV_TEXT_PACKAGE',
      'version': 1,
      'hcvId': safeId,
      'createdAt': createdAt,
      'contentFile': 'original.txt',
      'certificateFile': 'certificate.hcv',
      'originalTextName': p.basename(textPath),
      'originalCertificateName': p.basename(hcvPath),
      'textSha256': sha256.convert(textBytes).toString(),
      'certificateSha256': sha256.convert(certificateBytes).toString(),
      'hashAlgorithm': 'SHA256',
    };

    final archive = Archive()
      ..addFile(ArchiveFile('original.txt', textBytes.length, textBytes))
      ..addFile(
        ArchiveFile(
          'certificate.hcv',
          certificateBytes.length,
          certificateBytes,
        ),
      );
    final metaBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(meta));
    archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('Errore creazione HCVPACK testo');
    }

    final directory = outputDirectory ?? await HCVTextArtifactStore.outputDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final output = File(p.join(directory.path, 'hcv_text_$safeId.hcvpack'));
    if (await output.exists()) {
      await output.delete();
    }
    await output.writeAsBytes(encoded, flush: true);
    return output.path;
  }

  static Future<HCVTextPackageContents> read(String packagePath) async {
    final packageFile = File(packagePath);
    if (!await packageFile.exists()) {
      throw Exception('HCVPACK non trovato: $packagePath');
    }

    final archive = ZipDecoder().decodeBytes(await packageFile.readAsBytes());
    ArchiveFile? textEntry;
    ArchiveFile? certificateEntry;
    ArchiveFile? metaEntry;
    for (final entry in archive.files) {
      final name = entry.name.replaceAll('\\', '/').split('/').last.toLowerCase();
      if (!entry.isFile) continue;
      if (name == 'original.txt') textEntry = entry;
      if (name == 'certificate.hcv') certificateEntry = entry;
      if (name == 'meta.json') metaEntry = entry;
    }

    if (textEntry == null || certificateEntry == null) {
      throw Exception('HCVPACK testo incompleto');
    }

    final textBytes = List<int>.from(textEntry.content as List);
    final certificateBytes = List<int>.from(certificateEntry.content as List);
    Map<String, dynamic>? meta;
    if (metaEntry != null) {
      try {
        final decoded = jsonDecode(utf8.decode(List<int>.from(metaEntry.content as List)));
        if (decoded is Map<String, dynamic>) meta = decoded;
      } catch (_) {}
    }

    if (meta != null) {
      final expectedTextHash = meta['textSha256']?.toString();
      final expectedCertificateHash = meta['certificateSha256']?.toString();
      if (expectedTextHash != null &&
          sha256.convert(textBytes).toString() != expectedTextHash) {
        throw Exception('Testo HCVPACK alterato');
      }
      if (expectedCertificateHash != null &&
          sha256.convert(certificateBytes).toString() != expectedCertificateHash) {
        throw Exception('Certificato HCVPACK alterato');
      }
    }

    return HCVTextPackageContents(
      originalText: utf8.decode(textBytes),
      certificateRaw: utf8.decode(certificateBytes),
      meta: meta,
    );
  }
}

class HCVTextPackageContents {
  const HCVTextPackageContents({
    required this.originalText,
    required this.certificateRaw,
    this.meta,
  });

  final String originalText;
  final String certificateRaw;
  final Map<String, dynamic>? meta;
}
