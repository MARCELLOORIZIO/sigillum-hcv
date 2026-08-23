import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'registry_verify_page.dart';

class QuickHcvMediaGatePage extends StatefulWidget {
  const QuickHcvMediaGatePage({
    super.key,
    required this.path,
    this.languageCode = 'it',
  });

  final String path;
  final String languageCode;

  @override
  State<QuickHcvMediaGatePage> createState() => _QuickHcvMediaGatePageState();
}

class _QuickHcvMediaGatePageState extends State<QuickHcvMediaGatePage> {
  static const MethodChannel _mediaChannel = MethodChannel('hcv.media');

  bool _checking = true;
  bool _notCertified = false;
  String _status = 'Controllo rapido SIGILLUM...';

  bool get _isItalian => widget.languageCode == 'it';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runPrecheck();
    });
  }

  String? _extractHcvId(String value) {
    final normalized = value
        .toUpperCase()
        .replaceAll(' ', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll('HCV-ID:', 'HCV-')
        .replaceAll('HCVID:', 'HCV-')
        .replaceAll('HCVID', 'HCV-')
        .replaceAll('HCV1D:', 'HCV-')
        .replaceAll('HCV1D', 'HCV-')
        .replaceAll('HCV_ID', 'HCV-')
        .replaceAll('HCV_', 'HCV-')
        .replaceAll('—', '-')
        .replaceAll('–', '-');

    return RegExp(r'HCV-[A-F0-9]{16}(?![A-F0-9])')
        .firstMatch(normalized)
        ?.group(0);
  }

  String? _extractHcvIdFromName(String path) {
    return RegExp(r'HCV-[A-F0-9]{16}(?![A-F0-9])', caseSensitive: false)
        .firstMatch(p.basename(path))
        ?.group(0)
        ?.toUpperCase();
  }

  Future<String?> _prepareUpperWatermarkImage(String sourcePath) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final cropHeight =
          (decoded.height * 0.46).round().clamp(1, decoded.height).toInt();
      var crop = img.copyCrop(
        decoded,
        x: 0,
        y: 0,
        width: decoded.width,
        height: cropHeight,
      );

      if (crop.width > 1280) {
        crop = img.copyResize(crop, width: 1280);
      }

      final dir = await getTemporaryDirectory();
      final out = File(
        '${dir.path}/sigillum_quick_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(img.encodeJpg(crop, quality: 84), flush: true);
      return out.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _ocrImage(String sourcePath) async {
    String? preparedPath;
    TextRecognizer? recognizer;
    try {
      preparedPath = await _prepareUpperWatermarkImage(sourcePath);
      if (!mounted) return null;
      final inputPath = preparedPath ?? sourcePath;
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized =
          await recognizer.processImage(InputImage.fromFilePath(inputPath));
      if (!mounted) return null;
      return _extractHcvId(recognized.text);
    } catch (_) {
      return null;
    } finally {
      await recognizer?.close();
      if (preparedPath != null) {
        try {
          final file = File(preparedPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<String?> _checkVideo() async {
    String? framePath;
    try {
      framePath = await _mediaChannel.invokeMethod<String>(
        'extractVideoFrame',
        {'path': widget.path, 'seconds': 0.2},
      );
      if (!mounted || framePath == null || framePath.isEmpty) return null;
      return await _ocrImage(framePath);
    } catch (_) {
      return null;
    } finally {
      if (framePath != null) {
        try {
          final frame = File(framePath);
          if (await frame.exists()) await frame.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _runPrecheck() async {
    if (!mounted) return;

    final fromName = _extractHcvIdFromName(widget.path);
    String? detectedId = fromName;
    final lower = widget.path.toLowerCase();

    if (detectedId == null) {
      if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png')) {
        detectedId = await _ocrImage(widget.path);
      } else if (lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.m4v')) {
        detectedId = await _checkVideo();
      }
    }

    if (!mounted) return;

    if (detectedId == null || detectedId.isEmpty) {
      setState(() {
        _checking = false;
        _notCertified = true;
        _status = _isItalian
            ? 'Contenuto non certificato SIGILLUM'
            : 'Content not certified by SIGILLUM';
      });
      return;
    }

    setState(() {
      _status = _isItalian
          ? 'HCV-ID rilevato. Verifica certificato in corso...'
          : 'HCV-ID detected. Verifying certificate...';
    });

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistryVerifyPage(
          initialMediaPath: widget.path,
          languageCode: widget.languageCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF35106F);
    const cyan = Color(0xFF25C2CE);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: purple,
        elevation: 0,
        title: Text(
          _isItalian ? 'Verifica contenuto' : 'Verify content',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: (_notCertified ? Colors.red : cyan)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: _checking
                        ? const Padding(
                            padding: EdgeInsets.all(23),
                            child: CircularProgressIndicator(
                              color: purple,
                              strokeWidth: 4,
                            ),
                          )
                        : Icon(
                            _notCertified
                                ? Icons.shield_outlined
                                : Icons.verified_outlined,
                            size: 46,
                            color: _notCertified ? Colors.red : purple,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: purple,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _checking
                        ? (_isItalian
                            ? 'Cerco subito il marchio HCV e il codice. Se non sono presenti, il controllo si ferma qui.'
                            : 'Checking immediately for the HCV mark and code. If absent, verification stops here.')
                        : (_isItalian
                            ? 'Non è stato rilevato un HCV-ID valido nel contenuto selezionato.'
                            : 'No valid HCV-ID was detected in the selected content.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF625A70),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (_notCertified) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyan,
                          foregroundColor: purple,
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          _isItalian
                              ? 'TORNA ALLA VERIFICA'
                              : 'BACK TO VERIFY',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
