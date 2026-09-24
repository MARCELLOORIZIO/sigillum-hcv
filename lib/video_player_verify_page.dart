import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:video_player/video_player.dart';

import 'hcv_verifier.dart';
import 'hcv_logo_badge.dart';
import 'sigillum_localization.dart';

class VideoPlayerVerifyPage extends StatefulWidget {
  const VideoPlayerVerifyPage({super.key, this.languageCode = 'it'});
  final String languageCode;

  @override
  State<VideoPlayerVerifyPage> createState() => _VideoPlayerVerifyPageState();
}

class _VideoPlayerVerifyPageState extends State<VideoPlayerVerifyPage> {
  final verifier = HCVVerifier();
  String _t(String key) => SigillumCopy.t(widget.languageCode, key);

  VideoPlayerController? _controller;

  String? videoPath;
  String? hcvPath;

  String status = '';
  String? result;

  Future<void> pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    _controller?.dispose();

    final controller = VideoPlayerController.file(File(path));

    await controller.initialize();

    setState(() {
      videoPath = path;
      _controller = controller;
      status = _t('videoLoaded');
      result = null;
    });

    controller.play();
  }

  Future<void> pickHCV() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['hcv'],
    );

    if (res == null) return;

    final path = res.files.single.path;
    if (path == null) return;

    setState(() {
      hcvPath = path;
      status = _t('certificateLoaded');
    });

    await verify();
  }

  Future<void> verify() async {
    if (videoPath == null) return;

    try {
      setState(() {
        status = _t('verifying');
        result = null;
      });

      final videoFile = File(videoPath!);
      final videoBytes = await videoFile.readAsBytes();
      final videoHash = sha256.convert(videoBytes).toString();

      if (hcvPath == null) {
        setState(() {
          result = "NOT VERIFIED ❌";
          status = _t('noCertificate');
        });
        return;
      }

      final hcvFile = File(hcvPath!);
      final hcvJson = await hcvFile.readAsString();
      final data = jsonDecode(hcvJson);

      final hcvOk = await verifier.verifyFile(hcvPath!);

      if (!hcvOk) {
        setState(() {
          result = "INVALID CERT ❌";
          status = _t('invalidCertificate');
        });
        return;
      }

      final content = data["content"];

      if (content == null || content["type"] != "video") {
        setState(() {
          result = "NOT VERIFIED ❌";
          status = _t('hcvNotCompatible');
        });
        return;
      }

      final storedHash = content["hash"];

      if (storedHash != videoHash) {
        setState(() {
          result = "TAMPERED ❌";
          status = _t('videoModified');
        });
        return;
      }

      setState(() {
        result = "CERTIFICATE_VERIFIED";
        status = "OK";
      });
    } catch (e) {
      setState(() {
        result = "ERROR ❌";
        status = "$e";
      });
    }
  }

  Widget buildBadge() {
    if (result == null) return const SizedBox();

    Color color;
    String text;

    if (result!.contains("VERIFIED")) {
      color = Colors.green;
      text = _t('certificateVerifiedLabel');
    } else {
      color = Colors.red;
      text = _t('notVerifiedLabel');
    }

    return Positioned(
      top: 40,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('videoPlayerTitle')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _controller == null
                  ? Text(_t('selectVideoPrompt'))
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: VideoPlayer(_controller!),
                              ),
                              const Positioned(
                                top: 12,
                                right: 12,
                                child: HCVLogoBadge(),
                              ),
                            ],
                          ),
                        ),
                        buildBadge(),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(status),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: pickVideo,
            child: Text(_t('loadVideo')),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: pickHCV,
            child: Text(_t('loadHcv')),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
