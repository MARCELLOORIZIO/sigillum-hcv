import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS paywall never exposes currency-inconsistent StoreKit price', () {
    final billing =
        File('lib/commercial_billing_service.dart').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();

    expect(billing, contains("MethodChannel('hcv.storekit2')"));
    expect(billing, contains("'localizedProductPrices'"));
    expect(billing, contains("'currentStorefrontCurrency'"));
    expect(billing, contains('product.currencyCode'));
    expect(billing, contains('mapEquals(previousComplete, resolved)'));
    expect(billing, contains('_storefrontPriceRetryDelays'));

    expect(appDelegate, contains('import StoreKit'));
    expect(appDelegate, contains('StoreKit.Product.products(for: productIds)'));
    expect(appDelegate, contains('storefront?.currency?.identifier'));
    expect(appDelegate, contains('product.priceFormatStyle.currencyCode'));
    expect(appDelegate, contains('prices[product.id] = product.displayPrice'));
    expect(appDelegate, contains('prices[product.id] = "App Store"'));
    expect(appDelegate, isNot(contains('[SF:')));
    expect(appDelegate, contains('name: "hcv.storekit2"'));

    // A stale ProductDetails sandbox price must never become visible merely as
    // a fallback. The Apple purchase sheet remains the final price authority.
    expect(gate, isNot(contains('?? product.price')));
    expect(gate, contains('!_productDisplayPrices.containsKey(product.id)'));
  });
}
