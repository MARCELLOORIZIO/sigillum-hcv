from pathlib import Path
import re

GATE = Path('lib/commercial_gate.dart')
BILLING = Path('lib/commercial_billing_service.dart')
for target in (GATE, BILLING):
    if target.as_posix() not in {
        'lib/commercial_gate.dart',
        'lib/commercial_billing_service.dart',
    }:
        raise RuntimeError('StoreKit lifecycle patch target escaped commercial allowlist')

# ---------------------------------------------------------------------------
# StoreKit2 direct unfinished-transaction recovery.
# ---------------------------------------------------------------------------
billing = BILLING.read_text(encoding='utf-8')

if "package:flutter/foundation.dart" not in billing:
    billing = billing.replace(
        "import 'package:in_app_purchase/in_app_purchase.dart';\n",
        "import 'package:flutter/foundation.dart';\n"
        "import 'package:in_app_purchase/in_app_purchase.dart';\n"
        "import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';\n",
        1,
    )
elif "package:in_app_purchase_storekit/store_kit_2_wrappers.dart" not in billing:
    billing = billing.replace(
        "import 'package:in_app_purchase/in_app_purchase.dart';\n",
        "import 'package:in_app_purchase/in_app_purchase.dart';\n"
        "import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';\n",
        1,
    )

model = r'''class CommercialUnfinishedAppleTransaction {
  const CommercialUnfinishedAppleTransaction({
    required this.transactionId,
    required this.productId,
    required this.receiptData,
  });

  final String transactionId;
  final String productId;
  final String receiptData;
}

'''
if 'class CommercialUnfinishedAppleTransaction' not in billing:
    billing = billing.replace(
        'class CommercialBillingService {',
        model + 'class CommercialBillingService {',
        1,
    )

method_anchor = "  Future<void> restore() => _iap.restorePurchases();\n\n"
methods = r'''  Future<List<CommercialUnfinishedAppleTransaction>>
      unfinishedAppleTransactions() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return const [];

    final transactions = await SK2Transaction.unfinishedTransactions();
    return transactions
        .where((transaction) => productIds.contains(transaction.productId))
        .where((transaction) => (transaction.receiptData ?? '').isNotEmpty)
        .map(
          (transaction) => CommercialUnfinishedAppleTransaction(
            transactionId: transaction.id,
            productId: transaction.productId,
            receiptData: transaction.receiptData!,
          ),
        )
        .toList(growable: false);
  }

  Future<void> finishUnfinishedAppleTransaction(
    String transactionId,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final numericId = int.tryParse(transactionId);
    if (numericId == null) {
      throw StateError('Identificativo transazione Apple non valido.');
    }
    await SK2Transaction.finish(numericId);
  }

'''
if 'unfinishedAppleTransactions()' not in billing:
    if method_anchor not in billing:
        raise RuntimeError('commercial billing restore anchor missing')
    billing = billing.replace(method_anchor, method_anchor + methods, 1)

for token in [
    'SK2Transaction.unfinishedTransactions()',
    'SK2Transaction.finish(numericId)',
    'CommercialUnfinishedAppleTransaction',
]:
    if token not in billing:
        raise RuntimeError(f'StoreKit2 recovery billing token missing: {token}')

BILLING.write_text(billing, encoding='utf-8')

# ---------------------------------------------------------------------------
# Gate: verify unfinished transactions server-side, finish only authentic
# Apple transactions, then evaluate entitlement separately.
# ---------------------------------------------------------------------------
source = GATE.read_text(encoding='utf-8')

recovery_helper = r'''  Future<bool> _recoverUnfinishedAppleTransactions() async {
    final unfinished = await CommercialBillingService.instance
        .unfinishedAppleTransactions();
    var entitlementActive = false;

    for (final transaction in unfinished) {
      final verified = await _account.verifyApplePurchase(
        productId: transaction.productId,
        transactionId: transaction.transactionId,
        receiptData: transaction.receiptData,
      );
      if (verified['verified'] != true) {
        throw CommercialAccountException(_t('subscriptionFailed'));
      }

      await CommercialBillingService.instance.finishUnfinishedAppleTransaction(
        transaction.transactionId,
      );

      final status = verified['status']?.toString() ?? 'inactive';
      if (status == 'active' || status == 'grace') {
        entitlementActive = true;
      }
    }

    return entitlementActive;
  }

'''
if 'Future<bool> _recoverUnfinishedAppleTransactions()' not in source:
    anchor = '  Future<void> _routeAuthenticated() async {'
    if anchor not in source:
        raise RuntimeError('authenticated route anchor missing')
    source = source.replace(anchor, recovery_helper + anchor, 1)

route_pattern = re.compile(
    r"    Map<String, dynamic> billing = const \{};\n"
    r"    try \{\n"
    r"      billing = await _account\.billingStatus\(\);\n"
    r"    \} catch \(_\) \{}\n"
    r"    final serverStatus = billing\['status'\]\?\.toString\(\) \?\? '';\n"
    r"    final serverActive = serverStatus == 'active' \|\| serverStatus == 'grace';\n\n"
    r"    if \(!serverActive\) \{\n"
    r"      await _prepareBilling\(\);\n"
    r"      if \(mounted\) setState\(\(\) => _stage = _GateStage\.billing\);\n"
    r"      return;\n"
    r"    \}",
    re.S,
)
route_replacement = r'''    Map<String, dynamic> billing = const {};
    try {
      billing = await _account.billingStatus();
    } catch (_) {}
    var serverStatus = billing['status']?.toString() ?? '';
    var serverActive = serverStatus == 'active' || serverStatus == 'grace';

    if (!serverActive) {
      try {
        final recoveredActive = await _recoverUnfinishedAppleTransactions();
        if (recoveredActive) {
          billing = await _account.billingStatus();
          serverStatus = billing['status']?.toString() ?? '';
          serverActive = serverStatus == 'active' || serverStatus == 'grace';
        }
      } catch (error) {
        _message = "${_t('subscriptionFailed')}: $error";
      }
    }

    if (!serverActive) {
      await _prepareBilling();
      if (mounted) setState(() => _stage = _GateStage.billing);
      return;
    }'''
source, route_count = route_pattern.subn(route_replacement, source, count=1)
if route_count != 1 and '_recoverUnfinishedAppleTransactions()' not in source:
    raise RuntimeError('billing route recovery anchor missing')

pattern = re.compile(
    r"  Future<void> _onPurchases\(List<PurchaseDetails> purchases\) async \{.*?\n  \}\n\n  Future<void> _run",
    re.S,
)

replacement = r'''  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!CommercialBillingService.productIds.contains(purchase.productID)) {
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (mounted) {
          setState(() {
            _busy = true;
            _message = _t('checkingSubscription');
          });
        }
        try {
          final verified = await _account.verifyApplePurchase(
            productId: purchase.productID,
            transactionId: purchase.purchaseID,
            receiptData: purchase.verificationData.serverVerificationData,
          );
          if (verified['verified'] != true) {
            throw CommercialAccountException(_t('subscriptionFailed'));
          }

          final status = verified['status']?.toString() ?? 'inactive';

          // StoreKit delivery lifecycle and entitlement are separate. Once
          // Apple authenticity is confirmed server-side, finish the StoreKit
          // transaction even when the subscription is expired or revoked.
          await CommercialBillingService.instance.completeVerifiedPurchase(
            purchase,
          );

          final entitlementActive = status == 'active' || status == 'grace';
          if (!entitlementActive) {
            if (mounted) {
              setState(() {
                _message = _t('subscriptionInactive');
              });
            }
            continue;
          }

          if (!mounted) return;
          setState(() {
            _message = _t('subscriptionVerified');
          });
          await _routeAuthenticated();
          return;
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _message = "${_t('subscriptionFailed')}: $error";
          });
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      }

      if (purchase.status == PurchaseStatus.error && mounted) {
        setState(() {
          _message = purchase.error?.message ?? _t('purchaseFailed');
        });
      }
    }
  }

  Future<void> _run'''

source, count = pattern.subn(replacement, source, count=1)
if count != 1:
    if 'final entitlementActive = status ==' not in source:
        raise RuntimeError('StoreKit lifecycle purchase-handler anchor missing')

required = [
    "if (verified['verified'] != true)",
    'completeVerifiedPurchase(',
    "final entitlementActive = status == 'active' || status == 'grace';",
    "_message = _t('subscriptionInactive');",
    'await _routeAuthenticated();',
    'Future<bool> _recoverUnfinishedAppleTransactions()',
    '.unfinishedAppleTransactions()',
    'finishUnfinishedAppleTransaction(',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'StoreKit lifecycle token missing: {token}')

verify_pos = source.index("if (verified['verified'] != true)")
complete_pos = source.index('completeVerifiedPurchase(', verify_pos)
entitlement_pos = source.index('final entitlementActive = status ==', complete_pos)
route_pos = source.index('await _routeAuthenticated();', entitlement_pos)
if not (verify_pos < complete_pos < entitlement_pos < route_pos):
    raise RuntimeError('StoreKit authenticity/completion/entitlement order invalid')

GATE.write_text(source, encoding='utf-8')
print('StoreKit2 unfinished transactions recovered server-side; inactive entitlement remains blocked')
