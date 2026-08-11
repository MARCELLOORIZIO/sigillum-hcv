from pathlib import Path
import re

path = Path('lib/commercial_gate.dart')
source = path.read_text(encoding='utf-8')

source = source.replace("import 'package:shared_preferences/shared_preferences.dart';\n", '')
source = source.replace(
    "  static const _localPurchaseKey = 'sigillum_local_creator_purchase_observed_v1';\n",
    '',
)
source = source.replace('  bool _localPurchaseObserved = false;\n', '')

bootstrap_old = """      final prefs = await SharedPreferences.getInstance();
      _localPurchaseObserved = prefs.getBool(_localPurchaseKey) ?? false;
      final envelope = await _account.restoreAccount();
"""
bootstrap_new = """      final envelope = await _account.restoreAccount();
"""
if bootstrap_old in source:
    source = source.replace(bootstrap_old, bootstrap_new, 1)

paid_old = """    final serverActive = billing['status'] == 'active';
    final paid = serverActive ||
        (!_billingEnforced && _localPurchaseObserved) ||
        (!_billingEnforced && _prelaunchBillingBypass);
"""
paid_new = """    final serverStatus = billing['status']?.toString() ?? 'inactive';
    final serverActive = serverStatus == 'active' || serverStatus == 'grace';
    final paid = serverActive ||
        (!_billingEnforced && _prelaunchBillingBypass);
"""
if paid_old not in source and paid_new not in source:
    raise RuntimeError('billing route anchor missing')
source = source.replace(paid_old, paid_new, 1)

method_pattern = re.compile(
    r"  Future<void> _onPurchases\(List<PurchaseDetails> purchases\) async \{.*?\n  \}\n\n  Future<void> _run",
    re.S,
)
method_replacement = r'''  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
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
            _message = 'Verifica dell’abbonamento con App Store in corso…';
          });
        }
        try {
          final verified = await _account.verifyApplePurchase(
            productId: purchase.productID,
            transactionId: purchase.purchaseID,
            receiptData: purchase.verificationData.serverVerificationData,
          );
          final status = verified['status']?.toString() ?? 'inactive';
          if (verified['verified'] != true ||
              (status != 'active' && status != 'grace')) {
            throw const CommercialAccountException(
              'L’abbonamento non risulta attivo dopo la verifica App Store.',
            );
          }

          // StoreKit viene completato soltanto dopo la verifica server-side.
          await CommercialBillingService.instance.completeVerifiedPurchase(
            purchase,
          );

          if (!mounted) return;
          setState(() {
            _message = 'Abbonamento verificato.';
          });
          await _routeAuthenticated();
          return;
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _message = 'Verifica abbonamento non riuscita: $error';
          });
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      }

      if (purchase.status == PurchaseStatus.error && mounted) {
        setState(() {
          _message = purchase.error?.message ?? 'Acquisto non completato.';
        });
      }
    }
  }

  Future<void> _run'''
source, count = method_pattern.subn(method_replacement, source, count=1)
if count != 1 and 'verifyApplePurchase(' not in source:
    raise RuntimeError('purchase handler anchor missing')

for forbidden in [
    'SharedPreferences.getInstance()',
    '_localPurchaseKey',
    '_localPurchaseObserved',
    "setBool(_localPurchaseKey",
]:
    if forbidden in source:
        raise RuntimeError(f'local billing entitlement remains: {forbidden}')

required = [
    'verifyApplePurchase(',
    'purchase.verificationData.serverVerificationData',
    'purchase.purchaseID',
    'completeVerifiedPurchase(',
    "serverStatus == 'active' || serverStatus == 'grace'",
]
for token in required:
    if token not in source:
        raise RuntimeError(f'server-verified billing token missing: {token}')

verify_pos = source.index('verifyApplePurchase(')
complete_pos = source.index('completeVerifiedPurchase(', verify_pos)
if complete_pos <= verify_pos:
    raise RuntimeError('StoreKit completion precedes backend verification')

path.write_text(source, encoding='utf-8')
print('Server-verified App Store entitlement enforced in commercial gate')
