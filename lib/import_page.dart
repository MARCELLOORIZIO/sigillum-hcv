import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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

  Future<void> pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (res == null) {
        setState(() {
          status = _t('noFileSelected');
        });
        return;
      }

      final path = res.files.single.path;

      if (path == null) {
        setState(() {
          status = _t('filePathUnavailable');
        });
        return;
      }

      setState(() {
        selectedPath = path;
        status = "${_t('fileSelected')}:\n$path";
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HCVImportRouterPage(
            path: path,
            languageCode: widget.languageCode,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        status = "${_t('importError')}: $e";
      });
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t('supportedFiles'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 30),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: pickFile,
                child: Text(_t('selectFile')),
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
