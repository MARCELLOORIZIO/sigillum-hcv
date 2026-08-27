import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Creator commercial ladder includes localized 7-day plan', () {
    final billing =
        File('lib/commercial_billing_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();

    expect(
      billing,
      contains("weeklyProductId = 'com.sigillum.hcv.creator.weekly'"),
    );
    final productSet = RegExp(
      r'static const productIds\s*=\s*\{[^}]*weeklyProductId[^}]*monthlyProductId[^}]*annualProductId[^}]*\}',
      dotAll: true,
    );
    expect(productSet.hasMatch(billing), isTrue);
    expect(billing, contains('static int productRank(String productId)'));
    expect(billing, contains('productRank(a.id)'));
    expect(billing, contains('productRank(b.id)'));

    expect(gate, contains("'weekly': '7 GIORNI'"));
    expect(gate, contains("'weekly': '7 DAYS'"));
    expect(gate, contains("'weekly': '7 DÍAS'"));
    expect(gate, contains("'weekly': '7 ДНЕЙ'"));
    expect(gate, contains('CommercialBillingService.weeklyProductId'));
    expect(gate, contains("return _t('weekly');"));
    expect(gate, contains('_creatorPlanLabel(product)'));

    // iOS price is displayed only after a localized StoreKit snapshot exists;
    // ProductDetails.price must never be a visible fallback.
    expect(gate, contains('_productDisplayPrices[product.id]'));
    expect(gate, contains("_productDisplayPrices[product.id] ?? '…'"));
    expect(gate, isNot(contains('_productDisplayPrices[product.id] ?? product.price')));
    expect(gate, isNot(contains('€2,99')));
    expect(gate, isNot(contains(r'$2.99')));
  });
}
