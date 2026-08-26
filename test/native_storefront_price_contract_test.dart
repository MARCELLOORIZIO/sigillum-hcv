import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS paywall price comes from native current App Store storefront', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(billing, contains("MethodChannel('hcv.media')"));
    expect(billing, contains("'localizedProductPrices'"));
    expect(billing, contains("'productIds': fallback.keys.toList()"));

    expect(scene, contains('import StoreKit'));
    expect(scene, contains('private final class HCVStorePriceLookup'));
    expect(scene, contains('product.priceLocale'));
    expect(scene, contains('call.method == "localizedProductPrices"'));
    expect(scene, contains('private func localizedProductPrices('));
  });
}
