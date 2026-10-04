import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'media precheck stays bounded while photo and video recover from OCR misses',
    () {
      final registry = File('lib/registry_verify_page.dart').readAsStringSync();
      final gate = File('lib/quick_hcv_media_gate_page.dart')
          .readAsStringSync();
      final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

      // Photos start with one native OCR pass and get only one focused top-crop
      // fallback before SIGILLUM declares that no HCV-ID is visible.
      expect(gate, contains('HCVMediaIdOcr.extractFastFromImage(sourcePath)'));
      expect(gate, contains('allowFocusedFallback = false'));
      expect(
        gate,
        contains('HCVMediaIdOcr.extractFocusedFromImage(sourcePath)'),
      );
      expect(gate, contains('allowFocusedFallback: true'));

      // Video remains bounded, but must not declare non-SIGILLUM after one
      // OCR miss. Two early frames are checked; each gets fast OCR and then
      // the focused/yellow-mask fallback before the gate may stop.
      expect(gate, contains("'extractVideoFrame'"));
      expect(gate, contains('const sampleSeconds = <double>[0.2, 0.8]'));
      expect(gate, contains('HCVMediaIdOcr.extractFocusedFromImage'));
      expect(gate, contains('A single unreadable frame must not classify'));
      expect(gate, isNot(contains('One frame only.')));

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
