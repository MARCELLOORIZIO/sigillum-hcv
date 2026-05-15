import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'hcv_engine.dart';
import 'hcv_verifier.dart';

class TextCertPage extends StatefulWidget {
  const TextCertPage({super.key});

  @override
  State<TextCertPage> createState() => _TextCertPageState();
}

class _TextCertPageState extends State<TextCertPage> {
  final TextEditingController controller = TextEditingController();

  final engine = HCVEngine();
  final verifier = HCVVerifier();

  String status = "Scrivi testo e certifica";
  String? result;
  String? filePath;
  String? textPath;

  Future<void> certify() async {
    final text = controller.text.trim();

    if (text.isEmpty) {
      setState(() => status = "Inserisci un testo");
      return;
    }

    try {
      // 📂 DIRECTORY
      final dir = await getApplicationDocumentsDirectory();

      // 📄 CREA FILE TXT
      final textFile = File(
        p.join(
          dir.path,
          "text_${DateTime.now().millisecondsSinceEpoch}.txt",
        ),
      );

      await textFile.writeAsString(text);

      // 🔥 HASH DEL FILE REALE (.txt)
      final bytes = await textFile.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      // 🔗 START
      engine.start();

      // 🔗 COLLEGA CONTENUTO REALE
      engine.setContent(
        type: "text",
        hash: hash,
        size: bytes.length,
        name: p.basename(textFile.path),
      );

      // 🔗 STOP
      engine.stop();

      // 💾 SALVA HCV
      final path = await engine.exportToFile();

      // 🔍 VERIFICA
      final ok = await verifier.verifyFile(path);

      setState(() {
        textPath = textFile.path;
        filePath = path;
        result = ok ? "VALID ✔" : "INVALID ❌";
        status = "Certificazione completata";
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
        title: const Text("HCV Text Certifier"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(status),

            const SizedBox(height: 20),

            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Scrivi qui il testo umano...",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: certify,
              child: const Text("CERTIFICA TESTO"),
            ),

            const SizedBox(height: 20),

            if (result != null)
              Text(
                result!,
                style: const TextStyle(fontSize: 18),
              ),

            if (textPath != null) ...[
              const SizedBox(height: 10),
              Text(
                "TXT:\n$textPath",
                textAlign: TextAlign.center,
              ),
            ],

            if (filePath != null) ...[
              const SizedBox(height: 10),
              Text(
                "HCV:\n$filePath",
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}