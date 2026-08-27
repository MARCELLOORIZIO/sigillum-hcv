import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS paywall confirms stable native StoreKit2 price snapshot', () {
    final billing =
        File('lib/commercial_billing_service.dart').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();

    expect(billing, contains("MethodChannel('hcv.storekit2')"));
    expect(billing, contains("'localizedProductPrices'"));
    expect(billing, contains('mapEquals(previousComplete, resolved)'));
    expect(billing, contains('_storefrontPriceRetryDelays'));
    expect(
      billing,
      contains("'Stable localized App Store price unavailable for current storefront.'"),
    );

    expect(appDelegate, contains('import StoreKit'));
    expect(appDelegate, contains('StoreKit.Product.products(for: productIds)'));
    expect(appDelegate, contains('prices[product.id] = product.displayPrice'));
    expect(appDelegate, contains('name: "hcv.storekit2"'));

    // A stale ProductDetails sandbox price must never become visible while the
    // current Apple storefront price is still resolving.
    expect(gate, isNot(contains('?? product.price')));
    expect(gate, contains('!_productDisplayPrices.containsKey(product.id)'));
  });
}
