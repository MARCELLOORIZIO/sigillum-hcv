import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVMediaIdOcr {
  const HCVMediaIdOcr._();

  static String? extractFromRecognizedText(String value) {
    if (value.trim().isEmpty) return null;

    final segments = <String>[
      ...value.split(RegExp(r'[\r\n]+')),
      value,
    ];

    for (final segment in segments) {
      final normalized = segment
          .toUpperCase()
          .replaceAll('\u2014', '-')
          .replaceAll('\u2013', '-')
          .replaceAll('\u2212', '-')
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll('HCV-ID:', 'HCV-')
          .replaceAll('HCVID:', 'HCV-')
          .replaceAll('HCVID', 'HCV-')
          .replaceAll('HCV1D:', 'HCV-')
          .replaceAll('HCV1D', 'HCV-')
          .replaceAll('HCV_ID', 'HCV-')
          .replaceAll('HCV:', 'HCV-')
          .replaceAll('HCV_', 'HCV-')
          .replaceAll('HCY-', 'HCV-')
          .replaceAll('HCU-', 'HCV-');

      final exact = RegExp(r'HCV-([A-F0-9]{16})').firstMatch(normalized);
      if (exact != null) {
        return 'HCV-${exact.group(1)}';
      }

      final loosePatterns = [
        RegExp(r'HCV[-_:]?([A-Z0-9]{16})'),
        RegExp(r'HC[VYUW][-_:]?([A-Z0-9]{16})'),
      ];

      for (final pattern in loosePatterns) {
        final match = pattern.firstMatch(normalized);
        if (match == null) continue;

        final payload = _normalizePayload(match.group(1)!);
        if (RegExp(r'^[A-F0-9]{16}$').hasMatch(payload)) {
          return 'HCV-$payload';
        }
      }
    }

    return null;
  }

  static Future<String?> extractFromImage(String path) async {
    final source = File(path);
    if (!await source.exists()) return null;

    final direct = await _recognizePath(path);
    if (direct != null) return direct;

    final temporaryCandidates = <File>[];

    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width < 32 || decoded.height < 32) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final fractions = <double>[0.18, 0.28, 0.42];

      for (var i = 0; i < fractions.length; i++) {
        final cropHeight = max(
          32,
          min(decoded.height, (decoded.height * fractions[i]).round()),
        );
        final cropWidth = max(32, (decoded.width * 0.98).round());
        final cropped = img.copyCrop(
          decoded,
          x: 0,
          y: 0,
          width: cropWidth,
          height: cropHeight,
        );

        final targetWidth = min(2400, max(1200, cropped.width * 4));
        final targetHeight = max(
          120,
          (cropped.height * targetWidth / cropped.width).round(),
        );
        final enlarged = img.copyResize(
          cropped,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.cubic,
        );

        final candidate = File(
          p.join(
            tempDir.path,
            'hcv_id_ocr_${DateTime.now().microsecondsSinceEpoch}_$i.png',
          ),
        );
        await candidate.writeAsBytes(img.encodePng(enlarged), flush: true);
        temporaryCandidates.add(candidate);
      }

      for (final candidate in temporaryCandidates) {
        final detected = await _recognizePath(candidate.path);
        if (detected != null) return detected;
      }
    } catch (_) {
      return null;
    } finally {
      for (final candidate in temporaryCandidates) {
        try {
          if (await candidate.exists()) {
            await candidate.delete();
          }
        } catch (_) {}
      }
    }

    return null;
  }

  static Future<String?> _recognizePath(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return extractFromRecognizedText(recognized.text);
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }

  static String _normalizePayload(String value) {
    final buffer = StringBuffer();

    for (final codeUnit in value.toUpperCase().codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (RegExp(r'[A-F0-9]').hasMatch(char)) {
        buffer.write(char);
        continue;
      }

      switch (char) {
        case 'O':
        case 'Q':
          buffer.write('0');
          break;
        case 'I':
        case 'L':
          buffer.write('1');
          break;
        case 'Z':
          buffer.write('2');
          break;
        case 'S':
          buffer.write('5');
          break;
        case 'G':
          buffer.write('6');
          break;
        case 'T':
          buffer.write('7');
          break;
      }
    }

    return buffer.toString();
  }
}
