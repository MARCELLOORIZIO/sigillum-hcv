from pathlib import Path

home_path = Path('lib/user_home_page.dart')
source = home_path.read_text()

old_import = "import 'identity_page.dart';\n"
new_import = "import 'account_page.dart';\n"
if new_import not in source:
    if source.count(old_import) != 1:
        raise RuntimeError('Unable to replace IdentityPage import with AccountPage')
    source = source.replace(old_import, new_import, 1)

old_open = '''                  onIdentity: () => _open(
                    IdentityPage(languageCode: languageCode),
                  ),'''
new_open = '''                  onIdentity: () => _open(
                    AccountPage(
                      languageCode: languageCode,
                      onLanguageChanged: _setLanguage,
                    ),
                  ),'''
if new_open not in source:
    if source.count(old_open) != 1:
        raise RuntimeError('Unable to connect AccountPage to the user header')
    source = source.replace(old_open, new_open, 1)

source = source.replace(
    "tooltip: _t('identity'),\n              onPressed: onIdentity,\n              icon: const Icon(Icons.badge_outlined),",
    "tooltip: 'Account',\n              onPressed: onIdentity,\n              icon: const Icon(Icons.manage_accounts_outlined),",
    1,
)

home_path.write_text(source)

Path('test/account_page_contract_test.dart').write_text(
    '''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SIGILLUM account section', () {
    final account = File('lib/account_page.dart').readAsStringSync();
    final home = File('lib/user_home_page.dart').readAsStringSync();

    test('user header opens the account page', () {
      expect(home, contains("import 'account_page.dart';"));
      expect(home, contains('AccountPage('));
      expect(home, contains('onLanguageChanged: _setLanguage'));
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
      expect(
        account,
        contains('onPressed: null,\n                icon: const Icon(Icons.logout_rounded)'),
      );
    });
  });
}
'''
)

print('SIGILLUM account page connected and contract tests installed')
