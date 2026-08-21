import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreKit transaction lifecycle', () {
    final patch = File(
      'tool/apply_storekit_transaction_lifecycle_fix_20260821.py',
    ).readAsStringSync();
    final compileGuard = File(
      'tool/apply_prelaunch_legal_localization_compile_guard_20260818.py',
    ).readAsStringSync();

    test('backend authenticity is required before StoreKit completion', () {
      final verifyIndex = patch.indexOf("if (verified['verified'] != true)");
      final completeIndex = patch.indexOf(
        'completeVerifiedPurchase(',
        verifyIndex,
      );
      expect(verifyIndex, greaterThanOrEqualTo(0));
      expect(completeIndex, greaterThan(verifyIndex));
    });

    test('verified inactive transaction is finished before entitlement check', () {
      final completeIndex = patch.indexOf('completeVerifiedPurchase(');
      final entitlementIndex = patch.indexOf(
        'final entitlementActive = status ==',
        completeIndex,
      );
      final inactiveIndex = patch.indexOf(
        "_message = _t('subscriptionInactive');",
        entitlementIndex,
      );
      final routeIndex = patch.indexOf(
        'await _routeAuthenticated();',
        entitlementIndex,
      );

      expect(completeIndex, greaterThanOrEqualTo(0));
      expect(entitlementIndex, greaterThan(completeIndex));
      expect(inactiveIndex, greaterThan(entitlementIndex));
      expect(routeIndex, greaterThan(inactiveIndex));
      expect(patch, contains('if (!entitlementActive)'));
      expect(patch, contains('continue;'));
    });

    test('build-time commercial chain always applies lifecycle fix', () {
      expect(
        compileGuard,
        contains('apply_storekit_transaction_lifecycle_fix_20260821.py'),
      );
    });

    test('billing lifecycle patch cannot write frozen HCV files', () {
      expect(patch, isNot(contains("GATE = Path('lib/camera_page.dart')")));
      expect(patch, isNot(contains("GATE = Path('lib/text_cert_page.dart')")));
      expect(patch, isNot(contains("GATE = Path('lib/hcv_engine.dart')")));
      expect(patch, isNot(contains("GATE = Path('lib/hcv_package.dart')")));
    });
  });
}
