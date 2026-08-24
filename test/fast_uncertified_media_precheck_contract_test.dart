import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncertified media precheck stays short and stops before full verification', () {
    final patch = File('tool/apply_fast_uncertified_media_precheck_20260823.py')
        .readAsStringSync();
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();
    final gate = File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();

    // The patch itself contains the old long timestamps in its forbidden-token
    // guard, so timing assertions must inspect the generated Registry source.
    expect(registry, contains("'00:00:00.2'"));
    expect(registry, contains("'00:00:00.8'"));
    expect(registry, isNot(contains("'00:00:08.0'")));
    expect(registry, contains('if (!mounted) return null;'));
    expect(registry, contains('withData: false,'));

    // Keep a contract on the patch so the fast-precheck finalizer cannot vanish.
    expect(patch, contains('Fast pre-check only'));

    // Public copy is selected through the four-language verification catalog.
    expect(gate, contains("_v('notCertified')"));
    expect(gate, contains('VerificationUiCopy.t(widget.languageCode, key)'));
  });
}
