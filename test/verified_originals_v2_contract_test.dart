import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creator consent remains separate from publishing and monetization', () {
    final source =
        File('lib/verified_originals_consent_page.dart').readAsStringSync();

    expect(source, contains("'monetizationConsent': _monetizationConsent"));
    expect(source, contains("'publishReference': true"));
    expect(source, contains("'rightsConfirmed': true"));
    expect(source, isNot(contains("'originalSha256':")));
    expect(source, isNot(contains('youtubeApiKey')));
    expect(source, isNot(contains('clientSecret')));
    expect(source, isNot(contains("'/api/verified-originals/publications'")));
    expect(source, isNot(contains('launchUrl')));
  });

  test('public reference screen never calls a social integrity verdict', () {
    final source = File('lib/verified_originals_page.dart').readAsStringSync();
    expect(source, contains('un HCV-ID può essere copiato'));
    expect(source, contains('non dimostra'));
    expect(source, isNot(contains('INTEGRITÀ VERIFICATA')));
    expect(source, isNot(contains('SOCIAL VERIFIED OK')));
  });
}
