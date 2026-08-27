import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native StoreKit price bridge remains a fallback for missing SK2 prices', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(billing, contains("MethodChannel('hcv.media')"));
    expect(billing, contains('final missingIds = requestedIds'));
    expect(billing, contains("'localizedProductPrices'"));
    expect(billing, contains("'productIds': missingIds"));

    final sk2Index = billing.indexOf('SK2Product.products(requestedIds)');
    final nativeIndex = billing.indexOf("'localizedProductPrices'");
    expect(sk2Index, greaterThanOrEqualTo(0));
    expect(nativeIndex, greaterThan(sk2Index));

    expect(scene, contains('import StoreKit'));
    expect(scene, contains('private final class HCVStorePriceLookup'));
    expect(scene, contains('product.priceLocale'));
    expect(scene, contains('call.method == "localizedProductPrices"'));
    expect(scene, contains('private func localizedProductPrices('));
  });
}
