import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Commercial API transport', () {
    final registry =
        File('lib/hcv_registry_service.dart').readAsStringSync();
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();
    final commercial =
        File('lib/commercial_account_service.dart').readAsStringSync();

    test('account and Registry share the production API define', () {
      expect(auth, contains("'SIGILLUM_API_BASE_URL'"));
      expect(commercial, contains("'SIGILLUM_API_BASE_URL'"));
      expect(registry, contains("'SIGILLUM_API_BASE_URL'"));
    });

    test('certificate writes carry the authenticated Creator session', () {
      expect(
        registry,
        contains("HCVSecureStore.read('sigillum.auth.session.v1')"),
      );
      expect(registry, contains('HttpHeaders.authorizationHeader'));
    });

    test('public certificate fetch remains publicly readable', () {
      final fetchStart = registry.indexOf(
        'Future<Map<String, dynamic>> fetchCertificate',
      );
      expect(fetchStart, greaterThanOrEqualTo(0));
      final fetchBody = registry.substring(fetchStart);
      expect(fetchBody, contains('client.getUrl(uri)'));
      expect(
        fetchBody,
        isNot(contains("HCVSecureStore.read('sigillum.auth.session.v1')")),
      );
    });
  });
}
