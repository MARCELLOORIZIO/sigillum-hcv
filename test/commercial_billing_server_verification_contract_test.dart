import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Commercial Creator billing', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final billing =
        File('lib/commercial_billing_service.dart').readAsStringSync();
    final account =
        File('lib/commercial_account_service.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final text = File('lib/text_cert_page.dart').readAsStringSync();

    test('local StoreKit observation never grants Creator entitlement', () {
      expect(gate, isNot(contains('SharedPreferences.getInstance()')));
      expect(gate, isNot(contains('_localPurchaseObserved')));
      expect(gate, isNot(contains('_localPurchaseKey')));
      expect(gate, contains('verifyApplePurchase('));
      expect(gate, contains("serverStatus == 'active' || serverStatus == 'grace'"));
    });

    test('purchase is verified by backend before StoreKit completion', () {
      final verifyIndex = gate.indexOf('verifyApplePurchase(');
      final completeIndex = gate.indexOf('completeVerifiedPurchase(', verifyIndex);
      expect(verifyIndex, greaterThanOrEqualTo(0));
      expect(completeIndex, greaterThan(verifyIndex));
      expect(gate, contains('purchase.purchaseID'));
      expect(
        gate,
        contains('purchase.verificationData.serverVerificationData'),
      );
      expect(account, contains("'/api/billing/apple/verify'"));
      expect(account, contains("'transactionId': transactionId.trim()"));
      expect(account, contains("'receiptData': receiptData"));
    });

    test('billing service does not auto-complete unverified purchases', () {
      final listenerStart = billing.indexOf('void startListening()');
      final listenerEnd = billing.indexOf('Future<bool> purchase(', listenerStart);
      expect(listenerStart, greaterThanOrEqualTo(0));
      expect(listenerEnd, greaterThan(listenerStart));
      final listener = billing.substring(listenerStart, listenerEnd);
      expect(listener, isNot(contains('completePurchase(')));
      expect(billing, contains('completeVerifiedPurchase('));
    });

    test('commercial billing layer does not modify capture or text engines', () {
      expect(camera, isNot(contains('verifyApplePurchase(')));
      expect(camera, isNot(contains('CommercialBillingService')));
      expect(text, isNot(contains('verifyApplePurchase(')));
      expect(text, isNot(contains('CommercialBillingService')));
    });
  });
}
