import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'hcv_verifier.dart';

class VerifyPage extends StatefulWidget {
  final String? initialPath;

  const VerifyPage({
    super.key,
    this.initialPath,
  });

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final verifier = HCVVerifier();

  String status = "Seleziona file HCV";
  String? result;
  String? filePath;

  @override
  void initState() {
    super.initState();

    if (widget.initialPath != null) {
      Future.microtask(() => verifyPath(widget.initialPath!));
    }
  }

  Future<void> pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['hcv'],
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    await verifyPath(path);
  }

  Future<void> verifyPath(String path) async {
    setState(() {
      filePath = path;
      status = "Verifica in corso...";
      result = null;
    });

    try {
      final ok = await verifier.verifyFile(path);

      setState(() {
        result = ok ? "VALID ✔" : "INVALID ❌";
        status = "Completato";
      });
    } catch (e) {
      setState(() {
        status = "ERRORE: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV Verify"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: pickFile,
              child: const Text("SELEZIONA HCV"),
            ),

            const SizedBox(height: 20),

            if (result != null)
              Text(
                result!,
                style: const TextStyle(fontSize: 22),
              ),

            if (filePath != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  filePath!,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
