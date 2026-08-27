import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncertified media precheck stays short and stops before full verification', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();
    final gate = File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();
    final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

    // Full Registry verification may use its own cautious OCR logic, but the
    // public quick gate must never scan the entire video or invoke the robust
    // multi-pass still-image OCR before deciding that media is uncertified.
    expect(gate, contains("'extractVideoFrame'"));
    expect(gate, contains("'seconds': 0.2"));
    expect(gate, contains('HCVMediaIdOcr.extractFastFromImage(sourcePath)'));
    expect(gate, isNot(contains('HCVMediaIdOcr.extractFromImage(sourcePath)')));

    // The fast OCR path is exactly one native recognizer pass. The expensive
    // decode/crop/enlarge fallback remains confined to extractFromImage(),
    // which is available to the full verification pipeline only.
    expect(ocr, contains('static Future<String?> extractFastFromImage'));
    expect(ocr, contains('return _recognizePath(path);'));
    expect(ocr, contains('static Future<String?> extractFromImage'));
    expect(ocr, contains('img.decodeImage(bytes)'));

    // Keep the already-materialized Registry safeguards too.
    expect(registry, contains("'00:00:00.2'"));
    expect(registry, contains("'00:00:00.8'"));
    expect(registry, isNot(contains("'00:00:08.0'")));
    expect(registry, contains('withData: false,'));
  });
}
