import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Apple current entitlement reconciliation', () {
    final account =
        File('lib/commercial_account_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    test('native StoreKit exports only verified current entitlements as JWS', () {
      expect(swift, contains('StoreKit.Transaction.currentEntitlements'));
      expect(swift, contains('case .verified(let transaction)'));
      expect(swift, contains('verification.jwsRepresentation'));
      expect(swift, contains('case .unverified:'));
      expect(swift, contains('continue'));
    });

    test('missing StoreKit entitlement requires fresh Apple server reconciliation', () {
      expect(account, contains("'currentEntitlements'"));
      expect(account, contains("'/api/billing/apple/reconcile'"));
      expect(account, contains("reconciled['verified'] == true"));
      expect(account, contains("reconciledStatus == 'active' ||"));
      expect(account, contains("reconciledStatus == 'grace'"));
      expect(account, contains("'appleEntitlement': 'server_reconciled'"));
      expect(account, contains("'appleEntitlement': currentEntitlements.isEmpty"));
      expect(account, contains("'status': 'inactive'"));
    });

    test('StoreKit current entitlement remains a valid verified fast path', () {
      expect(account, contains('verifyApplePurchase('));
      expect(account, contains("verified['verified'] == true"));
      expect(account, contains("'appleEntitlement': 'current'"));
    });

    test('Creator routing still requires active or grace after reconciliation', () {
      expect(gate, contains("serverStatus == 'active' || serverStatus == 'grace'"));
      expect(gate, contains('billing = await _account.billingStatus();'));
      expect(gate, isNot(contains('appleEntitlement ==')));
    });
  });
}
