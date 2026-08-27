import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native StoreKit1 bridge cannot leak a stale price into iOS paywall', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(billing, contains('SK2Product.products(requestedIds)'));
    expect(billing, contains('Storefront().countryCode()'));
    expect(billing, isNot(contains("'localizedProductPrices'")));
    expect(billing, isNot(contains("MethodChannel('hcv.media')")));

    // The native bridge may remain for backwards compatibility elsewhere, but
    // Creator paywall pricing must not call it after a StoreKit2 instability.
    expect(scene, contains('import StoreKit'));
    expect(scene, contains('private final class HCVStorePriceLookup'));
    expect(scene, contains('product.priceLocale'));
    expect(scene, contains('call.method == "localizedProductPrices"'));
    expect(scene, contains('private func localizedProductPrices('));
  });
}
