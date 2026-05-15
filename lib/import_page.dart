import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'hcv_import_router_page.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String status = "Seleziona un file da verificare";
  String? selectedPath;

  Future<void> pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (res == null) {
        setState(() {
          status = "Nessun file selezionato";
        });
        return;
      }

      final path = res.files.single.path;

      if (path == null) {
        setState(() {
          status = "Path file non disponibile";
        });
        return;
      }

      setState(() {
        selectedPath = path;
        status = "File selezionato:\n$path";
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HCVImportRouterPage(path: path),
        ),
      );
    } catch (e) {
      setState(() {
        status = "Errore import: $e";
      });
    }
  }

  bool isSupported(String path) {
    final lower = path.toLowerCase();

    return lower.endsWith(".hcvpack") ||
        lower.endsWith(".hcv") ||
        lower.endsWith(".txt") ||
        lower.endsWith(".mp4") ||
        lower.endsWith(".mov") ||
        lower.endsWith(".m4v");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Import / Verify"),
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

              const Text(
                "Importa e verifica file HCV",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Supportati:\n.hcvpack, .hcv, .txt, .mp4, .mov, .m4v",
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
                child: const Text("SELEZIONA FILE"),
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