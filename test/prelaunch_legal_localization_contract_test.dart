import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commercial onboarding is localized before account creation', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();

    expect(gate, contains('SigillumCopy.initialLanguageCode()'));
    expect(gate, contains("prefs.setString('sigillum_language'"));
    expect(gate, contains('Widget _languageSelector()'));
    expect(gate, contains("'en':"));
    expect(gate, contains("'es':"));
    expect(gate, contains("'ru':"));
    expect(gate, contains('languageCode: _languageCode'));
    expect(gate, isNot(contains("const ImportPage(languageCode: 'it')")));
    expect(gate, isNot(contains("const LegalInfoPage(languageCode: 'it')")));
  });

  test('legal resources follow the selected language', () {
    final legal = File('lib/legal_info_page.dart').readAsStringSync();

    expect(legal, contains('/privacy?lang='));
    expect(legal, contains('/terms?lang='));
    expect(legal, contains('/support?lang='));
    expect(legal, contains('/delete-data?lang='));
  });

  test('legal acceptance carries language and current document revision', () {
    final account =
        File('lib/commercial_account_service.dart').readAsStringSync();

    expect(account, contains("termsVersion = '2026-08-18'"));
    expect(account, contains("privacyVersion = '2026-08-18'"));
    expect(account, contains("'languageCode': languageCode"));
  });

  test('commercial profile has Spanish and Russian copy', () {
    final profile = File('lib/commercial_profile_page.dart').readAsStringSync();

    expect(profile, contains('_extraCopy'));
    expect(profile, contains("'es':"));
    expect(profile, contains("'ru':"));
  });

  test('legal localization patch cannot write HCV engine files', () {
    final patch = File('tool/apply_prelaunch_legal_localization_20260818.py')
        .readAsStringSync();

    expect(patch, contains('TARGETS ='));
    expect(patch, contains("'lib/commercial_gate.dart'"));
    expect(patch, contains("'lib/commercial_account_service.dart'"));
    expect(patch, contains("'lib/commercial_profile_page.dart'"));
    expect(patch, contains("'lib/legal_info_page.dart'"));
    expect(patch, isNot(contains("'lib/hcv_engine.dart'")));
    expect(patch, isNot(contains("'lib/camera_page.dart'")));
    expect(patch, isNot(contains("'lib/hcv_package.dart'")));
    expect(patch, isNot(contains("'lib/hcv_verifier.dart'")));
  });
}
