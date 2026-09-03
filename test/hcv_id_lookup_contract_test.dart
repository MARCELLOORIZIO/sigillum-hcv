import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification menu exposes a separate HCV-ID lookup', () {
    final source = File('lib/import_page.dart').readAsStringSync();

    expect(source, contains("import 'hcv_id_lookup_page.dart';"));
    expect(source, contains('HcvIdLookupPage'));
    expect(source, contains('CONSULTA HCV-ID'));
  });

  test('HCV-ID lookup retrieves and verifies certificate without media path', () {
    final source = File('lib/hcv_id_lookup_page.dart').readAsStringSync();

    expect(source, contains('_registry.fetchCertificate(hcvId)'));
    expect(source, contains('_verifier.verifyFile(tempFile.path)'));
    expect(source, contains('Nessun file media è stato confrontato'));
    expect(source, isNot(contains('RegistryVerifyPage(')));
  });
}
