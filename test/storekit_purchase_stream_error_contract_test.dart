import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchase stream errors are handled without showing StoreKit internals', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    expect(billing, contains('_purchaseController.addError(error, stackTrace)'));
    final listener = gate.split('CommercialBillingService.instance.purchases.listen(')[1].split('_intentChannel.setMethodCallHandler')[0];
    expect(listener, contains('onError: (Object error, StackTrace stackTrace)'));
    expect(listener, contains("_message = _t('purchaseFailed')"));
    expect(listener, isNot(contains('error.toString()')));
  });
}
