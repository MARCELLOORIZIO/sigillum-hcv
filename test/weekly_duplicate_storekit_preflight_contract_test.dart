import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekly StoreKit duplicate-product preflight', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();

    test('same product is recovered before creating a new payment', () {
      final purchaseStart = billing.indexOf('Future<bool> purchase(ProductDetails product)');
      final recoverIndex = billing.indexOf(
        '_recoverSameProductBeforePurchase(product.id)',
        purchaseStart,
      );
      final buyIndex = billing.indexOf('_iap.buyNonConsumable(', purchaseStart);

      expect(purchaseStart, greaterThanOrEqualTo(0));
      expect(recoverIndex, greaterThan(purchaseStart));
      expect(buyIndex, greaterThan(recoverIndex));
      expect(
        billing,
        contains('.where((transaction) => transaction.productId == productId)'),
      );
    });

    test('unfinished transaction is authenticated before manual finish', () {
      final helperStart = billing.indexOf(
        'Future<bool> _recoverSameProductBeforePurchase(String productId)',
      );
      final verifyIndex = billing.indexOf('verifyApplePurchase(', helperStart);
      final verifiedGuard = billing.indexOf(
        "if (verified['verified'] != true)",
        verifyIndex,
      );
      final finishIndex = billing.indexOf(
        'finishUnfinishedAppleTransaction(transaction.transactionId)',
        verifyIndex,
      );

      expect(helperStart, greaterThanOrEqualTo(0));
      expect(verifyIndex, greaterThan(helperStart));
      expect(verifiedGuard, greaterThan(verifyIndex));
      expect(finishIndex, greaterThan(verifiedGuard));
    });

    test('active recovery restores normal delivery instead of repurchasing', () {
      final purchaseStart = billing.indexOf('Future<bool> purchase(ProductDetails product)');
      final activeIndex = billing.indexOf('if (recoveredActive)', purchaseStart);
      final restoreIndex = billing.indexOf('await _iap.restorePurchases();', activeIndex);
      final returnIndex = billing.indexOf('return true;', restoreIndex);
      final buyIndex = billing.indexOf('_iap.buyNonConsumable(', returnIndex);

      expect(activeIndex, greaterThan(purchaseStart));
      expect(restoreIndex, greaterThan(activeIndex));
      expect(returnIndex, greaterThan(restoreIndex));
      expect(buyIndex, greaterThan(returnIndex));
      expect(billing, contains("status == 'active' || status == 'grace'"));
    });

    test('unverified recovery remains fail closed', () {
      expect(
        billing,
        contains("throw const CommercialAccountException(\n          'Verifica abbonamento App Store non riuscita.'"),
      );
      expect(billing, isNot(contains('verified = true')));
      expect(billing, isNot(contains("'status': 'active'")));
    });
  });
}
