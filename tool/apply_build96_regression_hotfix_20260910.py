from pathlib import Path


def replace_once(path: str, old: str, new: str, marker: str) -> None:
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    if old in source:
        file.write_text(source.replace(old, new, 1), encoding='utf-8')
        print(f'patched {path}: {marker}')
        return
    if marker in source:
        print(f'already patched {path}: {marker}')
        return
    raise RuntimeError(f'cannot find expected source block in {path}: {marker}')


# 1) BUILD96 regression: UserHomePage remained a WidgetsBindingObserver while
# hidden behind picker/import/quick-verify routes. iOS resume therefore started
# an Apple/server entitlement reconciliation in parallel with media precheck.
replace_once(
    'lib/user_home_page.dart',
    """  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.microtask(_revalidateCreatorEntitlement);
    }
  }
""",
    """  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    // A route kept underneath the iOS photo/video picker also receives app
    // lifecycle callbacks. Revalidate only when Creator Home is actually the
    // visible route; otherwise the hidden page would compete with OCR/media
    // work as soon as the picker returns.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Future.microtask(_revalidateCreatorEntitlement);
  }
""",
    'ModalRoute.of(context)?.isCurrent != true',
)


# 2) Quick negative PHOTO must actually be quick. The existing helper was
# bounded, but _runPrecheck immediately opened RegistryVerifyPage on a miss,
# which started the deeper multi-crop OCR anyway. Keep that deeper recovery in
# the explicit Registry verifier; do not force it on every ordinary photo.
replace_once(
    'lib/quick_hcv_media_gate_page.dart',
    """      if (isPhoto) {
        // A single native OCR miss must not classify a certified photo as
        // uncertified. Still images get one focused top-crop fallback first.
        // If that fast path is inconclusive, RegistryVerifyPage performs the
        // existing deeper multi-crop OCR recovery before any final verdict.
        detectedId = await _ocrImage(widget.path, allowFocusedFallback: true);
        if (!mounted) return;
        if (detectedId == null || detectedId.isEmpty) {
          await _openRegistry();
          return;
        }
      } else if (lower.endsWith('.mp4') ||
""",
    """      if (isPhoto) {
        // Quick verification is deliberately bounded: one full-image OCR pass
        // plus one focused top-crop fallback. If neither finds an HCV-ID, stop
        // here. The dedicated Registry verifier still owns the deeper
        // multi-crop recovery path when the user explicitly requests it.
        detectedId = await _ocrImage(widget.path, allowFocusedFallback: true);
      } else if (lower.endsWith('.mp4') ||
""",
    'Quick verification is deliberately bounded',
)


# 3) Login/routing latency. billingStatus already checks current StoreKit
# entitlement and performs account-bound server reconciliation. Running every
# unfinished StoreKit transaction again before showing the paywall duplicated
# verification and could keep the login spinner alive for a very long time.
replace_once(
    'lib/commercial_gate.dart',
    """    if (!serverActive) {
      try {
        final recoveredActive = await _recoverUnfinishedAppleTransactions();
        if (recoveredActive) {
          billing = await _account.billingStatus();
          serverStatus = billing['status']?.toString() ?? '';
          serverActive = serverStatus == 'active' || serverStatus == 'grace';
        }
      } catch (error) {
        _message = \"${_t('subscriptionFailed')}: $error\";
      }
    }

""",
    """    // billingStatus() already performs current-entitlement verification
    // and an account-bound Apple server reconcile. Do not replay unfinished
    // StoreKit transactions during ordinary login: stale queue cleanup belongs
    // to the purchase/restore paths and must not hold the login spinner open.

""",
    'stale queue cleanup belongs',
)


# 4) Generic billing status must not use the post-purchase propagation retry
# window. Those retries are useful immediately after a purchase, but on login
# or foreground revalidation they turn an expired/inactive Sandbox transaction
# into many repeated server calls before the final reconcile can run.
replace_once(
    'lib/commercial_account_service.dart',
    """        final verified = await verifyApplePurchase(
          productId: entitlement.productId,
          transactionId: entitlement.transactionId,
          receiptData: entitlement.receiptData,
        );
""",
    """        final verified = await verifyApplePurchase(
          productId: entitlement.productId,
          transactionId: entitlement.transactionId,
          receiptData: entitlement.receiptData,
          retryInactivePropagation: false,
        );
""",
    'retryInactivePropagation: false',
)

replace_once(
    'lib/commercial_account_service.dart',
    """  Future<Map<String, dynamic>> verifyApplePurchase({
    required String productId,
    String? transactionId,
    required String receiptData,
  }) async {
""",
    """  Future<Map<String, dynamic>> verifyApplePurchase({
    required String productId,
    String? transactionId,
    required String receiptData,
    bool retryInactivePropagation = true,
  }) async {
""",
    'bool retryInactivePropagation = true',
)

replace_once(
    'lib/commercial_account_service.dart',
    """        if (result['verified'] == true &&
            (status == 'active' || status == 'grace')) {
          return result;
        }
""",
    """        if (result['verified'] == true &&
            (status == 'active' || status == 'grace')) {
          return result;
        }
        if (!retryInactivePropagation) return result;
""",
    'if (!retryInactivePropagation) return result;',
)


# Regression contract: protect the complete paths, not just helper methods.
test_path = Path('test/build96_login_quickverify_regression_contract_test.dart')
test_path.write_text("""import 'dart:io';

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
""", encoding='utf-8')
print('wrote regression contract test')
