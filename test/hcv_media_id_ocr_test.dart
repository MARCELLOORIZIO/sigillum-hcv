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

    test('consensus rejects a single 6-to-0 OCR error', () {
      expect(
        HCVMediaIdOcr.selectConsensusCandidate(const [
          'HCV-80DF7C6F1B0B4B36',
          'HCV-80DF7C6F1B6B4B36',
          'HCV-80DF7C6F1B6B4B36',
        ]),
        'HCV-80DF7C6F1B6B4B36',
      );
    });

    test('consensus rejects a malformed direct reading when crops agree', () {
      expect(
        HCVMediaIdOcr.selectConsensusCandidate(const [
          'HCV-DBDEC479CD146DCE',
          'HCV-DBDEC4C79CD146DC',
          'HCV-DBDEC4C79CD146DC',
        ]),
        'HCV-DBDEC4C79CD146DC',
      );
    });

    test('single robust reading remains usable after a fast-pass miss', () {
      expect(
        HCVMediaIdOcr.selectConsensusCandidate(const [
          null,
          'HCV-D2BEECE9BB114783',
          null,
        ]),
        'HCV-D2BEECE9BB114783',
      );
    });

    test('ties keep the first reading deterministically', () {
      expect(
        HCVMediaIdOcr.selectConsensusCandidate(const [
          'HCV-D2BEECE9BB114783',
          'HCV-80DF7C6F1B6B4B36',
        ]),
        'HCV-D2BEECE9BB114783',
      );
    });
  });
}
