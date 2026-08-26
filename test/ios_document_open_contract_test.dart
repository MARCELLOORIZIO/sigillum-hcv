import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS registers Fotocamera Sigillum as a document viewer', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    expect(info, contains('<key>CFBundleTypeRole</key>'));
    expect(info, contains('<string>Viewer</string>'));
    expect(info, contains('<key>LSSupportsOpeningDocumentsInPlace</key>'));
    expect(info, contains('<string>public.image</string>'));
    expect(info, contains('<string>public.movie</string>'));
  });

  test('registry verification delegates still-image reading to multi-pass OCR', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains("import 'hcv_media_id_ocr.dart';"));
    expect(source, contains('HCVMediaIdOcr.extractFromImage(path)'));
  });
}
