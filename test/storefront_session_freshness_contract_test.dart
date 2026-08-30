import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression for the real TestFlight case observed on 2026-08-30: SIGILLUM's
// paywall showed stale USD while Apple's purchase sheet showed the correct EUR.
void main() {
  group('Storefront session freshness contract', () {
    final native = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();

    test('launch-time Storefront.current is baseline only, never freshness proof', () {
      expect(native, contains('storefrontBaselineFingerprint'));
      expect(native, contains('storefrontSessionFresh = false'));
      expect(native, contains('StoreKit.Storefront.updates'));
      expect(
        native,
        contains('fingerprint != self.storefrontBaselineFingerprint'),
      );
      expect(native, contains('self.storefrontSessionFresh = true'));
    });

    test('native never returns numeric display price before a storefront refresh', () {
      final freshnessRead = native.indexOf(
        'let sessionFresh = await MainActor.run { self.storefrontSessionFresh }',
      );
      final freshnessGuard = native.indexOf('guard sessionFresh else', freshnessRead);
      final neutral = native.indexOf(r'($0, "App Store")', freshnessGuard);
      final numeric = native.indexOf(
        'prices[product.id] = product.displayPrice',
        neutral,
      );

      expect(freshnessRead, greaterThanOrEqualTo(0));
      expect(freshnessGuard, greaterThan(freshnessRead));
      expect(neutral, greaterThan(freshnessGuard));
      expect(numeric, greaterThan(neutral));
    });

    test('Dart refuses ProductDetails numeric fallback until native session is fresh', () {
      expect(billing, contains("raw?['sessionFresh'] != true"));
      expect(billing, contains('if (storefrontCurrency.isNotEmpty)'));
      expect(billing, contains("id: 'App Store'"));
    });

    test('neutral launch result uses full retry window instead of settling immediately', () {
      expect(billing, contains('_isNeutralApplePrice'));
      expect(
        billing,
        contains('neutralOnly && storefrontCurrency.isEmpty'),
      );
      expect(
        billing,
        contains('give Storefront.updates a chance to refresh'),
      );
    });
  });
}
