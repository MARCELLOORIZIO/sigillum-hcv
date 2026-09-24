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


    test('Registry recovery covers the physical Messenger C-to-0 OCR error', () {
      final variants = HCVMediaIdOcr.buildRegistryRecoveryVariants(const [
        'HCV-58499808ECB04900',
      ]);

      expect(variants, contains('HCV-58499808ECB049C0'));
      expect(variants.length, lessThanOrEqualTo(16));

      const base = '58499808ECB04900';
      for (final variant in variants) {
        final payload = variant.substring(4);
        var changed = 0;
        for (var i = 0; i < base.length; i++) {
          if (base[i] != payload[i]) changed++;
        }
        expect(changed, 1, reason: '$variant must be one OCR edit only');
      }
    });

    test('Registry recovery is deterministic and respects its global cap', () {
      final first = HCVMediaIdOcr.buildRegistryRecoveryVariants(
        const ['HCV-58499808ECB04900'],
        maxVariants: 3,
      );
      final second = HCVMediaIdOcr.buildRegistryRecoveryVariants(
        const ['HCV-58499808ECB04900'],
        maxVariants: 3,
      );

      expect(first, second);
      expect(first, hasLength(3));
      expect(first, [
        'HCV-5B499808ECB04900',
        'HCV-58499B08ECB04900',
        'HCV-584998C8ECB04900',
      ]);
    });
  });
}
