import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'hcv_import_router_page.dart';
import 'sigillum_localization.dart';

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
  String status = "";
  String? selectedPath;

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);

  @override
  void initState() {
    super.initState();
    status = _t('selectFileToVerify');
  }

  Future<void> _openPickedPath(String path) async {
    if (!mounted) return;
    setState(() {
      selectedPath = path;
      status = "${_t('fileSelected')}:\n$path";
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HCVImportRouterPage(
          path: path,
          languageCode: widget.languageCode,
        ),
      ),
    );
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

    return lower.endsWith(".hcvpack") ||
        lower.endsWith(".hcv") ||
        lower.endsWith(".txt") ||
        lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".pdf") ||
        lower.endsWith(".mp4") ||
        lower.endsWith(".mov") ||
        lower.endsWith(".m4v");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('verifyContentHeading')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.file_open,
                size: 72,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                _t('verifyContentHeading'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t('supportedFiles'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 30),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: pickDocument,
                icon: const Icon(Icons.description_outlined),
                label: Text(widget.languageCode == 'it'
                    ? 'VERIFICA TESTO / DOCUMENTO'
                    : 'VERIFY TEXT / DOCUMENT'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: pickPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(widget.languageCode == 'it'
                    ? 'VERIFICA FOTO'
                    : 'VERIFY PHOTO'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: pickVideo,
                icon: const Icon(Icons.video_library_outlined),
                label: Text(widget.languageCode == 'it'
                    ? 'VERIFICA VIDEO'
                    : 'VERIFY VIDEO'),
              ),
              if (selectedPath != null) ...[
                const SizedBox(height: 20),
                Text(
                  selectedPath!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
