import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Registry 402 is a non-retryable subscription state retained in outbox', () {
    final source = File('lib/hcv_registry_service.dart').readAsStringSync();
    expect(source, contains('subscriptionInactive,'));
    expect(source, contains('res.statusCode == 402'));
    expect(source, contains('HCVRegistryFailureKind.subscriptionInactive'));
    expect(source, contains('subscriptionInactivePaths.add(path)'));
    expect(source, contains('subscriptionInactivePaths: subscriptionInactivePaths'));

    final retryGetter = source.substring(
      source.indexOf('bool get isRetryable'),
      source.indexOf('@override', source.indexOf('bool get isRetryable')),
    );
    expect(retryGetter, isNot(contains('subscriptionInactive')));
  });

  test('camera and text route subscription Registry rejection to billing', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final text = File('lib/text_cert_page.dart').readAsStringSync();
    expect(camera, contains('report.subscriptionInactivePaths.contains(currentPath)'));
    expect(camera, contains('await _handleSubscriptionInactive()'));
    expect(text, contains('HCVRegistryFailureKind.subscriptionInactive'));
    expect(text, contains('await _routeToSubscription()'));
  });
}
