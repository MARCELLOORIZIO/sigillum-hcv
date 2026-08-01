import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_service.dart';
import 'hcv_social_fingerprint.dart';
import 'hcv_verifier.dart';

class ProductionRegistryVerifyPage extends StatefulWidget {
  const ProductionRegistryVerifyPage({
    super.key,
    this.initialMediaPath,
    this.languageCode = 'it',
  });

  final String? initialMediaPath;
  final String languageCode;

  @override
  State<ProductionRegistryVerifyPage> createState() =>
      _ProductionRegistryVerifyPageState();
}

class _ProductionRegistryVerifyPageState
    extends State<ProductionRegistryVerifyPage> {
  static const MethodChannel _mediaChannel = MethodChannel('hcv.media');
  static final RegExp _hcvIdPattern = RegExp(
    r'HCV-[A-F0-9]{8,32}',
    caseSensitive: false,
  );

  final TextEditingController _idController = TextEditingController();
  final HCVRegistryService _registry = const HCVRegistryService();
  final HCVVerifier _verifier = HCVVerifier();

  String _status = 'Seleziona il contenuto e inserisci o rileva l HCV-ID';
  String? _result;
  String? _mediaPath;
  String? _source;
  String? _integrity;
  String? _sceneDecision;
  String? _creatorName;
  String? _identityLevel;
  String? _contentType;
  bool _loading = false;
  bool _idDetectedInMedia = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMediaPath;
    if (initial != null && initial.isNotEmpty) {
      Future.microtask(() => _prepareMedia(initial, autoVerify: true));
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const [
        'mp4',
        'mov',
        'm4v',
        'jpg',
        'jpeg',
        'png',
        'txt',
        'pdf',
        'mp3',
        'wav',
        'm4a',
      ],
    );
    if (picked == null) return;
    final item = picked.files.single;
    var path = item.path;
    if (path == null && item.bytes != null) {
      final dir = await getApplicationDocumentsDirectory();
      final target = File(p.join(dir.path, item.name));
      await target.writeAsBytes(item.bytes!, flush: true);
      path = target.path;
    }
    if (path == null) {
      setState(() => _status = 'File selezionato ma non accessibile');
      return;
    }
    await _prepareMedia(path, autoVerify: false);
  }

  Future<void> _prepareMedia(
    String path, {
    required bool autoVerify,
  }) async {
    setState(() {
      _mediaPath = path;
      _loading = true;
      _result = null;
      _source = null;
      _integrity = null;
      _sceneDecision = null;
      _idDetectedInMedia = false;
      _status = 'Rilevazione HCV-ID dal contenuto...';
    });

    final detected = await _detectHcvId(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (detected != null) {
        _idController.text = detected;
        _idDetectedInMedia = true;
        _status = 'HCV-ID rilevato nel contenuto';
      } else {
        _status = 'HCV-ID non rilevato automaticamente: inseriscilo manualmente';
      }
    });
    if (autoVerify && detected != null) {
      await _verify();
    }
  }

  String? _normalizeHcvId(String value) {
    final normalized = value
        .toUpperCase()
        .replaceAll('HCV-ID:', 'HCV-')
        .replaceAll('HCV ID:', 'HCV-')
        .replaceAll('HCVID:', 'HCV-')
        .replaceAll('HCV_ID', 'HCV-')
        .replaceAll('HCV_', 'HCV-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2013', '-');
    final match = _hcvIdPattern.firstMatch(normalized);
    if (match == null) return null;
    final candidate = match.group(0)!.toUpperCase();
    final body = candidate.substring(4).replaceAll('O', '0');
    return 'HCV-$body';
  }

  Future<String?> _detectHcvId(String path) async {
    final fromName = _normalizeHcvId(p.basename(path));
    if (fromName != null) return fromName;
    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) {
      try {
        return _normalizeHcvId(await File(path).readAsString());
      } catch (_) {
        return null;
      }
    }
    if (_isImage(lower)) return _ocrImage(path);
    if (_isVideo(lower)) return _ocrVideo(path);
    return null;
  }

  Future<String?> _ocrImage(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      return _normalizeHcvId(result.text.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }

  Future<String?> _ocrVideo(String path) async {
    const seconds = [0.2, 0.8, 1.5, 2.5, 4.0, 6.0, 8.0];
    for (final second in seconds) {
      String? framePath;
      try {
        framePath = Platform.isIOS
            ? await _mediaChannel.invokeMethod<String>(
                'extractVideoFrame',
                {'path': path, 'seconds': second},
              )
            : await _extractFfmpegFrame(path, second);
        if (framePath == null) continue;
        final detected = await _ocrImage(framePath);
        if (detected != null) return detected;
      } catch (_) {
      } finally {
        if (framePath != null) {
          try {
            await File(framePath).delete();
          } catch (_) {}
        }
      }
    }
    return null;
  }

  Future<String?> _extractFfmpegFrame(String videoPath, double second) async {
    final temp = await getTemporaryDirectory();
    final output = p.join(
      temp.path,
      'hcv_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final command = "-y -ss $second -i '$videoPath' "
        "-vf \"crop=iw:ih*0.38:0:ih*0.62,scale=iw*2:ih*2,eq=contrast=1.5\" "
        "-frames:v 1 '$output'";
    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();
    return code != null && ReturnCode.isSuccess(code) ? output : null;
  }

  Future<MapEntry<String, Map<String, dynamic>>> _fetchCertificate(
    String hcvId,
  ) async {
    try {
      return MapEntry(hcvId, await _registry.fetchCertificate(hcvId));
    } catch (original) {
      for (final candidate in _ambiguousIdVariants(hcvId)) {
        try {
          return MapEntry(candidate, await _registry.fetchCertificate(candidate));
        } catch (_) {}
      }
      rethrow;
    }
  }

  Iterable<String> _ambiguousIdVariants(String hcvId) sync* {
    final normalized = _normalizeHcvId(hcvId);
    if (normalized == null) return;
    final chars = normalized.substring(4).split('');
    final positions = <int>[];
    for (var index = 0; index < chars.length; index++) {
      if (chars[index] == '8' || chars[index] == 'B') positions.add(index);
    }
    if (positions.isEmpty || positions.length > 5) return;
    final variants = <String>{};
    void walk(int position, List<String> value) {
      if (position == positions.length || variants.length >= 32) {
        variants.add('HCV-${value.join()}');
        return;
      }
      walk(position + 1, value);
      final index = positions[position];
      final original = value[index];
      value[index] = original == '8' ? 'B' : '8';
      walk(position + 1, value);
      value[index] = original;
    }
    walk(0, List<String>.from(chars));
    variants.remove(normalized);
    yield* variants;
  }

  Future<void> _verify() async {
    final mediaPath = _mediaPath;
    final normalizedId = _normalizeHcvId(_idController.text);
    if (mediaPath == null || mediaPath.isEmpty) {
      setState(() => _status = 'Seleziona il contenuto da verificare');
      return;
    }
    if (normalizedId == null) {
      setState(() => _status = 'HCV-ID non valido');
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _source = null;
      _integrity = null;
      _sceneDecision = null;
      _status = 'Ricerca certificato locale e Registry...';
    });

    try {
      final resolved = await _fetchCertificate(normalizedId);
      final hcvId = resolved.key;
      final certificate = resolved.value;
      _idController.text = hcvId;
      final source = certificate.remove('_hcvVerificationSource')?.toString() ??
          'UNKNOWN';

      final temp = await getTemporaryDirectory();
      final certFile = File(
        p.join(temp.path, 'verify_${DateTime.now().microsecondsSinceEpoch}.hcv'),
      );
      await certFile.writeAsString(jsonEncode(certificate), flush: true);
      final certificateValid = await _verifier.verifyFile(certFile.path);
      try {
        await certFile.delete();
      } catch (_) {}
      if (!certificateValid) {
        throw const FormatException('Firma crittografica del certificato non valida');
      }

      final content = certificate['content'];
      if (content is! Map) {
        throw const FormatException('Content binding mancante');
      }
      final mediaFile = File(mediaPath);
      if (!await mediaFile.exists()) {
        throw const FileSystemException('File media non disponibile');
      }
      final bytes = await mediaFile.readAsBytes();
      final actualHash = sha256.convert(bytes).toString();
      final expectedHash = content['hash']?.toString() ?? '';
      final contentType = content['type']?.toString() ?? 'unknown';

      String result;
      String integrity;
      String status;
      if (expectedHash.isNotEmpty && actualHash == expectedHash) {
        result = 'FORENSIC VERIFIED';
        integrity = 'ORIGINAL_EXACT';
        status = 'File identico byte per byte al contenuto certificato.';
      } else if (contentType == 'text' &&
          await _matchesCertifiedText(mediaPath, expectedHash)) {
        result = 'DERIVED VERIFIED';
        integrity = 'TEXT_CONTENT_MATCH';
        status = 'Testo certificato corrispondente; il footer social e ignorato.';
      } else {
        final fingerprint = await _matchesSocialFingerprint(
          certificate,
          mediaPath,
          contentType,
        );
        if (fingerprint == true) {
          result = 'DERIVED VERIFIED';
          integrity = 'SOCIAL_FINGERPRINT_MATCH';
          status =
              'File ricompresso o rinominato, ma fingerprint compatibile con il certificato.';
        } else if (fingerprint == null) {
          result = 'ID VALID / MEDIA NOT VERIFIED';
          integrity = 'NOT_DETERMINED';
          status =
              'Certificato valido, ma il media non coincide con l originale e non contiene un fingerprint compatibile.';
        } else {
          result = 'ID VALID / MEDIA MISMATCH';
          integrity = 'MISMATCH';
          status =
              'HCV-ID valido, ma il contenuto selezionato non corrisponde al certificato.';
        }
      }

      final claims = certificate['claims'];
      final sceneDecision = _signedSceneDecision(claims);
      final meta = certificate['meta'];
      final identity = meta is Map ? meta['identity'] : null;

      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = result;
        _source = source;
        _integrity = integrity;
        _sceneDecision = sceneDecision;
        _contentType = contentType;
        _creatorName =
            identity is Map ? identity['creatorName']?.toString() : null;
        _identityLevel = identity is Map
            ? identity['identityAssuranceLevel']?.toString()
            : null;
        _status = '${source == 'REGISTRY' ? 'Registry confermato' : 'Certificato locale valido'}\n$status';
      });
    } on HCVRegistryException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (error.kind == HCVRegistryFailureKind.notFound) {
          _result = 'CERTIFICATE NOT FOUND';
          _status =
              'Nessun certificato locale o Registry disponibile per questo HCV-ID.';
        } else if (error.kind == HCVRegistryFailureKind.unavailable ||
            error.kind == HCVRegistryFailureKind.server) {
          _result = 'REGISTRY UNAVAILABLE';
          _status =
              'Registry non raggiungibile e nessun certificato locale disponibile.';
        } else {
          _result = 'REGISTRY ERROR';
          _status = error.message;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'INVALID';
        _status = 'Verifica non completata: $error';
      });
    }
  }

  String _signedSceneDecision(dynamic claims) {
    if (claims is! Map) return 'NOT_ANALYZED';
    final evidence = claims['displayRiskEvidence'];
    if (evidence is Map) {
      final decision = evidence['decision']?.toString();
      final risk = evidence['risk']?.toString();
      final score = evidence['score']?.toString();
      if (decision != null && risk != null && score != null) return decision;
    }
    return claims['displayRiskDecision']?.toString() ?? 'NOT_ANALYZED';
  }

  Future<bool> _matchesCertifiedText(String path, String expectedHash) async {
    if (!path.toLowerCase().endsWith('.txt') || expectedHash.isEmpty) return false;
    try {
      final text = await File(path).readAsString();
      final clean = text.replaceFirst(
        RegExp(
          r'\s+HCV VERIFIED\s*\r?\nID:\s*HCV-[A-F0-9]{8,32}\s*\r?\nVerify with SIGILLUM\s*$',
          caseSensitive: false,
          multiLine: true,
        ),
        '',
      ).trim();
      return sha256.convert(utf8.encode(clean)).toString() == expectedHash;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _matchesSocialFingerprint(
    Map<String, dynamic> certificate,
    String path,
    String contentType,
  ) async {
    final claims = certificate['claims'];
    if (claims is! Map) return null;
    final stored = claims['socialFingerprint'];
    if (stored is! Map) return null;
    try {
      if (contentType == 'photo' && _isImage(path.toLowerCase())) {
        final expected = stored['imageHash']?.toString();
        if (expected == null || expected.isEmpty) return null;
        final current = await HCVSocialFingerprint().buildFromImage(path);
        final actual = current['imageHash']?.toString();
        if (actual == null || actual.isEmpty) return false;
        return _hexDistance(expected, actual) <= 72;
      }
      if (contentType == 'video' && _isVideo(path.toLowerCase())) {
        final expected = stored['frameHashes'];
        if (expected is! List || expected.isEmpty) return null;
        final current = await HCVSocialFingerprint().buildFromVideo(path);
        final actual = current['frameHashes'];
        if (actual is! List || actual.isEmpty) return false;
        return _videoHashesMatch(expected, actual);
      }
      return null;
    } catch (_) {
      return false;
    }
  }

  bool _videoHashesMatch(List expectedRaw, List currentRaw) {
    final expected = expectedRaw.map((value) => value.toString()).toList();
    final current = currentRaw.map((value) => value.toString()).toList();
    if (expected.isEmpty || current.isEmpty) return false;
    final used = <int>{};
    var matches = 0;
    for (final target in expected) {
      var bestIndex = -1;
      var bestDistance = 1 << 30;
      for (var index = 0; index < current.length; index++) {
        if (used.contains(index)) continue;
        final distance = _hexDistance(target, current[index]);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = index;
        }
      }
      if (bestIndex >= 0 && bestDistance <= 96) {
        used.add(bestIndex);
        matches++;
      }
    }
    final comparable = min(expected.length, current.length);
    return matches >= max(2, (comparable * 0.35).ceil());
  }

  int _hexDistance(String left, String right) {
    final length = min(left.length, right.length);
    var distance = (left.length - right.length).abs() * 4;
    for (var index = 0; index < length; index++) {
      final a = int.tryParse(left[index], radix: 16);
      final b = int.tryParse(right[index], radix: 16);
      if (a == null || b == null) {
        distance += 4;
        continue;
      }
      var diff = a ^ b;
      while (diff > 0) {
        distance += diff & 1;
        diff >>= 1;
      }
    }
    return distance;
  }

  bool _isImage(String lower) => lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png');

  bool _isVideo(String lower) => lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v');

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 3),
          SelectableText(value, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verified = _result == 'FORENSIC VERIFIED' ||
        _result == 'DERIVED VERIFIED';
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica contenuto')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                verified ? Icons.verified : Icons.manage_search,
                size: 72,
                color: verified ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'HCV-ID',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickMedia,
                icon: const Icon(Icons.file_open),
                label: const Text('SELEZIONA CONTENUTO'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _verify,
                icon: const Icon(Icons.verified_user),
                label: const Text('VERIFICA'),
              ),
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 14),
              SelectableText(_status, textAlign: TextAlign.center),
              _row('Esito', _result),
              _row('Fonte certificato', _source),
              _row('Integrita', _integrity),
              _row('Scena firmata', _sceneDecision),
              _row('Tipo contenuto', _contentType),
              _row('Creatore', _creatorName),
              _row('Livello identita', _identityLevel),
              _row('File', _mediaPath),
              if (_idDetectedInMedia)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'HCV-ID rilevato nel media',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
