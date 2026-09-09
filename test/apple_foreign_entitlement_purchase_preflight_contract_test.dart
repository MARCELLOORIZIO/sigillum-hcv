import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Prevent an Apple subscription owned by another SIGILLUM account from ever
// reaching a new payment sheet on the currently signed-in SIGILLUM account.
void main() {
  test(
    'foreign current Apple entitlement is checked before stale recovery and buyNonConsumable',
    () {
      final billing =
          File('lib/commercial_billing_service.dart').readAsStringSync();

      final purchaseStart = billing.indexOf(
        'Future<bool> purchase(ProductDetails product) async',
      );
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
    },
  );

  test(
    'purchase preflight interrogates verified StoreKit current entitlements directly',
    () {
      final billing =
          File('lib/commercial_billing_service.dart').readAsStringSync();
      final preflight = billing.indexOf(
        'Future<void> _preflightCurrentAppleEntitlementOwnership() async',
      );
      final purchase = billing.indexOf(
        'Future<bool> purchase(ProductDetails product) async',
        preflight,
      );
      final section = billing.substring(preflight, purchase);

      expect(preflight, greaterThanOrEqualTo(0));
      expect(section, contains("'currentEntitlements'"));
      expect(section, contains('await account.verifyApplePurchase('));
      expect(section, contains('transactionId: transactionId'));
      expect(section, contains('receiptData: receiptData'));
      expect(section, isNot(contains('.billingStatus()')));
    },
  );

  test(
    'ownership conflict is terminal before payment while unrelated failures do not grant entitlement',
    () {
      final billing =
          File('lib/commercial_billing_service.dart').readAsStringSync();
      final preflight = billing.indexOf(
        'Future<void> _preflightCurrentAppleEntitlementOwnership() async',
      );
      final purchase = billing.indexOf(
        'Future<bool> purchase(ProductDetails product) async',
        preflight,
      );
      final section = billing.substring(preflight, purchase);

      expect(
        section,
        contains("if (error.code == 'APPLE_SUBSCRIPTION_ALREADY_LINKED') rethrow;"),
      );
      expect(
        section,
        contains('current foreign entitlement'),
      );
      expect(
        section,
        isNot(contains('completeVerifiedPurchase(')),
      );
      expect(
        section,
        isNot(contains('_iap.buyNonConsumable(')),
      );
    },
  );
}
