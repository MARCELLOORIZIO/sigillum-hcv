import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';

import 'hcv_verifier.dart';

class HCVPackPlayerPage extends StatefulWidget {
  final String? initialPath;

  const HCVPackPlayerPage({
    super.key,
    this.initialPath,
  });

  @override
  State<HCVPackPlayerPage> createState() => _HCVPackPlayerPageState();
}

class _HCVPackPlayerPageState extends State<HCVPackPlayerPage> {
  final verifier = HCVVerifier();

  late final Player player;
  late final VideoController controller;

  String status = "Seleziona file .hcvpack";
  String? result;

  Map<String, dynamic>? certificateData;

  File? extractedVideoFile;
  bool loading = false;

  @override
  void initState() {
    super.initState();

    MediaKit.ensureInitialized();

    player = Player();
    controller = VideoController(player);

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      Future.microtask(() => loadPackage(widget.initialPath!));
    }
  }

  Future<void> pickPack() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (res == null) return;

      final path = res.files.single.path;
      if (path == null) return;

      if (!path.toLowerCase().endsWith('.hcvpack')) {
        setState(() {
          status = "Seleziona un file .hcvpack";
          result = "ERROR ❌";
        });
        return;
      }

      await loadPackage(path);
    } catch (e) {
      setState(() {
        status = "Errore selezione file: $e";
        result = "ERROR ❌";
      });
    }
  }

  Future<void> loadPackage(String packPath) async {
    try {
      setState(() {
        loading = true;
        status = "Analisi HCVPACK...";
        result = null;
      });

      final file = File(packPath);

      if (!await file.exists()) {
        setState(() {
          loading = false;
          status = "File non trovato:\n$packPath";
          result = "ERROR ❌";
        });
        return;
      }

      final bytes = await file.readAsBytes();

      if (_looksLikeZip(bytes)) {
        await _loadZipPackage(bytes);
      } else {
        await _loadJsonBase64Package(bytes);
      }
    } catch (e) {
      setState(() {
        loading = false;
        status = "ERRORE: $e";
        result = "ERROR ❌";
      });
    }
  }

  bool _looksLikeZip(List<int> bytes) {
    if (bytes.length < 4) return false;

    return bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  Future<void> _loadZipPackage(List<int> packBytes) async {
    try {
      setState(() {
        status = "Apertura HCVPACK ZIP...";
      });

      final archive = ZipDecoder().decodeBytes(packBytes);

      ArchiveFile? videoEntry;
      ArchiveFile? certEntry;
      ArchiveFile? metaEntry;

      for (final entry in archive.files) {
        final name = entry.name.toLowerCase();

        if (name == "video.mp4") {
          videoEntry = entry;
        }

        if (name == "certificate.hcv") {
          certEntry = entry;
        }

        if (name == "meta.json") {
          metaEntry = entry;
        }
      }

      if (videoEntry == null || certEntry == null || metaEntry == null) {
        setState(() {
          loading = false;
          status = "HCVPACK ZIP incompleto: video/certificato/meta mancanti";
          result = "ERROR ❌";
        });
        return;
      }

      final videoBytes = List<int>.from(videoEntry.content as List<int>);
      final certBytes = List<int>.from(certEntry.content as List<int>);
      final metaBytes = List<int>.from(metaEntry.content as List<int>);

      final certSha256 = sha256.convert(certBytes).toString();
      final videoSha256 = sha256.convert(videoBytes).toString();

      final metaStr = utf8.decode(metaBytes);
      final metaJson = jsonDecode(metaStr);

      if (metaJson is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          status = "meta.json non valido";
          result = "ERROR ❌";
        });
        return;
      }

      final metaOk = _validateMeta(
        meta: metaJson,
        videoSha256: videoSha256,
        certificateSha256: certSha256,
      );

      if (!metaOk) {
        final tempVideoFile = await _writeTempVideo(videoBytes);
        extractedVideoFile = tempVideoFile;

        await player.open(
          Media(tempVideoFile.path),
          play: true,
        );

        setState(() {
          loading = false;
          status = "Meta HCVPACK non corrisponde";
          result = "TAMPERED ❌";
        });
        return;
      }

      final certJsonStr = utf8.decode(certBytes);
      final certificate = jsonDecode(certJsonStr);

      certificateData = certificate;

      if (certificate is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          status = "Certificato HCV non valido";
          result = "ERROR ❌";
        });
        return;
      }

      await _verifyAndPlay(
        videoBytes: videoBytes,
        certificate: certificate,
        sourceLabel: "ZIP v${metaJson["version"]}",
      );
    } catch (e) {
      setState(() {
        loading = false;
        status = "Errore lettura ZIP HCVPACK: $e";
        result = "ERROR ❌";
      });
    }
  }

  bool _validateMeta({
    required Map<String, dynamic> meta,
    required String videoSha256,
    required String certificateSha256,
  }) {
    if (meta["type"] != "HCV_PACKAGE") return false;
    if (meta["version"] != 2) return false;

    if (meta["videoFile"] != "video.mp4") return false;
    if (meta["certificateFile"] != "certificate.hcv") return false;

    if (meta["hashAlgorithm"] != "SHA256") return false;
    if (meta["certificateFormat"] != "HCV") return false;

    if (meta["videoSha256"] != videoSha256) return false;
    if (meta["certificateSha256"] != certificateSha256) return false;

    final packageId = meta["packageId"];
    final createdAt = meta["createdAt"];

    if (packageId == null || packageId is! String || packageId.isEmpty) {
      return false;
    }

    if (createdAt == null || createdAt is! String || createdAt.isEmpty) {
      return false;
    }

    final expectedPackageIdSource =
        "$videoSha256|$certificateSha256|$createdAt";
    final expectedPackageId =
        sha256.convert(utf8.encode(expectedPackageIdSource)).toString();

    if (packageId != expectedPackageId) return false;

    return true;
  }

  Future<void> _loadJsonBase64Package(List<int> packBytes) async {
    try {
      setState(() {
        status = "Apertura HCVPACK JSON legacy...";
      });

      final jsonStr = utf8.decode(packBytes);
      final data = jsonDecode(jsonStr);
      

      if (data is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          status = "Formato HCVPACK non valido";
          result = "ERROR ❌";
        });
        return;
      }

      final videoBase64 = data["video"];
      final certificate = data["certificate"];

      if (videoBase64 == null || certificate == null) {
        setState(() {
          loading = false;
          status = "HCVPACK incompleto";
          result = "ERROR ❌";
        });
        return;
      }

      if (videoBase64 is! String) {
        setState(() {
          loading = false;
          status = "Video HCVPACK non valido";
          result = "ERROR ❌";
        });
        return;
      }

      if (certificate is! Map<String, dynamic>) {
        setState(() {
          loading = false;
          status = "Certificato HCV non valido";
          result = "ERROR ❌";
        });
        return;
      }
      certificateData = certificate;

      final videoBytes = base64Decode(videoBase64);

      await _verifyAndPlay(
        videoBytes: videoBytes,
        certificate: certificate,
        sourceLabel: "JSON legacy",
      );
    } catch (e) {
      setState(() {
        loading = false;
        status = "Errore lettura JSON HCVPACK: $e";
        result = "ERROR ❌";
      });
    }
  }

  Future<void> _verifyAndPlay({
    required List<int> videoBytes,
    required Map<String, dynamic> certificate,
    required String sourceLabel,
  }) async {
    final videoHash = sha256.convert(videoBytes).toString();

    final content = certificate["content"];

    if (content == null || content is! Map<String, dynamic>) {
      final tempVideoFile = await _writeTempVideo(videoBytes);
      extractedVideoFile = tempVideoFile;

      await player.open(
        Media(tempVideoFile.path),
        play: true,
      );

      setState(() {
        loading = false;
        status = "Certificato HCV incompleto";
        result = "INVALID ❌";
      });
      return;
    }

    final storedHash = content["hash"];

    if (storedHash == null || storedHash is! String) {
      final tempVideoFile = await _writeTempVideo(videoBytes);
      extractedVideoFile = tempVideoFile;

      await player.open(
        Media(tempVideoFile.path),
        play: true,
      );

      setState(() {
        loading = false;
        status = "Hash mancante nel certificato";
        result = "INVALID ❌";
      });
      return;
    }

    final tempVideoFile = await _writeTempVideo(videoBytes);
    extractedVideoFile = tempVideoFile;

    final tempHcvFile = File(
      "${Directory.systemTemp.path}/hcv_cert_${DateTime.now().millisecondsSinceEpoch}.hcv",
    );

    await tempHcvFile.writeAsString(jsonEncode(certificate));

    final certOk = await verifier.verifyFile(tempHcvFile.path);

    if (!certOk) {
      await player.open(
        Media(tempVideoFile.path),
        play: true,
      );

      setState(() {
        loading = false;
        result = "INVALID ❌";
        status = "Certificato non valido";
      });
      return;
    }

    if (videoHash != storedHash) {
      await player.open(
        Media(tempVideoFile.path),
        play: true,
      );

      setState(() {
        loading = false;
        result = "TAMPERED ❌";
        status = "Video modificato";
      });
      return;
    }

    await player.open(
      Media(tempVideoFile.path),
      play: true,
    );

    setState(() {
      loading = false;
      result = "HUMAN VERIFIED ✔";
      status = "Verifica completata ($sourceLabel)";
    });
  }

  Future<File> _writeTempVideo(List<int> videoBytes) async {
    final tempVideoFile = File(
      "${Directory.systemTemp.path}/hcv_video_${DateTime.now().millisecondsSinceEpoch}.mp4",
    );

    await tempVideoFile.writeAsBytes(videoBytes);

    return tempVideoFile;
  }

  bool get isVerified {
    return result == "HUMAN VERIFIED ✔";
  }

  bool get hasResult {
    return result != null;
  }


  Widget buildBadge() {
    if (!hasResult) {
      return const SizedBox();
    }

    final identity = certificateData?["meta"]?["identity"];

    return Positioned(
      top: 18,
      left: 16,
      right: 16,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: isVerified ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVerified
                    ? "HUMAN VERIFIED"
                    : "NOT VERIFIED",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),

              if (
                isVerified &&
                identity is Map<String, dynamic>
              ) ...[
                const SizedBox(height: 10),

                const Divider(
                  color: Colors.white24,
                  height: 1,
                ),

                const SizedBox(height: 10),

                const Text(
                  "Verified by",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  (identity["creatorName"] ??
                          "Unknown Creator")
                      .toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Trust: ${(identity["trustLevel"] ?? "UNKNOWN").toString()}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  Widget buildLoadingOverlay() {
    if (!loading) return const SizedBox();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget buildStatusPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isVerified)
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),

            if (result != null) ...[
              const SizedBox(height: 6),
              Text(
                isVerified ? "HUMAN VERIFIED ✔" : "NOT VERIFIED ❌",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isVerified ? Colors.green : Colors.red,
                ),
              ),
            ],

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: loading ? null : pickPack,
              child: const Text("APRI HCVPACK"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    player.dispose();

    try {
      extractedVideoFile?.deleteSync();
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("HCV Pack Player"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Video(controller: controller),
                  ),
                ),

                if (hasResult) buildBadge(),

                buildLoadingOverlay(),
              ],
            ),
          ),

          buildStatusPanel(),
        ],
      ),
    );
  }
}