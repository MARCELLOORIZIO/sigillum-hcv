import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD144 removes monetization UI and parameters from USER runtime', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final secure = File('lib/secure_originals_page.dart').readAsStringSync();
    final publisher =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();

    expect(pubspec, contains('version: 1.0.0+144'));
    final consentTombstone =
        File('lib/verified_originals_consent_page.dart').readAsStringSync();
    expect(consentTombstone, isNot(contains('monetizationConsent')));
    expect(consentTombstone, isNot(contains('SwitchListTile')));
    expect(camera, isNot(contains('monetizationConsent')));
    expect(secure, isNot(contains('monetizationConsent')));
    expect(publisher, isNot(contains('bool monetizationConsent')));
    expect(publisher, contains("'monetizationConsent': false"));
    expect(publisher, contains("'monetizationEnabled': 'false'"));
  });

  test('USER text verification exposes Spanish and Russian copy', () {
    final textSocial =
        File('lib/text_social_verify_page.dart').readAsStringSync();
    final textCert = File('lib/text_cert_page.dart').readAsStringSync();

    expect(textSocial, contains("static const Map<String, String> _esCopy"));
    expect(textSocial, contains("static const Map<String, String> _ruCopy"));
    expect(textSocial, contains('VERIFICAR TEXTO PUBLICADO'));
    expect(textSocial, contains('ПРОВЕРКА ТЕКСТА'));

    expect(textCert, contains("'COMPARTIR HCVPACK DE TEXTO'"));
    expect(textCert, contains("'ОТПРАВИТЬ ТЕКСТОВЫЙ HCVPACK'"));
    expect(textCert, contains("'VERIFICAR TEXTO PUBLICADO'"));
    expect(textCert, contains("'ПРОВЕРИТЬ ОПУБЛИКОВАННЫЙ ТЕКСТ'"));
  });

  test('HCVPACK viewer user-facing copy is four-language', () {
    final player = File('lib/hcvpack_player_page.dart').readAsStringSync();

    expect(player, contains("String _p(String it, String en, String es, String ru)"));
    expect(player, contains("'Visor HCVPACK'"));
    expect(player, contains("'Просмотр HCVPACK'"));
    expect(player, contains("'ABRIR HCVPACK'"));
    expect(player, contains("'ОТКРЫТЬ HCVPACK'"));
    expect(player, isNot(contains('"Lettore HCVPACK"')));
    expect(player, isNot(contains('"APRI HCVPACK"')));
  });

  test('Registry copy uses registration rather than publication terminology', () {
    final cameraCopy = File('lib/camera_ui_copy.dart').readAsStringSync();
    final verifyCopy = File('lib/registry_verify_copy.dart').readAsStringSync();

    expect(cameraCopy, contains('Registrazione certificato nel Registry'));
    expect(cameraCopy, contains('Registering certificate in the Registry'));
    expect(cameraCopy, contains('Registrando el certificado en el Registry'));
    expect(cameraCopy, contains('Регистрация сертификата в Registry'));

    expect(
      cameraCopy,
      isNot(contains('Pubblicazione certificato nel Registry')),
    );
    expect(
      cameraCopy,
      isNot(contains('Publishing certificate to the Registry')),
    );
    expect(verifyCopy, isNot(contains('online publication may still be pending')));
    expect(verifyCopy, isNot(contains('pubblicazione online potrebbe essere ancora in attesa')));
  });
}
