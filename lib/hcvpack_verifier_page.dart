import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_verifier.dart';

class HCVPackVerifierPage extends StatefulWidget {
  const HCVPackVerifierPage({
    super.key,
    this.initialPath,
  });

  final String? initialPath;

  @override
  State<HCVPackVerifierPage> createState() => _HCVPackVerifierPageState();
}

class _HCVPackVerifierPageState extends State<HCVPackVerifierPage> {
  final HCVVerifier _verifier = HCVVerifier();

  String status = 'Seleziona un file HCVPACK';
  String? result;
  String? packPath;
  String? extractedContentPath;
  String? hcvId;
  String? contentType;
  String? creatorName;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPath;
    if (initial != null && initial.isNotEmpty) {
      Future.microtask(() => _verifyPack(initial));
    }
  }

  Future<void> _pickPack() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['hcvpack'],
      withData: true,
    );
    if (picked == null) return;
    final item = picked.files.single;
    var path = item.path;
    if (path == null && item.bytes != null) {
      final dir = await getApplicationDocumentsDirectory();
      final target = File(p.join(dir.path, item.name));
      await target.writeAsBytes(item.bytes!, flush: true);
      path = target.path;
    }
    if (path == null) {
      setState(() {
        status = 'File HCVPACK non accessibile';
        result = 'ERROR';
      });
      return;
    }
    await _verifyPack(path);
  }

  Future<void> _verifyPack(String path) async {
    setState(() {
      loading = true;
      packPath = path;
      extractedContentPath = null;
      hcvId = null;
      contentType = null;
      creatorName = null;
      result = null;
      status = 'Verifica HCVPACK...';
    });

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw const FormatException('File HCVPACK non trovato');
      }
      final bytes = await file.readAsBytes();
      if (_isZip(bytes)) {
        await _verifyZip(bytes);
      } else {
        await _verifyLegacyJson(bytes);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        result = 'INVALID';
        status = 'HCVPACK non valido: $error';
      });
    }
  }

  bool _isZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  Future<void> _verifyZip(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final byName = <String, ArchiveFile>{
      for (final entry in archive.files) entry.name: entry,
    };
    final metaEntry = byName['meta.json'];
    final certificateEntry = byName['certificate.hcv'];
    if (metaEntry == null || certificateEntry == null) {
      throw const FormatException('meta.json o certificate.hcv mancante');
    }

    final meta = jsonDecode(
      utf8.decode(List<int>.from(metaEntry.content as List<int>)),
    );
    if (meta is! Map<String, dynamic> || meta['type'] != 'HCV_PACKAGE') {
      throw const FormatException('meta.json non valido');
    }

    final version = (meta['version'] as num?)?.toInt() ?? 0;
    late final String contentEntryName;
    if (version >= 3) {
      contentEntryName = meta['contentFile']?.toString() ?? '';
    } else if (version == 2) {
      contentEntryName = meta['videoFile']?.toString() ?? 'video.mp4';
    } else {
      throw FormatException('Versione HCVPACK non supportata: $version');
    }
    if (contentEntryName.isEmpty || byName[contentEntryName] == null) {
      throw const FormatException('Contenuto del pacchetto mancante');
    }

    final contentBytes =
        List<int>.from(byName[contentEntryName]!.content as List<int>);
    final certificateBytes =
        List<int>.from(certificateEntry.content as List<int>);
    final actualContentDigest = sha256.convert(contentBytes).toString();
    final actualCertificateDigest = sha256.convert(certificateBytes).toString();
    final expectedContentDigest = version >= 3
        ? meta['contentSha256']?.toString()
        : meta['videoSha256']?.toString();
    final expectedCertificateDigest = meta['certificateSha256']?.toString();
    if (expectedContentDigest != actualContentDigest ||
        expectedCertificateDigest != actualCertificateDigest) {
      throw const FormatException('Digest HCVPACK non corrispondenti');
    }

    final createdAt = meta['createdAt']?.toString() ?? '';
    final expectedPackageId = sha256
        .convert(utf8.encode(
          '$actualContentDigest|$actualCertificateDigest|$createdAt',
        ))
        .toString();
    if (meta['packageId']?.toString() != expectedPackageId) {
      throw const FormatException('Package ID non valido');
    }

    await _verifyCertificateAndContent(
      certificateBytes: certificateBytes,
      contentBytes: contentBytes,
      contentName: p.basename(contentEntryName),
      packageVersion: version,
    );
  }

  Future<void> _verifyLegacyJson(List<int> bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('HCVPACK JSON legacy non valido');
    }
    final encodedContent = decoded['video'];
    final certificate = decoded['certificate'];
    if (encodedContent is! String || certificate is! Map) {
      throw const FormatException('HCVPACK JSON legacy incompleto');
    }
    await _verifyCertificateAndContent(
      certificateBytes: utf8.encode(jsonEncode(certificate)),
      contentBytes: base64Decode(encodedContent),
      contentName: 'video.mp4',
      packageVersion: 1,
    );
  }

  Future<void> _verifyCertificateAndContent({
    required List<int> certificateBytes,
    required List<int> contentBytes,
    required String contentName,
    required int packageVersion,
  }) async {
    final certificate = jsonDecode(utf8.decode(certificateBytes));
    if (certificate is! Map<String, dynamic>) {
      throw const FormatException('Certificato HCV non valido');
    }
    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempDir.path,
        'hcvpack_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await workDir.create(recursive: true);
    final certFile = File(p.join(workDir.path, 'certificate.hcv'));
    await certFile.writeAsBytes(certificateBytes, flush: true);
    if (!await _verifier.verifyFile(certFile.path)) {
      throw const FormatException('Firma del certificato non valida');
    }

    final content = certificate['content'];
    if (content is! Map) {
      throw const FormatException('Content binding mancante');
    }
    final expectedHash = content['hash']?.toString() ?? '';
    final actualHash = sha256.convert(contentBytes).toString();
    if (expectedHash.isEmpty || expectedHash != actualHash) {
      throw const FormatException('Il contenuto non corrisponde al certificato');
    }

    final extension = p.extension(contentName).isEmpty
        ? _extensionForType(content['type']?.toString() ?? '')
        : p.extension(contentName);
    final safeName = p.basenameWithoutExtension(contentName).replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        );
    final extracted = File(
      p.join(workDir.path, '$safeName$extension'),
    );
    await extracted.writeAsBytes(contentBytes, flush: true);

    final meta = certificate['meta'];
    final identity = meta is Map ? meta['identity'] : null;
    if (!mounted) return;
    setState(() {
      loading = false;
      result = 'VALID';
      status = 'HCVPACK v$packageVersion verificato offline';
      extractedContentPath = extracted.path;
      hcvId = meta is Map ? meta['hcvId']?.toString() : null;
      contentType = content['type']?.toString();
      creatorName = identity is Map ? identity['creatorName']?.toString() : null;
    });
  }

  String _extensionForType(String type) {
    switch (type) {
      case 'photo':
        return '.jpg';
      case 'video':
        return '.mp4';
      case 'audio':
        return '.m4a';
      case 'text':
        return '.txt';
      case 'document':
        return '.pdf';
      default:
        return '.bin';
    }
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SelectableText('$label: $value', textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = result == 'VALID';
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica HCVPACK')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                valid ? Icons.verified : Icons.inventory_2_outlined,
                size: 72,
                color: valid ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 18),
              SelectableText(status, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: loading ? null : _pickPack,
                child: const Text('SELEZIONA HCVPACK'),
              ),
              if (loading) ...[
                const SizedBox(height: 18),
                const CircularProgressIndicator(),
              ],
              _row('Esito', result),
              _row('HCV-ID', hcvId),
              _row('Creatore', creatorName),
              _row('Tipo contenuto', contentType),
              _row('Pacchetto', packPath),
              _row('Contenuto estratto', extractedContentPath),
            ],
          ),
        ),
      ),
    );
  }
}
