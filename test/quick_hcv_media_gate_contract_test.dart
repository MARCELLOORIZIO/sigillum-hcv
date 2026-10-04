import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'photo and video use bounded robust OCR before declaring non-SIGILLUM',
    () {
      final gate = File('lib/quick_hcv_media_gate_page.dart')
          .readAsStringSync();
      final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

      expect(gate, contains("import 'hcv_media_id_ocr.dart';"));
      expect(gate, contains('HCVMediaIdOcr.extractFastFromImage(sourcePath)'));
      expect(
        gate,
        contains('HCVMediaIdOcr.extractFocusedFromImage(sourcePath)'),
      );
      expect(gate, contains('allowFocusedFallback: true'));
      expect(gate, contains("'extractVideoFrame'"));
      expect(gate, contains('const sampleSeconds = <double>[0.2, 0.8]'));
      expect(gate, contains('allowFocusedFallback: true'));
      expect(gate, contains('A single unreadable frame must not classify'));
      expect(gate, isNot(contains('One frame only.')));
      expect(gate, contains('RegistryVerifyPage('));
      expect(gate, contains('initialHcvId: detectedId'));

      expect(ocr, contains('static Future<String?> extractFastFromImage'));
      expect(ocr, contains('return _recognizePath(path);'));
      expect(ocr, contains('static Future<String?> extractFocusedFromImage'));
      expect(ocr, contains('static String? selectConsensusCandidate'));
    },
  );
}
