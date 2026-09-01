import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVMediaIdOcr {
  const HCVMediaIdOcr._();

  static const MethodChannel _mediaChannel = MethodChannel('hcv.media');

  static String? extractFromRecognizedText(String value) {
    if (value.trim().isEmpty) return null;

    final segments = <String>[...value.split(RegExp(r'[\r\n]+')), value];

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

  static List<String> rankConsensusCandidates(Iterable<String?> candidates) {
    final counts = <String, int>{};
    final firstSeen = <String>[];

    for (final raw in candidates) {
      final candidate = raw?.trim().toUpperCase();
      if (candidate == null ||
          !RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(candidate)) {
        continue;
      }

      if (!counts.containsKey(candidate)) {
        counts[candidate] = 0;
        firstSeen.add(candidate);
      }
      counts[candidate] = counts[candidate]! + 1;
    }

    final firstSeenOrder = <String, int>{
      for (var i = 0; i < firstSeen.length; i++) firstSeen[i]: i,
    };
    firstSeen.sort((left, right) {
      final voteOrder = counts[right]!.compareTo(counts[left]!);
      if (voteOrder != 0) return voteOrder;
      return firstSeenOrder[left]!.compareTo(firstSeenOrder[right]!);
    });
    return firstSeen;
  }

  /// Chooses the HCV-ID supported by the largest number of independent OCR
  /// readings. Ties preserve first-seen order, so the direct full-image pass
  /// remains the deterministic fallback when every reading disagrees.
  static String? selectConsensusCandidate(Iterable<String?> candidates) {
    final ranked = rankConsensusCandidates(candidates);
    return ranked.isEmpty ? null : ranked.first;
  }

  /// Fast precheck: exactly one native OCR pass.
  ///
  /// Video verification uses this bounded path on one extracted frame. Photo
  /// verification may use it as the first pass and then invoke extractFromImage
  /// when a more robust still-image decision is required.
  static Future<String?> extractFastFromImage(String path) async {
    final source = File(path);
    if (!await source.exists()) return null;
    return _recognizePath(path);
  }

  /// Bounded still-image fallback for the public PHOTO precheck.
  ///
  /// The fast pass has already inspected the full image. This method performs
  /// exactly one additional OCR reading on an enlarged top crop, where the
  /// visible SIGILLUM HCV-ID watermark is rendered. Full multi-crop consensus
  /// remains reserved for deeper Registry recovery.
  static Future<String?> extractFocusedFromImage(String path) async {
    final source = File(path);
    if (!await source.exists()) return null;

    File? candidate;
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width < 32 || decoded.height < 32) {
        return null;
      }

      final cropHeight = max(
        32,
        min(decoded.height, (decoded.height * 0.28).round()),
      );
      final cropWidth = max(32, (decoded.width * 0.98).round());
      final cropped = img.copyCrop(
        decoded,
        x: 0,
        y: 0,
        width: cropWidth,
        height: cropHeight,
      );
      final targetWidth = min(2000, max(1000, cropped.width * 3));
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

      final tempDir = await getTemporaryDirectory();
      candidate = File(
        p.join(
          tempDir.path,
          'hcv_id_ocr_focused_${DateTime.now().microsecondsSinceEpoch}.png',
        ),
      );
      await candidate.writeAsBytes(img.encodePng(enlarged), flush: true);
      return await _recognizePath(candidate.path);
    } catch (_) {
      return null;
    } finally {
      try {
        if (candidate != null && await candidate.exists()) {
          await candidate.delete();
        }
      } catch (_) {}
    }
  }

  /// Returns every valid still-image HCV-ID candidate, ranked by independent
  /// OCR agreement. Registry verification can use lower-ranked candidates only
  /// after a higher-ranked candidate is confirmed absent online.
  static Future<List<String>> extractCandidatesFromImage(String path) async {
    final source = File(path);
    if (!await source.exists()) return const [];

    final detections = <String?>[];
    detections.add(await _recognizePath(path));

    final temporaryCandidates = <File>[];

    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width < 32 || decoded.height < 32) {
        return rankConsensusCandidates(detections);
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
        detections.add(await _recognizePath(candidate.path));
      }
    } catch (_) {
      return rankConsensusCandidates(detections);
    } finally {
      for (final candidate in temporaryCandidates) {
        try {
          if (await candidate.exists()) {
            await candidate.delete();
          }
        } catch (_) {}
      }
    }

    return rankConsensusCandidates(detections);
  }

  /// Robust still-image OCR. The best candidate is selected from the same
  /// ranked list that remains available to Registry 404 recovery.
  static Future<String?> extractFromImage(String path) async {
    final candidates = await extractCandidatesFromImage(path);
    return candidates.isEmpty ? null : candidates.first;
  }

  static Future<String?> _recognizePath(String path) async {
    final source = File(path);
    try {
      if (!await source.exists() || await source.length() <= 0) return null;
    } catch (_) {
      return null;
    }

    // google_mlkit_text_recognition on iOS constructs MLKVisionImage from a
    // UIImage. The plugin currently lets ML Kit raise an Objective-C exception
    // when UIImage(contentsOfFile:) is nil, which aborts the entire process and
    // cannot be caught by Dart. Preflight with the same UIKit decoder first.
    if (Platform.isIOS) {
      try {
        final decodable = await _mediaChannel.invokeMethod<bool>(
          'validateImageForOcr',
          {'path': path},
        );
        if (decodable != true) return null;
      } catch (_) {
        return null;
      }
    }

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
