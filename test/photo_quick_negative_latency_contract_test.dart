import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'negative PHOTO precheck is bounded to fast plus one focused OCR pass',
    () {
      final gate = File('lib/quick_hcv_media_gate_page.dart')
          .readAsStringSync();
      final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

      expect(gate, contains('HCVMediaIdOcr.extractFastFromImage(sourcePath)'));
      expect(
        gate,
        contains('HCVMediaIdOcr.extractFocusedFromImage(sourcePath)'),
      );
      expect(gate, contains('allowFocusedFallback: true'));
      expect(gate, isNot(contains('allowRobustFallback: true')));

      final imageMethodStart = gate.indexOf('Future<String?> _ocrImage(');
      final videoMethodStart = gate.indexOf(
        'Future<String?> _checkVideo()',
        imageMethodStart,
      );
      expect(imageMethodStart, greaterThanOrEqualTo(0));
      expect(videoMethodStart, greaterThan(imageMethodStart));
      final quickImageBlock = gate.substring(
        imageMethodStart,
        videoMethodStart,
      );
      expect(quickImageBlock, isNot(contains('extractFromImage(sourcePath)')));

      expect(ocr, contains('static Future<String?> extractFocusedFromImage'));
      expect(ocr, contains('(decoded.height * 0.28).round()'));
      expect(ocr, contains('hcv_id_ocr_focused_'));
      expect(
        ocr,
        contains('static Future<List<String>> extractCandidatesFromImage'),
      );
      expect(ocr, contains('final fractions = <double>[0.18, 0.28, 0.42]'));
    },
  );
}
