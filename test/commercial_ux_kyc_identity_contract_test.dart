import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commercial landing exposes verify, login, account creation and creator registration', () {
    final source = File('lib/commercial_gate.dart').readAsStringSync();

    expect(source, contains('VERIFICA CONTENUTO GRATIS'));
    expect(source, contains('Accedi al tuo account'));
    expect(source, contains('Crea account'));
    expect(source, contains('Diventa creator'));
  });

  test('commercial authentication opts into iOS AutoFill semantics', () {
    final source = File('lib/commercial_gate.dart').readAsStringSync();

    expect(source, contains('AutofillHints.username'));
    expect(source, contains('AutofillHints.email'));
    expect(source, contains('AutofillHints.password'));
    expect(source, contains('AutofillHints.newPassword'));
    expect(source, contains('AutofillHints.oneTimeCode'));
    expect(
      source,
      contains('TextInput.finishAutofillContext(shouldSave: true)'),
    );
  });

  test('KYC UI distinguishes user input from processing', () {
    final source = File('lib/commercial_gate.dart').readAsStringSync();

    expect(source, contains('CONTINUA VERIFICA IDENTITÀ'));
    expect(source, contains('VERIFICA IN ELABORAZIONE'));
    expect(source, contains("status == 'processing'"));
    expect(source, contains("status == 'requires_input'"));
    expect(source, contains("result['verificationLivemode'] == true"));
  });

  test('account deletion clears local KYC and creator identity data', () {
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();
    final identity = File('lib/hcv_identity.dart').readAsStringSync();

    expect(auth, contains('await HCVIdentity().clearPersonalData();'));
    expect(
      identity,
      contains('status == "verified" && verifiedOutputs == null'),
    );
  });
}
