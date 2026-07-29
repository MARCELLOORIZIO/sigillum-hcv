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

account_action = '''                  _PrimaryAction(
                    icon: Icons.manage_accounts_rounded,
                    title: _t('accountTitle'),
                    subtitle: _t('accountSubtitle'),
                    filled: false,
                    onPressed: () => _open(
                      AccountPage(
                        languageCode: languageCode,
                        onLanguageChanged: _setLanguage,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
'''
info_anchor = '''                  _PrimaryAction(
                    icon: Icons.info_outline_rounded,
                    title: _t('infoTitle'),'''
if "title: _t('accountTitle')" not in source:
    if source.count(info_anchor) != 1:
        raise RuntimeError('Unable to insert the visible Account action')
    source = source.replace(info_anchor, account_action + info_anchor, 1)

home_path.write_text(source)

localization_path = Path('lib/sigillum_localization.dart')
localization = localization_path.read_text()

translations = {
    "      'identity': 'Identita',\n": (
        "      'identity': 'Identita',\n"
        "      'accountTitle': 'ACCOUNT',\n"
        "      'accountSubtitle': 'Profilo, identita, KYC, sicurezza e dati.',\n"
    ),
    "      'identity': 'Identity',\n": (
        "      'identity': 'Identity',\n"
        "      'accountTitle': 'ACCOUNT',\n"
        "      'accountSubtitle': 'Profile, identity, KYC, security and data.',\n"
    ),
    "      'identity': 'Identidad',\n": (
        "      'identity': 'Identidad',\n"
        "      'accountTitle': 'CUENTA',\n"
        "      'accountSubtitle': 'Perfil, identidad, KYC, seguridad y datos.',\n"
    ),
    "      'identity': 'Идентичность',\n": (
        "      'identity': 'Идентичность',\n"
        "      'accountTitle': 'АККАУНТ',\n"
        "      'accountSubtitle': 'Профиль, личность, KYC, безопасность и данные.',\n"
    ),
}

for old, new in translations.items():
    if new in localization:
        continue
    if localization.count(old) != 1:
        raise RuntimeError(f'Unable to add Account localization after: {old.strip()}')
    localization = localization.replace(old, new, 1)

localization_path.write_text(localization)

Path('test/account_page_contract_test.dart').write_text(
    '''import 'dart:io';

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
'''
)

print('SIGILLUM Account page connected through explicit home action and header icon')
