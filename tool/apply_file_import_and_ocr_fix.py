from pathlib import Path
import re

registry_path = Path('lib/registry_verify_page.dart')
source = registry_path.read_text()

import_line = "import 'hcv_media_id_ocr.dart';\n"
anchor = "import 'hcv_social_fingerprint.dart';\n"
if import_line not in source:
    if source.count(anchor) != 1:
        raise RuntimeError('Unable to insert HCV media OCR import')
    source = source.replace(anchor, anchor + import_line, 1)

method_pattern = (
    r"  Future<String\?> extractHcvIdFromImage\(String path\) async \{"
    r".*?"
    r"\n  \}\n\n  Future<String\?> extractHcvIdFromVideoFrame"
)
method_replacement = '''  Future<String?> extractHcvIdFromImage(String path) async {
    return HCVMediaIdOcr.extractFromImage(path);
  }

  Future<String?> extractHcvIdFromVideoFrame'''
source, count = re.subn(
    method_pattern,
    lambda _: method_replacement,
    source,
    count=1,
    flags=re.S,
)
if count != 1 and 'return HCVMediaIdOcr.extractFromImage(path);' not in source:
    raise RuntimeError('Unable to replace still-image HCV OCR method')

old_status = '''      status = detectedId != null
          ? 'HCV-ID rilevato dal nome file. Ora premi VERIFICA DA REGISTRY'
          : 'File selezionato. Se disponibile, inserisci o rileva HCV-ID e premi VERIFICA DA REGISTRY.';'''
new_status = '''      status = idController.text.trim().isNotEmpty
          ? 'HCV-ID rilevato. Ora premi VERIFICA DA REGISTRY'
          : 'File selezionato. Se disponibile, inserisci o rileva HCV-ID e premi VERIFICA DA REGISTRY.';'''
if old_status in source:
    source = source.replace(old_status, new_status, 1)
elif new_status not in source:
    raise RuntimeError('Unable to preserve OCR detection status')

registry_path.write_text(source)

info_path = Path('ios/Runner/Info.plist')
info = info_path.read_text()
required_plist_fragments = [
    '<key>CFBundleTypeRole</key>',
    '<string>Viewer</string>',
    '<key>LSSupportsOpeningDocumentsInPlace</key>',
    '<string>public.image</string>',
]
for fragment in required_plist_fragments:
    if fragment not in info:
        raise RuntimeError(f'iOS document registration incomplete: {fragment}')

Path('test/hcv_media_id_ocr_test.dart').write_text(
    '''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_media_id_ocr.dart';

void main() {
  group('HCV media ID OCR', () {
    test('reads the Messenger recompressed sample ID', () {
      expect(
        HCVMediaIdOcr.extractFromRecognizedText(
          'SIGILLUM CAPTURE\\n29/07/2026\\nHCV-9DB918C9EC74451F',
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
'''
)

Path('test/ios_document_open_contract_test.dart').write_text(
    '''import 'dart:io';

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
'''
)

print('iOS document import and multi-pass Messenger OCR fixes applied')
