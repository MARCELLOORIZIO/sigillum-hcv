import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SIGILLUM account section', () {
    final account = File('lib/account_page.dart').readAsStringSync();
    final home = File('lib/user_home_page.dart').readAsStringSync();
    final localization =
        File('lib/sigillum_localization.dart').readAsStringSync();

    test('home exposes an explicit and visible Account action', () {
      expect(home, contains("import 'account_page.dart';"));
      expect(home, contains("title: _t('accountTitle')"));
      expect(home, contains("subtitle: _t('accountSubtitle')"));
      expect(home, contains('Icons.manage_accounts_rounded'));
      expect(home, contains('AccountPage('));
      expect(home, contains('onLanguageChanged: _setLanguage'));
      expect(localization, contains("'accountTitle': 'ACCOUNT'"));
      expect(
        localization,
        contains("'accountSubtitle': 'Profilo, identita, KYC, sicurezza e dati.'"),
      );
    });

    test('top header also opens the account page', () {
      expect(home, contains("tooltip: 'Account'"));
      expect(home, contains('Icons.manage_accounts_outlined'));
    });

    test('profile name and language are editable', () {
      expect(account, contains('HCVIdentity().saveCreatorName(name)'));
      expect(account, contains('DropdownButtonFormField<String>'));
      expect(account, contains('widget.onLanguageChanged(code)'));
    });

    test('identity and KYC management remains available', () {
      expect(account, contains('IdentityPage(languageCode: _languageCode)'));
      expect(account, contains("_identity['kycStatus']"));
      expect(account, contains("_identity['devicePublicKeyFingerprint']"));
    });

    test('account deletion opens the official deletion endpoint', () {
      expect(account, contains('LegalInfoPage.deleteDataUrl'));
      expect(account, contains('LaunchMode.externalApplication'));
      expect(account, contains('_openDeletionRequest'));
    });

    test('logout is not falsely implemented without online authentication', () {
      expect(account, contains("'logoutUnavailable'"));
      expect(account, contains('onPressed: null'));
      expect(account, contains('Icons.logout_rounded'));
    });
  });
}
