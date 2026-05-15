import 'dart:io';

import 'package:flutter/material.dart';

import 'hcvpack_player_page.dart';
import 'verify_page.dart';
import 'registry_verify_page.dart';

class HCVImportRouterPage extends StatefulWidget {
  final String path;

  const HCVImportRouterPage({
    super.key,
    required this.path,
  });

  @override
  State<HCVImportRouterPage> createState() => _HCVImportRouterPageState();
}

class _HCVImportRouterPageState extends State<HCVImportRouterPage> {
  String status = "Analisi file...";

  @override
  void initState() {
    super.initState();
    Future.microtask(processFile);
  }

  Future<void> processFile() async {
    final path = widget.path;
    final lower = path.toLowerCase();

    if (!await File(path).exists()) {
      setState(() {
        status = "File non trovato:\n$path";
      });
      return;
    }

    if (lower.endsWith(".hcvpack")) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HCVPackPlayerPage(
            initialPath: path,
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
          builder: (_) => VerifyPage(
            initialPath: path,
          ),
        ),
      );
      return;
    }

    if (_isMediaOrTextFile(lower)) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegistryVerifyPage(
            initialMediaPath: path,
          ),
        ),
      );
      return;
    }

    setState(() {
      status = "Formato non riconosciuto:\n$path";
    });
  }

  bool _isMediaOrTextFile(String lower) {
    return lower.endsWith(".mp4") ||
        lower.endsWith(".mov") ||
        lower.endsWith(".m4v") ||
        lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".txt") ||
        lower.endsWith(".pdf") ||
        lower.endsWith(".mp3") ||
        lower.endsWith(".wav");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV Import"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            status,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}