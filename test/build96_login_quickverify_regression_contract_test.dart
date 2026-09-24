import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hidden Creator Home does not revalidate on picker resume', () {
    final source = File('lib/user_home_page.dart').readAsStringSync();
    final lifecycle = source.indexOf('void didChangeAppLifecycleState');
    final revalidate = source.indexOf(
      'Future.microtask(_revalidateCreatorEntitlement);',
      lifecycle,
    );
    final currentRoute = source.indexOf(
      'ModalRoute.of(context)?.isCurrent != true',
      lifecycle,
    );

    expect(lifecycle, greaterThanOrEqualTo(0));
    expect(currentRoute, greaterThan(lifecycle));
    expect(revalidate, greaterThan(currentRoute));
  });

  test('quick PHOTO negative path never escalates into deep Registry OCR', () {
    final source = File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _runPrecheck() async');
    final idDetected = source.indexOf(
      "_status = _v('idDetected');",
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(idDetected, greaterThan(start));
    final negativePath = source.substring(start, idDetected);

    expect(negativePath, contains('allowFocusedFallback: true'));
    expect(negativePath, isNot(contains('await _openRegistry();')));
  });

  test('ordinary login does not replay unfinished StoreKit transactions', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final start = gate.indexOf('Future<void> _routeAuthenticated({');
    final end = gate.indexOf('Future<void> _prepareBilling()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final route = gate.substring(start, end);

    expect(route, contains('billing = await _account.billingStatus();'));
    expect(route, isNot(contains('_recoverUnfinishedAppleTransactions()')));
  });

  test('status checks do one Apple verify while purchases keep retry window', () {
    final source = File('lib/commercial_account_service.dart').readAsStringSync();
    expect(source, contains('bool retryInactivePropagation = true'));
    expect(source, contains('retryInactivePropagation: false'));
    expect(source, contains('if (!retryInactivePropagation) return result;'));
  });
}
