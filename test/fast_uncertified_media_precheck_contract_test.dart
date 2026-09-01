import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'media precheck stays bounded while photos can recover from one OCR miss',
    () {
      final registry = File('lib/registry_verify_page.dart').readAsStringSync();
      final gate = File('lib/quick_hcv_media_gate_page.dart')
          .readAsStringSync();
      final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

      // Photos start with one native OCR pass and get only one focused top-crop
      // fallback before SIGILLUM declares that no HCV-ID is visible.
      expect(gate, contains('HCVMediaIdOcr.extractFastFromImage(sourcePath)'));
      expect(gate, contains('allowFocusedFallback = false'));
      expect(gate, contains('HCVMediaIdOcr.extractFocusedFromImage(sourcePath)'));
      expect(gate, contains('allowFocusedFallback: true'));

      // Video remains intentionally short: one frame at 0.2 s and the default
      // fast-only OCR path. The full video is never scanned by the public gate.
      expect(gate, contains("'extractVideoFrame'"));
      expect(gate, contains("'seconds': 0.2"));
      expect(gate, contains('return await _ocrImage(framePath);'));

      // Full robust still-image OCR remains available for deeper Registry
      // recovery and keeps the existing bounded multi-crop consensus set.
      expect(ocr, contains('static Future<String?> extractFastFromImage'));
      expect(ocr, contains('return _recognizePath(path);'));
      expect(ocr, contains('static Future<String?> extractFocusedFromImage'));
      expect(ocr, contains('static Future<String?> extractFromImage'));
      expect(ocr, contains('img.decodeImage(bytes)'));
      expect(ocr, contains('final fractions = <double>[0.18, 0.28, 0.42]'));
      expect(ocr, contains('rankConsensusCandidates(detections)'));

      // Keep the already-materialized Registry safeguards too.
      expect(registry, contains("'00:00:00.2'"));
      expect(registry, contains("'00:00:00.8'"));
      expect(registry, isNot(contains("'00:00:08.0'")));
      expect(registry, contains('withData: false,'));
    },
  );
}
