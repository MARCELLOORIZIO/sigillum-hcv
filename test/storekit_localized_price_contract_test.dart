import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Creator paywall resolves every price from stable native StoreKit2', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(billing, contains("MethodChannel('hcv.storekit2')"));
    expect(billing, contains('mapEquals(previousComplete, resolved)'));
    expect(
      billing,
      contains('Stable localized App Store price unavailable for current storefront.'),
    );
    expect(appDelegate, contains('StoreKit.Product.products(for: productIds)'));
    expect(appDelegate, contains('product.displayPrice'));

    // ProductDetails.price is allowed only for non-iOS platforms. The iOS path
    // must resolve a stable complete native StoreKit2 snapshot or fail closed.
    final iosBlockStart = billing.indexOf(
      'if (defaultTargetPlatform != TargetPlatform.iOS)',
    );
    final nativeStart = billing.indexOf('final requestedIds =', iosBlockStart);
    expect(iosBlockStart, greaterThanOrEqualTo(0));
    expect(nativeStart, greaterThan(iosBlockStart));
    expect(
      billing.substring(nativeStart),
      isNot(contains('product.id: product.price')),
    );

    expect(gate, contains('localizedDisplayPrices(_products)'));
    expect(gate, contains('_productDisplayPrices.containsKey(product.id)'));
    expect(gate, contains("_productDisplayPrices[product.id] ?? '…'"));
    expect(gate, isNot(contains('_productDisplayPrices[product.id] ?? product.price')));
  });
}
