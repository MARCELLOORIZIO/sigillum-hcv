import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foreign current Apple entitlement is checked before stale recovery and buyNonConsumable', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();

    final purchaseStart = billing.indexOf('Future<bool> purchase(ProductDetails product) async');
    final preflightCall = billing.indexOf(
      'await _preflightCurrentAppleEntitlementOwnership();',
      purchaseStart,
    );
    final staleRecovery = billing.indexOf(
      'final recoveredActive = await _recoverSameProductBeforePurchase(product.id);',
      purchaseStart,
    );
    final buy = billing.indexOf('_iap.buyNonConsumable(', purchaseStart);

    expect(purchaseStart, greaterThanOrEqualTo(0));
    expect(preflightCall, greaterThan(purchaseStart));
    expect(staleRecovery, greaterThan(preflightCall));
    expect(buy, greaterThan(staleRecovery));
  });

  test('ownership conflict is terminal while unrelated status lookup failures do not grant entitlement', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final preflight = billing.indexOf(
      'Future<void> _preflightCurrentAppleEntitlementOwnership() async',
    );

    expect(preflight, greaterThanOrEqualTo(0));
    expect(
      billing.indexOf("error.code == 'APPLE_SUBSCRIPTION_ALREADY_LINKED'", preflight),
      greaterThan(preflight),
    );
    expect(
      billing.indexOf('rethrow;', preflight),
      greaterThan(preflight),
    );
    expect(
      billing,
      contains('opening another Apple sheet would only attempt a plan change'),
    );
  });
}
