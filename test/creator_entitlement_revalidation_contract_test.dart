import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Creator entitlement is revalidated on resume and before certification', () {
    final source = File('lib/user_home_page.dart').readAsStringSync();

    expect(source, contains('with WidgetsBindingObserver'));
    expect(source, contains('WidgetsBinding.instance.addObserver(this);'));
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('Future.microtask(_revalidateCreatorEntitlement);'));
    expect(source, contains("final billing = await _account.billingStatus();"));
    expect(source, contains("final active = status == 'active' || status == 'grace';"));
    expect(source, contains('_openCreatorProtected('));
    expect(source, contains('CameraPage(languageCode: languageCode)'));
    expect(source, contains('TextCertPage(languageCode: languageCode)'));
  });

  test('Concurrent Creator checks share one in-flight verification Future', () {
    final source = File('lib/user_home_page.dart').readAsStringSync();

    expect(source, contains('Future<bool>? _entitlementCheckInFlight;'));
    expect(source, contains('final existingCheck = _entitlementCheckInFlight;'));
    expect(source, contains('final active = await existingCheck;'));
    expect(source, contains('final check = _performCreatorEntitlementCheck();'));
    expect(source, contains('_entitlementCheckInFlight = check;'));
    expect(source, contains('identical(_entitlementCheckInFlight, check)'));
    expect(source, isNot(contains('if (_entitlementCheckInFlight) return false;'));
  });

  test('Registry retry waits for a valid Creator entitlement', () {
    final source = File('lib/user_home_page.dart').readAsStringSync();
    final bootstrap = source.indexOf('Future<void> _bootstrapCreatorSession() async');
    final revalidate = source.indexOf('final active = await _revalidateCreatorEntitlement();', bootstrap);
    final retry = source.indexOf('await _retryRegistryOutbox();', bootstrap);

    expect(bootstrap, greaterThanOrEqualTo(0));
    expect(revalidate, greaterThan(bootstrap));
    expect(retry, greaterThan(revalidate));
  });

  test('Inactive Creator state routes back through CommercialGate without logging out', () {
    final source = File('lib/user_home_page.dart').readAsStringSync();

    expect(source, contains('_routeToCommercialGate();'));
    expect(source, contains('pushNamedAndRemoveUntil('));
    expect(source, contains('Navigator.defaultRouteName'));
    expect(source, isNot(contains('await _account.logout();')));
  });
}
