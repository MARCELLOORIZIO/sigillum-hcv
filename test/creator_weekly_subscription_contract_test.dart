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
    expect(
      billing,
      contains(
        'productIds = {weeklyProductId, monthlyProductId, annualProductId}',
      ),
    );
    expect(billing, contains('static int productRank(String productId)'));
    expect(
      billing,
      contains('productRank(a.id).compareTo(productRank(b.id))'),
    );

    expect(gate, contains("'weekly': '7 GIORNI'"));
    expect(gate, contains("'weekly': '7 DAYS'"));
    expect(gate, contains("'weekly': '7 DÍAS'"));
    expect(gate, contains("'weekly': '7 ДНЕЙ'"));
    expect(gate, contains('CommercialBillingService.weeklyProductId'));
    expect(gate, contains("return _t('weekly');"));
    expect(gate, contains('_creatorPlanLabel(product)'));

    // Price itself remains Apple-localized; no euro/dollar amount is hardcoded.
    expect(gate, contains('_productDisplayPrices[product.id] ?? product.price'));
    expect(gate, isNot(contains('€2,99')));
    expect(gate, isNot(contains(r'$2.99')));
  });
}
