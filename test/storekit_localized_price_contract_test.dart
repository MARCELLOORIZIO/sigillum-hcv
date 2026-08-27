import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Creator paywall resolves every price from stable StoreKit2 storefront', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();

    expect(billing, contains('Storefront().countryCode()'));
    expect(billing, contains('SK2Product.products(requestedIds)'));
    expect(billing, contains('product.displayPrice.trim()'));
    expect(billing, contains('mapEquals(previousComplete, resolved)'));
    expect(billing, contains('previousStorefront == storefront'));
    expect(
      billing,
      contains('Stable localized App Store price unavailable for current storefront.'),
    );

    // ProductDetails.price is allowed only for non-iOS platforms. The iOS path
    // must either resolve a stable complete StoreKit2 snapshot or fail closed;
    // neither ProductDetails nor the legacy StoreKit1 bridge may leak USD.
    final iosBlockStart = billing.indexOf(
      'if (defaultTargetPlatform != TargetPlatform.iOS)',
    );
    final storeKitStart = billing.indexOf('final requestedIds =', iosBlockStart);
    expect(iosBlockStart, greaterThanOrEqualTo(0));
    expect(storeKitStart, greaterThan(iosBlockStart));
    expect(
      billing.substring(storeKitStart),
      isNot(contains('product.id: product.price')),
    );
    expect(
      billing.substring(storeKitStart),
      isNot(contains("'localizedProductPrices'")),
    );

    expect(gate, contains('localizedDisplayPrices(_products)'));
    expect(
      gate,
      contains(r'Account SIGILLUM: ${_email.text.trim()}'),
    );
  });
}
