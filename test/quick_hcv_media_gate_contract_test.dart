import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'photo can use focused fallback while video stays one-frame fast precheck',
    () {
      final gate = File('lib/quick_hcv_media_gate_page.dart')
          .readAsStringSync();
      final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

      expect(gate, contains("import 'hcv_media_id_ocr.dart';"));
      expect(gate, contains('HCVMediaIdOcr.extractFastFromImage(sourcePath)'));
      expect(gate, contains('HCVMediaIdOcr.extractFocusedFromImage(sourcePath)'));
      expect(gate, contains('allowFocusedFallback: true'));
      expect(gate, contains("'extractVideoFrame'"));
      expect(gate, contains("'seconds': 0.2"));
      expect(gate, contains('One frame only.'));
      expect(gate, contains('return await _ocrImage(framePath);'));
      expect(gate, contains('RegistryVerifyPage('));
      expect(gate, contains('initialHcvId: detectedId'));

      expect(ocr, contains('static Future<String?> extractFastFromImage'));
      expect(ocr, contains('return _recognizePath(path);'));
      expect(ocr, contains('static Future<String?> extractFocusedFromImage'));
      expect(ocr, contains('static String? selectConsensusCandidate'));
    },
  );
}
