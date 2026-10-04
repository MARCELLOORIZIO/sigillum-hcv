import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD146 routes Verify Text to paste-based social verification', () {
    final importPage = File('lib/import_page.dart').readAsStringSync();

    expect(importPage, contains("import 'text_social_verify_page.dart';"));
    expect(importPage, contains('onPressed: _openPublishedTextVerification'));
    expect(importPage, contains('builder: (_) => TextSocialVerifyPage('));
    expect(importPage, contains("label: Text(_v('verifyText'))"));

    // File/HCVPACK verification remains available, but must be a separate
    // action and must not own the Verify Text button.
    expect(importPage, contains('onPressed: pickDocument'));
    expect(importPage, contains('VERIFICA FILE / HCVPACK'));
    expect(
      importPage,
      isNot(
        contains(
          "onPressed: pickDocument,\n                    icon: const Icon(Icons.description_outlined),\n                    label: Text(_v('verifyText'))",
        ),
      ),
    );
  });
}
