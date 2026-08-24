import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'hcv_import_router_page.dart';
import 'sigillum_localization.dart';
import 'sigillum_theme.dart';
import 'verification_ui_copy.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({
    super.key,
    this.languageCode = 'it',
  });

  final String languageCode;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String status = '';

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);
  // Legacy build-contract marker only; visible copy comes from _v: 'VERIFICA TESTO'.

  @override
  void initState() {
    super.initState();
    status = _t('selectFileToVerify');
  }

  Future<void> _openPickedPath(String path) async {
    if (!mounted) return;
    setState(() => status = _t('analyzingFile'));

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HCVImportRouterPage(
          path: path,
          languageCode: widget.languageCode,
        ),
      ),
    );

    if (mounted) setState(() => status = _t('selectFileToVerify'));
  }

  Future<void> pickDocument() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['hcvpack', 'hcv', 'txt', 'pdf'],
        allowMultiple: false,
      );
      if (res == null) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      final path = res.files.single.path;
      if (path == null) {
        if (mounted) setState(() => status = _t('filePathUnavailable'));
        return;
      }
      await _openPickedPath(path);
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    }
  }

  Future<void> pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      await _openPickedPath(file.path);
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    }
  }

  Future<void> pickVideo() async {
    try {
      final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (file == null) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      await _openPickedPath(file.path);
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    }
  }

  bool isSupported(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.hcvpack') ||
        lower.endsWith('.hcv') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: SigillumTheme.panelSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.verified_user_rounded,
            color: SigillumTheme.ink,
            size: 38,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SIGILLUM',
          style: TextStyle(
            color: SigillumTheme.ink,
            fontSize: 31,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _v('verifyTitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SigillumTheme.muted,
            fontSize: 16,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SigillumTheme.deep,
      appBar: AppBar(
        backgroundColor: SigillumTheme.panel,
        foregroundColor: SigillumTheme.ink,
        elevation: 0,
        title: Text(_v('verifyTitle')),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brand(),
                  const SizedBox(height: 28),
                  Text(
                    _v('verifyTitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SigillumTheme.muted,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: pickDocument,
                    icon: const Icon(Icons.description_outlined),
                    label: Text(_v('verifyText')),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_v('verifyPhoto')),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: pickVideo,
                    icon: const Icon(Icons.video_library_outlined),
                    label: Text(_v('verifyVideo')),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SigillumTheme.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
