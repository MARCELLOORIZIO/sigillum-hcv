import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_media_id_ocr.dart';

void main() {
  group('HCV media ID OCR', () {
    test('reads the Messenger recompressed sample ID', () {
      expect(
        HCVMediaIdOcr.extractFromRecognizedText(
          'SIGILLUM CAPTURE\n29/07/2026\nHCV-9DB918C9EC74451F',
        ),
        'HCV-9DB918C9EC74451F',
      );
    });

    test('repairs common OCR substitutions inside the hexadecimal payload', () {
      expect(
        HCVMediaIdOcr.extractFromRecognizedText('HCV-9DB9I8C9EC744S1F'),
        'HCV-9DB918C9EC74451F',
      );
    });

    test('accepts spaces and a missing separator around the prefix', () {
      expect(
        HCVMediaIdOcr.extractFromRecognizedText('HCV 9DB918C9EC74451F'),
        'HCV-9DB918C9EC74451F',
      );
    });
  });
}
