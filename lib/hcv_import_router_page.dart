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
    final path = widget.path;
    final lower = path.toLowerCase();

    if (!await File(path).exists()) {
      setState(() {
        status = "${_t('fileNotFound')}:\n$path";
      });
      return;
    }

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
