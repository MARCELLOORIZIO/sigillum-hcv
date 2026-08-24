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
      final uploadStart = registry.indexOf(
        'Future<Map<String, dynamic>> uploadCertificateFile',
      );
      final fetchStart = registry.indexOf(
        'Future<Map<String, dynamic>> fetchCertificate',
      );
      expect(uploadStart, greaterThanOrEqualTo(0));
      expect(fetchStart, greaterThan(uploadStart));
      final uploadBody = registry.substring(uploadStart, fetchStart);
      expect(uploadBody, contains('HCVSecureStore.read('));
      expect(uploadBody, contains('sigillum.auth.session.v1'));
      expect(uploadBody, contains('HttpHeaders.authorizationHeader'));
      expect(uploadBody, contains("'Bearer \$sessionToken'"));
    });

    test('public certificate fetch remains publicly readable', () {
      final fetchStart = registry.indexOf(
        'Future<Map<String, dynamic>> fetchCertificate',
      );
      final queueStart = registry.indexOf(
        'Future<void> enqueueCertificateFile',
        fetchStart,
      );
      expect(fetchStart, greaterThanOrEqualTo(0));
      expect(queueStart, greaterThan(fetchStart));
      final fetchBody = registry.substring(fetchStart, queueStart);
      expect(fetchBody, contains('client.getUrl(uri)'));
      expect(fetchBody, isNot(contains('HCVSecureStore.read(')));
      expect(fetchBody, isNot(contains('HttpHeaders.authorizationHeader')));
    });

    test('commercial login preserves backend auth error code for gate routing', () {
      final loginStart = commercial.indexOf(
        'Future<Map<String, dynamic>> login',
      );
      final forgotStart = commercial.indexOf(
        'Future<void> forgotPassword',
        loginStart,
      );
      expect(loginStart, greaterThanOrEqualTo(0));
      expect(forgotStart, greaterThan(loginStart));
      final loginBody = commercial.substring(loginStart, forgotStart);
      expect(loginBody, contains('on HCVAuthException catch (error)'));
      expect(loginBody, contains('CommercialAccountException('));
      expect(loginBody, contains('statusCode: error.statusCode'));
      expect(loginBody, contains('code: error.code'));
    });
  });
}
