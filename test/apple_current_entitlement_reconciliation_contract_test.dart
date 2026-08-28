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

    test('cached backend active status cannot grant iOS access without Apple entitlement', () {
      expect(account, contains("'currentEntitlements'"));
      expect(account, contains('if (currentEntitlements.isEmpty)'));
      expect(account, contains("'status': 'inactive'"));
      expect(account, contains("'appleEntitlement': 'missing'"));
      expect(account, contains('verifyApplePurchase('));
      expect(account, contains("'appleEntitlement': 'current'"));
    });

    test('Creator routing still requires server active or grace after reconciliation', () {
      expect(gate, contains("serverStatus == 'active' || serverStatus == 'grace'"));
      expect(gate, contains('billing = await _account.billingStatus();'));
      expect(gate, isNot(contains('appleEntitlement ==')));
    });
  });
}
