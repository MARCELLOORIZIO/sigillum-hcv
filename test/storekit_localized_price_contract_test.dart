import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Creator paywall resolves every price from StoreKit before display', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();

    final sk2Index = billing.indexOf('SK2Product.products(requestedIds)');
    final nativeIndex = billing.indexOf("'localizedProductPrices'");
    expect(sk2Index, greaterThanOrEqualTo(0));
    expect(nativeIndex, greaterThan(sk2Index));

    expect(billing, contains('product.displayPrice.trim()'));
    expect(billing, contains('final missingIds = requestedIds'));
    expect(billing, contains('final unresolved = requestedIds'));
    expect(
      billing,
      contains('Localized App Store price unavailable for:'),
    );

    // ProductDetails.price is allowed only for non-iOS platforms. The iOS path
    // must either resolve every StoreKit-localized price or fail closed before
    // the billing screen is shown, so a stale USD fallback cannot leak to UI.
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

    expect(gate, contains('localizedDisplayPrices(_products)'));
    expect(
      gate,
      contains(r'Account SIGILLUM: ${_email.text.trim()}'),
    );
  });
}
