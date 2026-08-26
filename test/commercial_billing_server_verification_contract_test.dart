import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Commercial Creator billing', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final billing = File('lib/commercial_billing_service.dart')
        .readAsStringSync();
    final account = File('lib/commercial_account_service.dart')
        .readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final text = File('lib/text_cert_page.dart').readAsStringSync();

    test('local StoreKit observation never grants Creator entitlement', () {
      // SharedPreferences is allowed for UI preferences such as the selected
      // language. It must never be used as a local purchase/Creator entitlement.
      expect(gate, contains("'sigillum_language'"));
      expect(gate, isNot(contains('_localPurchaseObserved')));
      expect(gate, isNot(contains('_localPurchaseKey')));
      expect(gate, isNot(contains("setBool('sigillum.creator")));
      expect(gate, contains('verifyApplePurchase('));
      expect(
        gate,
        contains("serverStatus == 'active' || serverStatus == 'grace'"),
      );
    });

    test('server active status must still have a future expiration', () {
      expect(
        account,
        contains("final status = billing['status']?.toString() ?? '';"),
      );
      expect(
        account,
        contains(
          "final rawExpiresAt = billing['expiresAt']?.toString() ?? '';",
        ),
      );
      expect(account, contains('DateTime.tryParse(rawExpiresAt)?.toUtc()'));
      expect(account, contains('!expiresAt.isAfter(DateTime.now().toUtc())'));
      expect(
        account,
        contains("<String, dynamic>{...billing, 'status': 'expired'}"),
      );
    });

    test('purchase is verified by backend before StoreKit completion', () {
      final handlerStart = gate.indexOf(
        'Future<void> _onPurchases(List<PurchaseDetails> purchases)',
      );
      final verifyIndex = gate.indexOf('verifyApplePurchase(', handlerStart);
      final completeIndex = gate.indexOf(
        'completeVerifiedPurchase(',
        verifyIndex,
      );
      expect(handlerStart, greaterThanOrEqualTo(0));
      expect(verifyIndex, greaterThan(handlerStart));
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

    test(
      'fresh StoreKit purchase retries only unresolved or transient server verification',
      () {
        expect(account, contains('_appleVerificationRetryDelays'));
        expect(account, contains('Duration(milliseconds: 600)'));
        expect(account, contains('Duration(milliseconds: 1200)'));
        expect(account, contains('Duration(milliseconds: 2400)'));
        expect(account, contains('await Future<void>.delayed(delay)'));
        expect(account, contains("if (result['verified'] == true)"));
        expect(account, contains('_isTransientAppleVerificationError(error)'));
        expect(account, contains('status == 408'));
        expect(account, contains('status == 409'));
        expect(account, contains('status == 425'));
        expect(account, contains('status == 429'));
        expect(account, contains('status >= 500'));
        expect(account, contains('if (status == null) return false;'));
        expect(account, isNot(contains('status == 401')));
        expect(account, isNot(contains('status == 403')));
        expect(
          account,
          contains("'verified': false,\n          'status': 'inactive'"),
        );
        expect(account, isNot(contains("'verified': true,\n          'status': 'active'")));
      },
    );

    test(
      'unfinished StoreKit2 transaction is verified before manual finish',
      () {
        expect(billing, contains('SK2Transaction.unfinishedTransactions()'));
        expect(billing, contains('SK2Transaction.finish(numericId)'));
        final recoveryStart = gate.indexOf(
          'Future<bool> _recoverUnfinishedAppleTransactions()',
        );
        final verifyIndex = gate.indexOf('verifyApplePurchase(', recoveryStart);
        final finishIndex = gate.indexOf(
          'finishUnfinishedAppleTransaction(',
          verifyIndex,
        );
        expect(recoveryStart, greaterThanOrEqualTo(0));
        expect(verifyIndex, greaterThan(recoveryStart));
        expect(finishIndex, greaterThan(verifyIndex));
        expect(gate, contains("if (verified['verified'] != true)"));
        expect(gate, contains("if (status == 'active' || status == 'grace')"));
      },
    );

    test(
      'purchase stream events are never dropped just because UI is busy',
      () {
        final handlerStart = gate.indexOf(
          'Future<void> _onPurchases(List<PurchaseDetails> purchases)',
        );
        final handlerEnd = gate.indexOf('Future<void> _run', handlerStart);
        expect(handlerStart, greaterThanOrEqualTo(0));
        expect(handlerEnd, greaterThan(handlerStart));
        final handler = gate.substring(handlerStart, handlerEnd);
        expect(handler, isNot(contains('if (_busy) continue')));
      },
    );

    test('billing service does not auto-complete unverified purchases', () {
      final listenerStart = billing.indexOf('void startListening()');
      final listenerEnd = billing.indexOf(
        'Future<bool> purchase(',
        listenerStart,
      );
      expect(listenerStart, greaterThanOrEqualTo(0));
      expect(listenerEnd, greaterThan(listenerStart));
      final listener = billing.substring(listenerStart, listenerEnd);
      expect(listener, isNot(contains('completePurchase(')));
      expect(billing, contains('completeVerifiedPurchase('));
    });

    test(
      'commercial billing layer does not modify capture or text engines',
      () {
        expect(camera, isNot(contains('verifyApplePurchase(')));
        expect(camera, isNot(contains('CommercialBillingService')));
        expect(text, isNot(contains('verifyApplePurchase(')));
        expect(text, isNot(contains('CommercialBillingService')));
      },
    );
  });
}
