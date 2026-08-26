import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Creator paywall uses StoreKit2 localized display price', () {
    final billing = File('lib/commercial_billing_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();

    expect(
      billing,
      contains('SK2Product.products(fallback.keys.toList())'),
    );
    expect(
      billing,
      contains('product.displayPrice.trim()'),
    );
    expect(
      gate,
      contains('localizedDisplayPrices(_products)'),
    );
    expect(
      gate,
      contains('_productDisplayPrices[product.id] ?? product.price'),
    );
    expect(
      gate,
      contains('Account SIGILLUM: ${_email.text.trim()}'),
    );
  });
}
