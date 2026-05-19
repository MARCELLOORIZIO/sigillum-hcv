import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  String status = "Seleziona file .hcvpack";
  String? result;

  String? verifiedCreatorName;
  String? verifiedTrustLevel;
  String? verifiedIssuer;
  String? verifiedFileType;
  String? verifiedHcvTrustLevel;
  String? verifiedLiveCaptureTrust;
  String? verifiedScreenReplayRisk;
  String? verifiedSyntheticRisk;
  String? verifiedSceneAuthenticity;
  String? verifiedAiProofLevel;
  String? verifiedAudioTrust;
  String? verifiedAudioCaptured;

  Map<String, dynamic>? certificateData;

  File? extractedVideoFile;
  bool loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      Future.microtask(() => loadPackage(widget.initialPath!));
    }
  }

  Future<void> _openVideo(File tempVideoFile) async {
    extractedVideoFile = tempVideoFile;
    return;
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
      if (!packPath.toLowerCase().endsWith('.hcvpack')) {
        setState(() {
          loading = false;
          status = "Questo non è un file HCVPACK";
          result = "UNSUPPORTED ❌";
        });
        return;
      }

      setState(() {
        loading = true;
        status = "Analisi HCVPACK...";
        result = null;
        verifiedCreatorName = null;
        verifiedTrustLevel = null;
        verifiedIssuer = null;
        verifiedFileType = null;
        verifiedHcvTrustLevel = null;
        verifiedLiveCaptureTrust = null;
        verifiedScreenReplayRisk = null;
        verifiedSyntheticRisk = null;
        verifiedSceneAuthenticity = null;
        verifiedAiProofLevel = null;
        verifiedAudioTrust = null;
        verifiedAudioCaptured = null;
        certificateData = null;
        extractedVideoFile = null;
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

        await _openVideo(tempVideoFile);

        setState(() {
          loading = false;
          status = "Meta HCVPACK non corrisponde";
          result = "TAMPERED ❌";
        });
        return;
      }

      final certJsonStr = utf8.decode(certBytes);
      final certificate = jsonDecode(certJsonStr);

      if (certificate is Map<String, dynamic>) {
        certificateData = certificate;
      }

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
    certificateData = certificate;

    final videoHash = sha256.convert(videoBytes).toString();

    final content = certificate["content"];

    if (content == null || content is! Map<String, dynamic>) {
      final tempVideoFile = await _writeTempVideo(videoBytes);
      extractedVideoFile = tempVideoFile;

      await _openVideo(tempVideoFile);

      setState(() {
        loading = false;
        status = "Certificato HCV incompleto";
        result = "INVALID ❌";
      });
      return;
    }

    final contentType = (content["type"] ?? "unknown").toString();

    if (contentType != "video") {
      final tempVideoFile = await _writeTempVideo(videoBytes);
      extractedVideoFile = tempVideoFile;

      await _openVideo(tempVideoFile);

      setState(() {
        loading = false;
        status = "Il certificato HCV non è di tipo video";
        result = "INVALID ❌";
        verifiedFileType = contentType;
      });
      return;
    }

    final storedHash = content["hash"];

    if (storedHash == null || storedHash is! String) {
      final tempVideoFile = await _writeTempVideo(videoBytes);
      extractedVideoFile = tempVideoFile;

      await _openVideo(tempVideoFile);

      setState(() {
        loading = false;
        status = "Hash mancante nel certificato";
        result = "INVALID ❌";
      });
      return;
    }

    final tempVideoFile = await _writeTempVideo(videoBytes);
    extractedVideoFile = tempVideoFile;

    final tempDir = await getTemporaryDirectory();
    final tempHcvFile = File(
      p.join(
        tempDir.path,
        "hcv_cert_${DateTime.now().millisecondsSinceEpoch}.hcv",
      ),
    );

    await tempHcvFile.writeAsString(jsonEncode(certificate));

    final certOk = await verifier.verifyFile(tempHcvFile.path);

    if (!certOk) {
      await _openVideo(tempVideoFile);

      setState(() {
        loading = false;
        result = "INVALID ❌";
        status = "Certificato non valido";
      });
      return;
    }

    if (videoHash != storedHash) {
      await _openVideo(tempVideoFile);

      setState(() {
        loading = false;
        result = "TAMPERED ❌";
        status = "Video modificato";
      });
      return;
    }

    await _openVideo(tempVideoFile);

    final meta = certificate["meta"];
    final identity = meta is Map ? meta["identity"] : null;

    final claims = certificate["claims"];

    String? hcvTrustLevel;
    String? liveCaptureTrust;
    String? screenReplayRisk;
    String? syntheticRisk;
    String? sceneAuthenticity;
    String? aiProofLevel;
    String? audioTrust;
    String? audioCaptured;

    if (claims is Map) {
      hcvTrustLevel = claims["trustLevel"]?.toString();
      liveCaptureTrust = claims["liveCaptureTrust"]?.toString();
      screenReplayRisk = claims["screenReplayRisk"]?.toString();
      syntheticRisk = claims["syntheticRisk"]?.toString();
      sceneAuthenticity = claims["sceneAuthenticity"]?.toString();
      aiProofLevel = claims["aiProofLevel"]?.toString();
      audioTrust = claims["audioTrust"]?.toString();
      audioCaptured = claims["audioCaptured"]?.toString();
    }

    setState(() {
      loading = false;
      result = "HUMAN VERIFIED ✔";
      status = "Verifica completata ($sourceLabel)";

      verifiedFileType = contentType;

      if (identity is Map) {
        verifiedCreatorName =
            (identity["creatorName"] ?? "Unknown Creator").toString();

        verifiedTrustLevel = (identity["trustLevel"] ?? "UNKNOWN").toString();

        verifiedIssuer = (identity["issuer"] ?? "UNKNOWN").toString();
        verifiedHcvTrustLevel = hcvTrustLevel;
        verifiedLiveCaptureTrust = liveCaptureTrust;
        verifiedScreenReplayRisk = screenReplayRisk;
        verifiedSyntheticRisk = syntheticRisk;
        verifiedSceneAuthenticity = sceneAuthenticity;
        verifiedAiProofLevel = aiProofLevel;
        verifiedAudioTrust = audioTrust;
        verifiedAudioCaptured = audioCaptured;
      } else {
        verifiedCreatorName = "Identity not available";
        verifiedTrustLevel = "UNKNOWN";
        verifiedIssuer = "UNKNOWN";
      }
    });
  }

  Future<File> _writeTempVideo(List<int> videoBytes) async {
    final tempDir = await getTemporaryDirectory();
    final tempVideoFile = File(
      p.join(
        tempDir.path,
        "hcv_video_${DateTime.now().millisecondsSinceEpoch}.mp4",
      ),
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

  Widget buildResultBadge() {
    if (!hasResult) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.shade700 : Colors.red.shade700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.error,
            color: Colors.white,
            size: 52,
          ),
          const SizedBox(height: 8),
          Text(
            isVerified ? "HUMAN VERIFIED" : "NOT VERIFIED",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result ?? "",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDetailsPanel() {
    if (!isVerified) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Dettagli verifica HCVPACK",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Verified by: ${verifiedCreatorName ?? '-'}",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Trust: ${verifiedTrustLevel ?? '-'}",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Issuer: ${verifiedIssuer ?? '-'}",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "File type: ${verifiedFileType ?? '-'}",
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),
            Text(
              "Trust Level: ${verifiedHcvTrustLevel ?? '-'}\n"
              "Live Capture: ${verifiedLiveCaptureTrust ?? '-'}\n"
              "Screen Replay Risk: ${verifiedScreenReplayRisk ?? '-'}\n"
              "Synthetic Risk: ${verifiedSyntheticRisk ?? '-'}\n"
              "Scene Authenticity: ${verifiedSceneAuthenticity ?? '-'}\n"
              "AI Proof Level: ${verifiedAiProofLevel ?? '-'}\n"
              "Audio: ${verifiedAudioCaptured ?? '-'}\n"
              "Audio Trust: ${verifiedAudioTrust ?? '-'}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVideoInfoPanel() {
    if (extractedVideoFile == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Icon(Icons.movie_creation_outlined, size: 36),
            const SizedBox(height: 8),
            const Text(
              "Video estratto dal pacchetto",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              extractedVideoFile!.path,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 8),
            const Text(
              "Playback video disattivato su iOS in questa build.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      extractedVideoFile?.deleteSync();
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SIGILLUM HCVPACK"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.inventory_2,
                  size: 72,
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 18),
                const Text(
                  "Lettore HCVPACK",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                buildResultBadge(),
                buildDetailsPanel(),
                buildVideoInfoPanel(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: loading ? null : pickPack,
                  icon: const Icon(Icons.folder_open),
                  label: const Text("APRI HCVPACK"),
                ),
                if (loading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
