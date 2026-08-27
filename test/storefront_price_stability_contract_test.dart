import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS paywall confirms storefront and stable StoreKit2 price snapshot', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();

    expect(billing, contains('Storefront().countryCode()'));
    expect(billing, contains('SK2Product.products(requestedIds)'));
    expect(billing, contains('mapEquals(previousComplete, resolved)'));
    expect(billing, contains('previousStorefront == storefront'));
    expect(billing, contains('_storefrontPriceRetryDelays'));
    expect(
      billing,
      contains("throw StateError(\n      'Stable localized App Store price unavailable"),
    );
  });
}
