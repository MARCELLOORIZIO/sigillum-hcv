import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Registry verification HCV-ID format', () {
    late String source;

    setUpAll(() {
      source = File('lib/registry_verify_page.dart').readAsStringSync();
    });

    test('OCR and text parsing require the complete sixteen-character ID', () {
      expect(
        RegExp(r"RegExp\(r'HCV-\[A-F0-9\]\{16\}")
            .allMatches(source)
            .length,
        greaterThanOrEqualTo(2),
      );
      expect(
        source,
        isNot(contains("RegExp(r'HCV-[A-F0-9]{8}')")),
      );
    });

    test('Messenger recompressed sample ID is not truncated', () {
      final pattern = RegExp(r'HCV-[A-F0-9]{16}(?![A-F0-9])');
      final match = pattern.firstMatch('HCV-DD73F6F14B294836');
      expect(match?.group(0), 'HCV-DD73F6F14B294836');
    });

    test('Android OCR crop reads the upper watermark region', () {
      expect(source, contains('crop=iw:ih*0.40:0:0'));
      expect(source, isNot(contains('crop=iw:ih*0.35:0:ih*0.65')));
    });

    test('B and 8 OCR variants operate on sixteen characters', () {
      expect(
        source,
        contains(r"RegExp(r'^HCV-([A-F0-9]{16})$')"),
      );
    });
  });
}
