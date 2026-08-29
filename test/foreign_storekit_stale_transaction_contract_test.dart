import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foreign StoreKit stale transaction recovery', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final account = File('lib/commercial_account_service.dart').readAsStringSync();

    test('foreign verified unfinished transaction is finished before new payment', () {
      final helperStart = billing.indexOf(
        'Future<bool> _recoverSameProductBeforePurchase(String productId)',
      );
      final verifyIndex = billing.indexOf('verifyApplePurchase(', helperStart);
      final foreignCatch = billing.indexOf(
        "error.code != 'APPLE_SUBSCRIPTION_ALREADY_LINKED'",
        verifyIndex,
      );
      final finishIndex = billing.indexOf(
        'finishUnfinishedAppleTransaction(transaction.transactionId)',
        foreignCatch,
      );
      final continueIndex = billing.indexOf('continue;', finishIndex);
      final buyIndex = billing.indexOf('_iap.buyNonConsumable(');

      expect(helperStart, greaterThanOrEqualTo(0));
      expect(verifyIndex, greaterThan(helperStart));
      expect(foreignCatch, greaterThan(verifyIndex));
      expect(finishIndex, greaterThan(foreignCatch));
      expect(continueIndex, greaterThan(finishIndex));
      expect(buyIndex, greaterThan(helperStart));
      expect(
        billing,
        contains('Finishing this delivery does not cancel or transfer the subscription'),
      );
    });

    test('foreign ownership conflict is terminal and is not retried', () {
      final transientStart = account.indexOf(
        'static bool _isTransientAppleVerificationError(',
      );
      final foreignGuard = account.indexOf(
        "if (error.code == 'APPLE_SUBSCRIPTION_ALREADY_LINKED') return false;",
        transientStart,
      );
      final generic409 = account.indexOf('status == 409', foreignGuard);

      expect(transientStart, greaterThanOrEqualTo(0));
      expect(foreignGuard, greaterThan(transientStart));
      expect(generic409, greaterThan(foreignGuard));
    });

    test('foreign transaction never grants local entitlement', () {
      expect(
        billing,
        isNot(contains("APPLE_SUBSCRIPTION_ALREADY_LINKED') {\n          entitlementActive = true")),
      );
      expect(
        billing,
        contains("if (status == 'active' || status == 'grace')"),
      );
    });
  });
}
