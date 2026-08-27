import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Creator paywall storefront price contract', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final billing =
        File('lib/commercial_billing_service.dart').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    test('paywall never falls back to ProductDetails.price', () {
      expect(gate, isNot(contains('?? product.price')));
      expect(
        gate,
        contains('!_productDisplayPrices.containsKey(product.id)'),
      );
    });

    test('billing preparation performs one localized price lookup', () {
      final start = gate.indexOf('Future<void> _prepareBilling() async');
      final end = gate.indexOf('Future<void> _onPurchases(', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final block = gate.substring(start, end);
      expect(
        RegExp(r'localizedDisplayPrices\(_products\)').allMatches(block).length,
        1,
      );
    });

    test('iOS price comes from native StoreKit2 current storefront', () {
      expect(billing, contains("MethodChannel('hcv.storekit2')"));
      expect(
        billing,
        contains("'localizedProductPrices'"),
      );
      expect(
        billing,
        isNot(contains("MethodChannel('hcv.media')")),
      );
      expect(appDelegate, contains('import StoreKit'));
      expect(appDelegate, contains('StoreKit.Product.products(for: productIds)'));
      expect(appDelegate, contains('prices[product.id] = product.displayPrice'));
      expect(appDelegate, contains('name: "hcv.storekit2"'));
    });
  });
}
