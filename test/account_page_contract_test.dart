import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SIGILLUM account section', () {
    final account = File('lib/account_page.dart').readAsStringSync();
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();
    final secureStore = File('lib/hcv_secure_store.dart').readAsStringSync();
    final identity = File('lib/hcv_identity.dart').readAsStringSync();
    final home = File('lib/user_home_page.dart').readAsStringSync();
    final localization =
        File('lib/sigillum_localization.dart').readAsStringSync();
    final swift = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/example/hcv_app/MainActivity.kt',
    ).readAsStringSync();

    test('home exposes an explicit and visible Account action', () {
      expect(home, contains("import 'account_page.dart';"));
      expect(home, contains("title: _t('accountTitle')"));
      expect(home, contains("subtitle: _t('accountSubtitle')"));
      expect(home, contains('Icons.manage_accounts_rounded'));
      expect(home, contains('AccountPage('));
      expect(home, contains('onLanguageChanged: _setLanguage'));
      expect(localization, contains("'accountTitle': 'ACCOUNT'"));
    });

    test('account supports registration login and active session controls', () {
      expect(account, contains('_auth.register('));
      expect(account, contains('_auth.login('));
      expect(account, contains("'createAccount': 'CREA ACCOUNT ONLINE'"));
      expect(account, contains("'login': 'ACCEDI A UN ACCOUNT ESISTENTE'"));
      expect(account, contains("'active': 'Attiva'"));
      expect(account, contains('Icons.logout_rounded'));
      expect(account, contains('_auth.logout('));
      expect(account, isNot(contains("'logoutUnavailable'")));
    });

    test('profile identity KYC password and devices remain manageable', () {
      expect(account, contains('HCVIdentity().saveCreatorName(name)'));
      expect(account, contains('DropdownButtonFormField<String>'));
      expect(account, contains('IdentityPage(languageCode: _languageCode)'));
      expect(account, contains('_auth.changePassword('));
      expect(account, contains('_auth.listDevices()'));
      expect(account, contains("_identity['devicePublicKeyFingerprint']"));
    });

    test('account deletion is executed directly against authenticated API', () {
      expect(account, contains('_auth.deleteAccount('));
      expect(auth, contains("'/api/auth/delete'"));
      expect(auth, contains("'confirmation': 'DELETE'"));
      expect(identity, contains('Future<void> clearPersonalData()'));
      expect(account, isNot(contains('LegalInfoPage.deleteDataUrl')));
    });

    test('auth client binds sessions to the stable device key', () {
      expect(auth, contains('SIGILLUM_AUTH_DEVICE_BINDING_V1'));
      expect(auth, contains('HCVKeystoreSigner.sign(statement)'));
      expect(auth, contains("'/api/auth/register'"));
      expect(auth, contains("'/api/auth/login'"));
      expect(auth, contains("'/api/auth/session'"));
      expect(auth, contains("'/api/auth/logout'"));
    });

    test('session token uses native secure storage on iOS and Android', () {
      expect(secureStore, contains("MethodChannel('hcv.keystore')"));
      expect(secureStore, contains("'setSecret'"));
      expect(secureStore, contains("'getSecret'"));
      expect(secureStore, contains("'deleteSecret'"));
      expect(swift, contains('kSecClassGenericPassword'));
      expect(swift, contains('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'));
      expect(kotlin, contains('AES/GCM/NoPadding'));
      expect(kotlin, contains('AndroidKeyStore'));
    });
  });
}
