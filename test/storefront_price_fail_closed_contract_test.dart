import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
      expect(
        native,
        contains(
          'productCurrencyCode.caseInsensitiveCompare(storefrontCurrencyCode) == .orderedSame',
        ),
      );
      expect(
        native,
        isNot(contains(
          'productCurrencyCode.caseInsensitiveCompare(storefrontCurrencyCode) != .orderedSame {\n                prices[product.id] = "App Store"\n                continue\n              }\n              prices[product.id] = product.displayPrice',
        )),
      );
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
