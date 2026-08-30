import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh Apple-verified server status is accepted before StoreKit', () {
    final source = File('lib/commercial_account_service.dart').readAsStringSync();

    final serverStatusIndex = source.indexOf(
      "final freshServerStatus =\n        normalizedServerBilling['status']?.toString() ?? '';",
    );
    final freshnessIndex = source.indexOf(
      "normalizedServerBilling['verificationFresh'] == true",
    );
    final storeKitIndex = source.indexOf(
      'final currentEntitlements = await _currentAppleEntitlements();',
    );

    expect(serverStatusIndex, greaterThanOrEqualTo(0));
    expect(freshnessIndex, greaterThan(serverStatusIndex));
    expect(storeKitIndex, greaterThan(freshnessIndex));
    expect(
      source,
      contains("'appleEntitlement': 'server_fresh'"),
    );
    expect(
      source,
      contains("freshServerStatus == 'active' || freshServerStatus == 'grace'"),
    );
  });
}
