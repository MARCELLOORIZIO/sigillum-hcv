import 'dart:convert';
import 'dart:io';

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

  String? verifiedCreatorName;
  String? verifiedTrustLevel;
  String? verifiedIssuer;

  @override
  void initState() {
    super.initState();

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      filePath = widget.initialPath;
      Future.microtask(() => verifyCurrentFile());
    }
  }

  Future<void> pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    if (!path.toLowerCase().endsWith(".hcv")) {
      setState(() {
        filePath = path;
        status = "Seleziona un file .hcv";
        result = "INVALID ❌";
        verifiedCreatorName = null;
        verifiedTrustLevel = null;
        verifiedIssuer = null;
      });
      return;
    }

    setState(() {
      filePath = path;
      status = "File HCV selezionato";
      result = null;
      verifiedCreatorName = null;
      verifiedTrustLevel = null;
      verifiedIssuer = null;
    });

    await verifyCurrentFile();
  }

  Future<void> verifyCurrentFile() async {
    if (filePath == null) {
      setState(() {
        status = "Seleziona prima un file HCV";
      });
      return;
    }

    try {
      setState(() {
        status = "Verifica in corso...";
        result = null;
        verifiedCreatorName = null;
        verifiedTrustLevel = null;
        verifiedIssuer = null;
      });

      final ok = await verifier.verifyFile(filePath!);

      if (ok) {
        await loadIdentityFromCertificate(filePath!);
      }

      setState(() {
        result = ok ? "VALID ✔" : "INVALID ❌";
        status = ok ? "Certificato valido" : "Certificato non valido";
      });
    } catch (e) {
      setState(() {
        status = "ERRORE: $e";
        result = "INVALID ❌";
        verifiedCreatorName = null;
        verifiedTrustLevel = null;
        verifiedIssuer = null;
      });
    }
  }

  Future<void> loadIdentityFromCertificate(String path) async {
    try {
      final file = File(path);

      if (!await file.exists()) {
        return;
      }

      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr);

      if (data is! Map<String, dynamic>) {
        return;
      }

      final meta = data["meta"];
      if (meta is! Map) {
        return;
      }

      final identity = meta["identity"];
      if (identity is! Map) {
        return;
      }

      verifiedCreatorName =
          (identity["creatorName"] ?? "Unknown Creator").toString();

      verifiedTrustLevel =
          (identity["trustLevel"] ?? "UNKNOWN").toString();

      verifiedIssuer =
          (identity["issuer"] ?? "UNKNOWN").toString();
    } catch (_) {
      verifiedCreatorName = null;
      verifiedTrustLevel = null;
      verifiedIssuer = null;
    }
  }

  bool get isValid {
    return result == "VALID ✔";
  }

  Widget buildIdentityBlock() {
    if (!isValid || verifiedCreatorName == null) {
      return const SizedBox();
    }

    return Column(
      children: [
        const SizedBox(height: 14),

        const Text(
          "Verified by",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          verifiedCreatorName!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          "Trust: ${verifiedTrustLevel ?? "UNKNOWN"}",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),

        const SizedBox(height: 4),

        Text(
          "Issuer: ${verifiedIssuer ?? "UNKNOWN"}",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV Certificate Verify"),
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
              Icon(
                isValid ? Icons.verified : Icons.description,
                size: 72,
                color: result == null
                    ? Colors.grey
                    : isValid
                        ? Colors.green
                        : Colors.red,
              ),

              const SizedBox(height: 20),

              Text(
                status,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: pickFile,
                child: const Text("SELEZIONA HCV"),
              ),

              const SizedBox(height: 20),

              if (result != null)
                Text(
                  result!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isValid ? Colors.green : Colors.red,
                  ),
                ),

              buildIdentityBlock(),

              if (filePath != null) ...[
                const SizedBox(height: 12),
                Text(
                  filePath!,
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