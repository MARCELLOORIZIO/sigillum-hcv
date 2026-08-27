import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreKit cancel/retry lifecycle', () {
    final billing =
        File('lib/commercial_billing_service.dart').readAsStringSync();

    test('purchase remains locked until purchaseStream terminal state', () {
      final purchaseStart =
          billing.indexOf('Future<bool> purchase(ProductDetails product)');
      final lockIndex = billing.indexOf(
        '_purchaseInFlight.add(product.id)',
        purchaseStart,
      );
      final buyIndex = billing.indexOf('_iap.buyNonConsumable(', purchaseStart);
      final waitIndex = billing.indexOf('await terminal.future;', buyIndex);

      expect(purchaseStart, greaterThanOrEqualTo(0));
      expect(lockIndex, greaterThan(purchaseStart));
      expect(buyIndex, greaterThan(lockIndex));
      expect(waitIndex, greaterThan(buyIndex));
    });

    test('cancel is terminal and releases exact product before retry', () {
      final handlerStart = billing.indexOf(
        'void _releaseTerminalPurchaseAttempts(List<PurchaseDetails> purchases)',
      );
      final canceledIndex = billing.indexOf(
        'purchase.status == PurchaseStatus.canceled',
        handlerStart,
      );
      final releaseIndex = billing.indexOf(
        '_releasePurchaseAttempt(purchase.productID)',
        canceledIndex,
      );

      expect(handlerStart, greaterThanOrEqualTo(0));
      expect(canceledIndex, greaterThan(handlerStart));
      expect(releaseIndex, greaterThan(canceledIndex));
      expect(
        billing,
        contains("throw StateError('Acquisto App Store già in corso per questo prodotto.')"),
      );
    });

    test('pending is not terminal and cannot unlock the product early', () {
      final handlerStart = billing.indexOf(
        'void _releaseTerminalPurchaseAttempts(List<PurchaseDetails> purchases)',
      );
      final handlerEnd = billing.indexOf(
        'void _releasePurchaseAttempt(String productId)',
        handlerStart,
      );
      final handler = billing.substring(handlerStart, handlerEnd);

      expect(handler, isNot(contains('PurchaseStatus.pending')));
      expect(handler, contains('PurchaseStatus.purchased'));
      expect(handler, contains('PurchaseStatus.restored'));
      expect(handler, contains('PurchaseStatus.error'));
      expect(handler, contains('PurchaseStatus.canceled'));
    });

    test('cancellation never grants entitlement or bypasses backend verification', () {
      expect(
        billing,
        isNot(contains('PurchaseStatus.canceled ||\n          purchase.status == PurchaseStatus.purchased')),
      );
      expect(
        billing,
        contains("if (verified['verified'] != true)"),
      );
      expect(
        billing,
        contains('finishUnfinishedAppleTransaction(transaction.transactionId)'),
      );
      expect(billing, isNot(contains('verified = true')));
      expect(billing, isNot(contains("'status': 'active'")));
    });
  });
}
