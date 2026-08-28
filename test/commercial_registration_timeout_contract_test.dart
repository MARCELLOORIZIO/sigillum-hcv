import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Commercial Creator registration transport', () {
    final commercial =
        File('lib/commercial_account_service.dart').readAsStringSync();

    test('registration allows one Render cold start without retrying POST', () {
      expect(
        commercial,
        contains(
          'static const _registrationTimeout = Duration(seconds: 90);',
        ),
      );

      final registerStart = commercial.indexOf('Future<void> register');
      final verifyEmailStart = commercial.indexOf(
        'Future<void> verifyEmail',
        registerStart,
      );
      expect(registerStart, greaterThanOrEqualTo(0));
      expect(verifyEmailStart, greaterThan(registerStart));
      final registerBody = commercial.substring(registerStart, verifyEmailStart);

      expect(registerBody, contains("'/api/auth/register'"));
      expect(registerBody, contains('timeout: _registrationTimeout'));
      expect(registerBody, isNot(contains('for (')));
      expect(registerBody, isNot(contains('while (')));
    });

    test('ordinary commercial API requests retain the shorter default timeout', () {
      expect(
        commercial,
        contains('static const _timeout = Duration(seconds: 20);'),
      );
      expect(commercial, contains('final effectiveTimeout = timeout ?? _timeout;'));
      expect(commercial, contains('.timeout(effectiveTimeout)'));
    });
  });
}
