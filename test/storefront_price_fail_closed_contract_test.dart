import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression for TestFlight returning stale USD Product metadata while Apple's
// subscription sheet already has the correct storefront-localized EUR price.
void main() {
  group('Storefront price fail-closed contract', () {
    final native = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();

    test('native StoreKit never exposes numeric price when storefront currency is unavailable', () {
      final loopStart = native.indexOf('for product in products');
      final currencyGuard = native.indexOf(
        'guard let storefrontCurrencyCode,',
        loopStart,
      );
      final neutralFallback = native.indexOf(
        'prices[product.id] = "App Store"',
        currencyGuard,
      );
      final numericPrice = native.indexOf(
        'prices[product.id] = product.displayPrice',
        neutralFallback,
      );

      expect(loopStart, greaterThanOrEqualTo(0));
      expect(currencyGuard, greaterThan(loopStart));
      expect(neutralFallback, greaterThan(currencyGuard));
      expect(numericPrice, greaterThan(neutralFallback));
    });

    test('native StoreKit requires product currency to match storefront currency', () {
      final matchGuard = native.indexOf(
        'productCurrencyCode.caseInsensitiveCompare(storefrontCurrencyCode) == .orderedSame',
      );
      final mismatchFallback = native.indexOf(
        'prices[product.id] = "App Store"',
        matchGuard,
      );
      final numericPrice = native.indexOf(
        'prices[product.id] = product.displayPrice',
        mismatchFallback,
      );

      expect(matchGuard, greaterThanOrEqualTo(0));
      expect(mismatchFallback, greaterThan(matchGuard));
      expect(numericPrice, greaterThan(mismatchFallback));
    });

    test('Dart ProductDetails fallback is allowed only with a known storefront currency', () {
      final guard = billing.indexOf('if (storefrontCurrency.isNotEmpty)');
      final fallback = billing.indexOf(
        'if (productCurrency == storefrontCurrency && product.price.isNotEmpty)',
        guard,
      );

      expect(guard, greaterThanOrEqualTo(0));
      expect(fallback, greaterThan(guard));
      expect(
        billing,
        contains('A missing numeric\n    // price is safer and truthful'),
      );
    });
  });
}
