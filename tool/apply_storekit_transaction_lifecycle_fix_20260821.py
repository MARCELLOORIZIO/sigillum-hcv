from pathlib import Path
import re

GATE = Path('lib/commercial_gate.dart')
if GATE.as_posix() != 'lib/commercial_gate.dart':
    raise RuntimeError('StoreKit lifecycle patch target escaped commercial allowlist')
source = GATE.read_text(encoding='utf-8')

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
        if (_busy) continue;
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

          // Delivery lifecycle and entitlement are intentionally separate:
          // once Apple authenticity is confirmed server-side, finish the
          // StoreKit transaction even when the subscription is expired or
          // revoked. This prevents unfinished transactions from blocking
          // restore/new purchase with storekit_duplicate_product_object.
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
print('StoreKit verified transaction lifecycle fixed; inactive entitlement remains blocked')
