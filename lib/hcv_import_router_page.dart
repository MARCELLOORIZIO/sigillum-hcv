import 'dart:io';

import 'package:flutter/material.dart';

import 'hcv_file_provenance_gate_page.dart';
import 'hcvpack_provenance_gate_page.dart';
import 'quick_hcv_media_gate_page.dart';
import 'registry_verify_page.dart';
import 'sigillum_localization.dart';
import 'verification_ui_copy.dart';

class HCVImportRouterPage extends StatefulWidget {
  final String path;
  final String languageCode;

  const HCVImportRouterPage({
    super.key,
    required this.path,
    this.languageCode = 'it',
  });

  @override
  State<HCVImportRouterPage> createState() => _HCVImportRouterPageState();
}

class _HCVImportRouterPageState extends State<HCVImportRouterPage> {
  String status = "";

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);

  @override
  void initState() {
    super.initState();
    status = _t('analyzingFile');
    Future.microtask(processFile);
  }

  Future<void> processFile() async {
    var path = widget.path;

    if (!await File(path).exists()) {
      setState(() {
        status = "${_t('fileNotFound')}:\n$path";
      });
      return;
    }

    path = await _normalizeExtensionlessMedia(path);
    final lower = path.toLowerCase();

    if (lower.endsWith(".hcvpack")) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HCVPackProvenanceGatePage(
            path: path,
            languageCode: widget.languageCode,
          ),
        ),
      );
      return;
    }

    if (lower.endsWith(".hcv")) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HCVFileProvenanceGatePage(
            path: path,
            languageCode: widget.languageCode,
          ),
        ),
      );
      return;
    }

    if (_isPhotoOrVideo(lower)) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuickHcvMediaGatePage(
            path: path,
            languageCode: widget.languageCode,
          ),
        ),
      );
      return;
    }

    if (_isOtherMediaOrTextFile(lower)) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegistryVerifyPage(
            initialMediaPath: path,
            languageCode: widget.languageCode,
          ),
        ),
      );
      return;
    }

    setState(() {
      status = "${_t('unknownFormat')}:\n$path";
    });
  }

  Future<String> _normalizeExtensionlessMedia(String path) async {
    final lower = path.toLowerCase();
    if (_isPhotoOrVideo(lower) || _isOtherMediaOrTextFile(lower)) {
      return path;
    }

    String? extension;
    RandomAccessFile? handle;
    try {
      handle = await File(path).open();
      final bytes = await handle.read(16);

      final isJpeg = bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      final isPng = bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a;
      final isIsoBaseMedia = bytes.length >= 12 &&
          bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70;

      if (isJpeg) {
        extension = '.jpg';
      } else if (isPng) {
        extension = '.png';
      } else if (isIsoBaseMedia) {
        extension = '.mp4';
      }
    } catch (_) {
      return path;
    } finally {
      await handle?.close();
    }

    if (extension == null) return path;

    final normalized = File('$path$extension');
    if (!await normalized.exists()) {
      await File(path).copy(normalized.path);
    }
    return normalized.path;
  }

  bool _isPhotoOrVideo(String lower) {
    return lower.endsWith(".mp4") ||
        lower.endsWith(".mov") ||
        lower.endsWith(".m4v") ||
        lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png");
  }

  bool _isOtherMediaOrTextFile(String lower) {
    return lower.endsWith(".txt") ||
        lower.endsWith(".pdf") ||
        lower.endsWith(".mp3") ||
        lower.endsWith(".wav");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_v('routerTitle'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(status, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
