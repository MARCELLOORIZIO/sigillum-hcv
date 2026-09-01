import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'hcv_media_id_ocr.dart';
import 'registry_verify_page.dart';
import 'sigillum_theme.dart';
import 'verification_ui_copy.dart';

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
  String _status = '';

  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);

  @override
  void initState() {
    super.initState();
    _status = _v('fastCheck');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runPrecheck();
    });
  }

  String? _extractHcvIdFromName(String path) {
    return RegExp(
      r'HCV-[A-F0-9]{16}(?![A-F0-9])',
      caseSensitive: false,
    ).firstMatch(p.basename(path))?.group(0)?.toUpperCase();
  }

  Future<String?> _ocrImage(
    String sourcePath, {
    bool allowRobustFallback = false,
  }) async {
    final fast = await HCVMediaIdOcr.extractFastFromImage(sourcePath);
    if (fast != null || !allowRobustFallback) return fast;
    return HCVMediaIdOcr.extractFromImage(sourcePath);
  }

  Future<String?> _checkVideo() async {
    String? framePath;
    try {
      // One frame only. The full video is never scanned by the public precheck.
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
        // A single native OCR miss must not classify a certified photo as
        // uncertified. Still images get one bounded robust fallback; video
        // remains on its one-frame fast path to protect startup latency.
        detectedId = await _ocrImage(
          widget.path,
          allowRobustFallback: true,
        );
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
        _status = _v('notCertified');
      });
      return;
    }

    setState(() {
      _status = _v('idDetected');
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
          _v('verifyTitle'),
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
        title: Text(_v('verifyTitle')),
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
                    _checking ? _v('fastHelp') : _v('noId'),
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
                      child: Text(_v('backVerify')),
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
