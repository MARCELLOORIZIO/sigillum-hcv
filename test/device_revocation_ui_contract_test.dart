import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device revocation UI and auth contract are wired', () {
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();
    final profile = File('lib/commercial_profile_page.dart').readAsStringSync();

    expect(auth, contains("'/api/auth/devices/revoke'"));
    expect(
      auth,
      contains("'deviceKeyFingerprint': deviceKeyFingerprint.trim().toLowerCase()"),
    );
    expect(auth, contains("'password': password"));

    expect(profile, contains("item['current'] == true"));
    expect(profile, contains("item['fingerprint']"));
    expect(profile, contains("_t('revoke')"));
    expect(profile, contains("_t('revokeTitle')"));
    expect(profile, contains("_t('revokeBody')"));
    expect(profile, contains('SigillumTheme.danger'));

    for (final marker in <String>[
      "'revoke': 'REVOCA'",
      "'revoke': 'REVOKE'",
      "'revoke': 'REVOCAR'",
      "'revoke': 'ОТОЗВАТЬ'",
    ]) {
      expect(profile, contains(marker));
    }
  });
}
