import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Creator paywall never displays a known-wrong storefront price', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(billing, contains("MethodChannel('hcv.storekit2')"));
    expect(billing, contains("'currentStorefrontCurrency'"));
    expect(billing, contains('mapEquals(previousComplete, resolved)'));
    expect(billing, contains('product.currencyCode'));
    expect(appDelegate, contains('StoreKit.Product.products(for: productIds)'));
    expect(appDelegate, contains('storefront?.currency?.identifier'));
    expect(appDelegate, contains('product.priceFormatStyle.currencyCode'));
    expect(appDelegate, contains('product.displayPrice'));
    expect(appDelegate, contains('prices[product.id] = "App Store"'));
    expect(appDelegate, isNot(contains('[SF:')));

    // ProductDetails.price may be used on iOS only as a secondary Apple-backed
    // source when its ISO currency matches the current Storefront currency.
    final iosBlockStart = billing.indexOf(
      'if (defaultTargetPlatform != TargetPlatform.iOS)',
    );
    final storefrontStart = billing.indexOf(
      'final storefrontCurrency = await _currentStorefrontCurrency()',
      iosBlockStart,
    );
    expect(iosBlockStart, greaterThanOrEqualTo(0));
    expect(storefrontStart, greaterThan(iosBlockStart));
    final iosPricing = billing.substring(storefrontStart);
    expect(iosPricing, contains('productCurrency == storefrontCurrency'));
    expect(iosPricing, contains('resolved[product.id] = product.price'));

    expect(gate, contains('localizedDisplayPrices(_products)'));
    expect(gate, contains('_productDisplayPrices.containsKey(product.id)'));
    expect(gate, contains("_productDisplayPrices[product.id] ?? '…'"));
    expect(gate, isNot(contains('_productDisplayPrices[product.id] ?? product.price')));
  });
}
