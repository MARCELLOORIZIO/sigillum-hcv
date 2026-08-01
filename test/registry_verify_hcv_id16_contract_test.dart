import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Registry verification HCV-ID format', () {
    late String registrySource;
    late String ocrSource;

    setUpAll(() {
      registrySource =
          File('lib/registry_verify_page.dart').readAsStringSync();
      ocrSource = File('lib/hcv_media_id_ocr.dart').readAsStringSync();
    });

    test('all verification paths require the complete sixteen-character ID', () {
      expect(
        registrySource,
        contains('(HCV-[A-F0-9]{16})(?![A-F0-9])'),
      );
      expect(
        registrySource,
        contains("RegExp(r'^HCV-([A-F0-9]{16})$')"),
      );
      expect(
        ocrSource,
        contains("RegExp(r'HCV-([A-F0-9]{16})')"),
      );
      expect(
        registrySource,
        contains('HCVMediaIdOcr.extractFromImage(path)'),
      );
      expect(
        registrySource,
        isNot(contains("RegExp(r'HCV-[A-F0-9]{8}')")),
      );
      expect(
        ocrSource,
        isNot(contains("RegExp(r'HCV-[A-F0-9]{8}')")),
      );
    });

    test('Messenger recompressed sample ID is not truncated', () {
      final pattern = RegExp(r'HCV-[A-F0-9]{16}(?![A-F0-9])');
      final match = pattern.firstMatch('HCV-DD73F6F14B294836');
      expect(match?.group(0), 'HCV-DD73F6F14B294836');
    });

    test('Android OCR crop reads the upper watermark region', () {
      expect(registrySource, contains('crop=iw:ih*0.40:0:0'));
      expect(
        registrySource,
        isNot(contains('crop=iw:ih*0.35:0:ih*0.65')),
      );
    });

    test('B and 8 OCR variants operate on sixteen characters', () {
      expect(
        registrySource,
        contains(r"RegExp(r'^HCV-([A-F0-9]{16})$')"),
      );
    });
  });
}
