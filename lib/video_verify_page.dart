import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';

import 'hcv_verifier.dart';
import 'sigillum_localization.dart';

class VideoVerifyPage extends StatefulWidget {
  final String? initialVideoPath;
  final String? initialHcvPath;
  final String languageCode;

  const VideoVerifyPage({
    super.key,
    this.initialVideoPath,
    this.initialHcvPath,
    this.languageCode = 'it',
  });

  @override
  State<VideoVerifyPage> createState() => _VideoVerifyPageState();
}

class _VideoVerifyPageState extends State<VideoVerifyPage> {
  final verifier = HCVVerifier();

  String status = "";
  String? result;

  String? videoPath;
  String? hcvPath;

  String? verifiedCreatorName;
  String? verifiedTrustLevel;
  String? verifiedIssuer;
  String? verifiedHcvId;
  String? verifiedUrl;
  String? verifiedHcvTrustLevel;
  String? verifiedLiveCaptureTrust;
  String? verifiedScreenReplayRisk;
  String? verifiedSyntheticRisk;
  String? verifiedSceneAuthenticity;
  String? verifiedAiProofLevel;
  String? verifiedAudioTrust;
  String? verifiedAudioCaptured;

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);

  @override
  void initState() {
    super.initState();
    status = _t('selectFileToVerify');

    videoPath = widget.initialVideoPath;
    hcvPath = widget.initialHcvPath;

    if (videoPath != null && hcvPath != null) {
      Future.microtask(verifyVideoWithHCV);
    } else if (videoPath != null) {
      status = "Video importato. Seleziona anche il certificato HCV";
    } else if (hcvPath != null) {
      status = "HCV importato. Seleziona anche il video";
    }
  }

  Future<void> pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    setState(() {
      videoPath = path;
      result = null;
      status = "Video selezionato";
    });
  }

  Future<void> pickHCV() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    if (!path.toLowerCase().endsWith(".hcv")) {
      setState(() {
        hcvPath = path;
        result = "INVALID ❌";
        status = "Seleziona un file .hcv";
      });
      return;
    }

    setState(() {
      hcvPath = path;
      result = null;
      status = "Certificato selezionato";
    });
  }

  Future<void> verifyVideoWithHCV() async {
    if (videoPath == null || hcvPath == null) {
      setState(() {
        status = "Seleziona prima video e HCV";
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
        verifiedHcvId = null;
        verifiedUrl = null;
        verifiedHcvTrustLevel = null;
        verifiedLiveCaptureTrust = null;
        verifiedScreenReplayRisk = null;
        verifiedSyntheticRisk = null;
        verifiedSceneAuthenticity = null;
        verifiedAiProofLevel = null;
        verifiedAudioTrust = null;
        verifiedAudioCaptured = null;
      });

      final videoFile = File(videoPath!);
      final hcvFile = File(hcvPath!);

      if (!await videoFile.exists()) {
        setState(() {
          status = "Video non trovato";
          result = "INVALID ❌";
        });
        return;
      }

      if (!await hcvFile.exists()) {
        setState(() {
          status = "HCV non trovato";
          result = "INVALID ❌";
        });
        return;
      }

      final videoBytes = await videoFile.readAsBytes();
      final videoHash = sha256.convert(videoBytes).toString();

      final hcvJson = await hcvFile.readAsString();
      final hcvData = jsonDecode(hcvJson);

      final hcvOk = await verifier.verifyFile(hcvPath!);

      if (!hcvOk) {
        setState(() {
          status = "Certificato HCV non valido";
          result = "INVALID ❌";
        });
        return;
      }

      if (hcvData is! Map<String, dynamic>) {
        setState(() {
          status = "Formato HCV non valido";
          result = "INVALID ❌";
        });
        return;
      }

      if (!hcvData.containsKey("content")) {
        setState(() {
          status = "HCV senza contenuto collegato";
          result = "INVALID ❌";
        });
        return;
      }

      final content = hcvData["content"];

      if (content == null || content is! Map<String, dynamic>) {
        setState(() {
          status = "HCV senza content binding";
          result = "INVALID ❌";
        });
        return;
      }

      if (content["type"] != "video") {
        setState(() {
          status = "Il certificato non è per un video";
          result = "INVALID ❌";
        });
        return;
      }

      final storedHash = content["hash"];

      if (storedHash != videoHash) {
        setState(() {
          status = "Hash video non corrisponde";
          result = "TAMPERED / NOT VERIFIED ❌";
        });
        return;
      }

      String? creatorName;
      String? trustLevel;
      String? issuer;
      String? hcvId;
      String? url;
      String? hcvTrustLevel;
      String? liveCaptureTrust;
      String? screenReplayRisk;
      String? syntheticRisk;
      String? sceneAuthenticity;
      String? aiProofLevel;
      String? audioTrust;
      String? audioCaptured;

      final meta = hcvData["meta"];
      if (meta is Map) {
        hcvId = meta["hcvId"]?.toString();
        url = meta["verificationUrl"]?.toString();
        final identity = meta["identity"];
        if (identity is Map) {
          creatorName = identity["creatorName"]?.toString();
          trustLevel = identity["trustLevel"]?.toString();
          issuer = identity["issuer"]?.toString();
        }
      }

      final claims = hcvData["claims"];

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
        status = "Video verificato";
        result = "HUMAN VERIFIED ✔";
        verifiedCreatorName = creatorName;
        verifiedTrustLevel = trustLevel;
        verifiedIssuer = issuer;
        verifiedHcvId = hcvId;
        verifiedUrl = url;
        verifiedHcvTrustLevel = hcvTrustLevel;
        verifiedLiveCaptureTrust = liveCaptureTrust;
        verifiedScreenReplayRisk = screenReplayRisk;
        verifiedSyntheticRisk = syntheticRisk;
        verifiedSceneAuthenticity = sceneAuthenticity;
        verifiedAiProofLevel = aiProofLevel;
        verifiedAudioTrust = audioTrust;
        verifiedAudioCaptured = audioCaptured;
      });
    } catch (e) {
      setState(() {
        status = "ERRORE: $e";
        result = "INVALID ❌";
      });
    }
  }

  bool get isVerified {
    return result == "HUMAN VERIFIED ✔";
  }

  bool get hasResult {
    return result != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HCV Video Verify"),
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
                hasResult
                    ? isVerified
                        ? Icons.verified
                        : Icons.error
                    : Icons.video_file,
                size: 72,
                color: hasResult
                    ? isVerified
                        ? Colors.green
                        : Colors.red
                    : Colors.grey,
              ),
              const SizedBox(height: 20),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: pickVideo,
                child: const Text("SELEZIONA VIDEO"),
              ),
              if (videoPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  "VIDEO:\n$videoPath",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: pickHCV,
                child: const Text("SELEZIONA HCV"),
              ),
              if (hcvPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  "HCV:\n$hcvPath",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: verifyVideoWithHCV,
                child: const Text("VERIFICA VIDEO + HCV"),
              ),
              const SizedBox(height: 20),
              if (result != null)
                Text(
                  result!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? Colors.green : Colors.red,
                  ),
                ),
              if (isVerified) ...[
                const SizedBox(height: 14),
                Text(
                  "${_t('declaredName')}: ${verifiedCreatorName ?? '-'}\n"
                  "${_t('technicalProof')}: ${verifiedTrustLevel ?? '-'}\n"
                  "${_t('issuer')}: ${verifiedIssuer ?? '-'}\n"
                  "HCV ID: ${verifiedHcvId ?? '-'}\n"
                  "Link: ${verifiedUrl ?? '-'}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (isVerified &&
                  (verifiedHcvTrustLevel != null ||
                      verifiedLiveCaptureTrust != null ||
                      verifiedScreenReplayRisk != null ||
                      verifiedSyntheticRisk != null ||
                      verifiedSceneAuthenticity != null ||
                      verifiedAiProofLevel != null ||
                      verifiedAudioTrust != null ||
                      verifiedAudioCaptured != null)) ...[
                const SizedBox(height: 16),
                const Text(
                  "HCV Trust",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${_t('trustLevel')}: ${verifiedHcvTrustLevel ?? '-'}\n"
                  "${_t('liveCapture')}: ${verifiedLiveCaptureTrust ?? '-'}\n"
                  "${_t('screenReplayRisk')}: ${verifiedScreenReplayRisk ?? '-'}\n"
                  "${_t('syntheticRisk')}: ${verifiedSyntheticRisk ?? '-'}\n"
                  "${_t('sceneAuthenticity')}: ${verifiedSceneAuthenticity ?? '-'}\n"
                  "${_t('aiProofLevel')}: ${verifiedAiProofLevel ?? '-'}\n"
                  "${_t('audio')}: ${verifiedAudioCaptured ?? '-'}\n"
                  "${_t('audioTrust')}: ${verifiedAudioTrust ?? '-'}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
