import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS paywall uses native StoreKit2 displayPrice only', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(billing, contains("MethodChannel('hcv.storekit2')"));
    expect(billing, contains("'localizedProductPrices'"));
    expect(billing, isNot(contains('SK2Product.products(requestedIds)')));
    expect(billing, isNot(contains("MethodChannel('hcv.media')")));

    // Pricing comes from native StoreKit2 Product.displayPrice, not the legacy
    // StoreKit1 priceLocale bridge or ProductDetails.price on iOS.
    expect(appDelegate, contains('import StoreKit'));
    expect(appDelegate, contains('StoreKit.Product.products(for: productIds)'));
    expect(appDelegate, contains('product.displayPrice'));
    expect(appDelegate, contains('name: "hcv.storekit2"'));
    expect(billing, isNot(contains("'localizedProductPrices',\n          {'productIds': missingIds}")));
  });
}
