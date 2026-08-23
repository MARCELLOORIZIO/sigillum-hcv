import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'registry_verify_page.dart';
import 'sigillum_theme.dart';

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

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: SigillumTheme.panelSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.security_rounded,
            color: SigillumTheme.ink,
            size: 38,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SIGILLUM',
          style: TextStyle(
            color: SigillumTheme.ink,
            fontSize: 31,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isItalian ? 'Verifica contenuto' : 'Verify content',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SigillumTheme.muted,
            fontSize: 16,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SigillumTheme.deep,
      appBar: AppBar(
        backgroundColor: SigillumTheme.panel,
        foregroundColor: SigillumTheme.ink,
        elevation: 0,
        title: Text(_isItalian ? 'Verifica contenuto' : 'Verify content'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brand(),
                  const SizedBox(height: 32),
                  if (_checking) ...[
                    const Center(
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(strokeWidth: 4),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ] else ...[
                    Icon(
                      _notCertified
                          ? Icons.shield_outlined
                          : Icons.verified_outlined,
                      size: 48,
                      color: _notCertified
                          ? SigillumTheme.danger
                          : SigillumTheme.verified,
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SigillumTheme.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
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
                      color: SigillumTheme.muted,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  if (_notCertified) ...[
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _isItalian
                            ? 'TORNA ALLA VERIFICA'
                            : 'BACK TO VERIFY',
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
