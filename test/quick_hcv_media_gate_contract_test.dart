import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'photo and video use one-frame HCV precheck before Registry verification',
    () {
      final gate =
          File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();
      expect(gate, contains("import 'hcv_media_id_ocr.dart';"));
      expect(gate, contains('HCVMediaIdOcr.extractFromImage(sourcePath)'));
      expect(gate, contains("'extractVideoFrame'"));
      expect(gate, contains("'seconds': 0.2"));
      expect(gate, contains('RegistryVerifyPage('));
    },
  );
}
