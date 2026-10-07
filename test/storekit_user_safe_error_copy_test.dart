import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commercial gate never exposes raw StoreKit or exception text', () {
    final source = File('lib/commercial_gate.dart').readAsStringSync();

    expect(
      source,
      isNot(contains(r"${_t('subscriptionFailed')}: $error")),
    );
    expect(source, isNot(contains('purchase.error?.message')));
    expect(
      source,
      isNot(contains(r"${_t('storeError')}: $error")),
    );
    expect(source, isNot(contains('return error.toString();')));
    expect(source, contains('String _localizedSubscriptionError(Object error)'));
    expect(source, contains("'APPLE_SUBSCRIPTION_ALREADY_LINKED'"));
  });

  test('three canonical subscription product ids remain unchanged', () {
    final source =
        File('lib/commercial_billing_service.dart').readAsStringSync();

    expect(source, contains("'com.sigillum.hcv.creator.weekly'"));
    expect(source, contains("'com.sigillum.hcv.creator.monthly'"));
    expect(source, contains("'com.sigillum.hcv.creator.annual'"));
  });
}
