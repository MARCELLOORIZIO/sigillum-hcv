import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KYC recovery remains bound to the stable public key', () {
    final identity = File('lib/hcv_identity.dart').readAsStringSync();
    final page = File('lib/identity_page.dart').readAsStringSync();
    final registry = File('lib/hcv_registry_service.dart').readAsStringSync();

    expect(identity, contains('"publicKey": publicKey'));
    expect(page, contains('recoverKycSession'));
    expect(page, contains('bindExistingKycSession'));
    expect(page, contains("identity['publicKey']"));
    expect(registry, contains('/api/identity/kyc/recover'));
    expect(registry, contains('/api/identity/kyc/bind'));
  });
}
