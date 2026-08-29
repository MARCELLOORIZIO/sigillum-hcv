import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression for TestFlight returning stale USD Product metadata while Apple's
// subscription sheet already has the correct storefront-localized EUR price.
void main() {
  group('Storefront price fail-closed contract', () {
    final native = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();

    test('native derives a region currency from Storefront alpha-3 country code', () {
      expect(native, contains('Locale(identifier: "en_\\(countryCode)")'));
      expect(native, contains('regionCurrencyCode'));
      expect(native, contains('trustedCurrencyCode'));
    });

    test('conflicting Storefront and region currencies produce no trusted numeric currency', () {
      final bothKnown = native.indexOf(
        'if !storefrontCurrencyCode.isEmpty && !regionCurrencyCode.isEmpty',
      );
      final equality = native.indexOf(
        'storefrontCurrencyCode.caseInsensitiveCompare(regionCurrencyCode) == .orderedSame',
        bothKnown,
      );
      final trustedAssignment = native.indexOf(
        'trustedCurrencyCode = storefrontCurrencyCode',
        equality,
      );

      expect(bothKnown, greaterThanOrEqualTo(0));
      expect(equality, greaterThan(bothKnown));
      expect(trustedAssignment, greaterThan(equality));
      expect(
        native,
        isNot(contains(
          'else {\n        trustedCurrencyCode = storefrontCurrencyCode\n      }',
        )),
      );
    });

    test('native price is numeric only when Product currency matches trusted currency', () {
      final loopStart = native.indexOf('for product in products');
      final trustGuard = native.indexOf(
        'guard !trustedCurrencyCode.isEmpty',
        loopStart,
      );
      final matchGuard = native.indexOf(
        'productCurrencyCode.caseInsensitiveCompare(trustedCurrencyCode) == .orderedSame',
        trustGuard,
      );
      final neutralFallback = native.indexOf(
        'prices[product.id] = "App Store"',
        trustGuard,
      );
      final numericPrice = native.indexOf(
        'prices[product.id] = product.displayPrice',
        matchGuard,
      );

      expect(loopStart, greaterThanOrEqualTo(0));
      expect(trustGuard, greaterThan(loopStart));
      expect(matchGuard, greaterThan(trustGuard));
      expect(neutralFallback, greaterThan(trustGuard));
      expect(numericPrice, greaterThan(matchGuard));
    });

    test('Dart ProductDetails fallback is allowed only with trusted storefront currency', () {
      final guard = billing.indexOf('if (storefrontCurrency.isNotEmpty)');
      final fallback = billing.indexOf(
        'if (productCurrency == storefrontCurrency && product.price.isNotEmpty)',
        guard,
      );

      expect(guard, greaterThanOrEqualTo(0));
      expect(fallback, greaterThan(guard));
      expect(
        billing,
        contains('Never fall back to a currency-inconsistent Product'),
      );
    });
  });
}
