from pathlib import Path
import re

path = Path('lib/commercial_gate.dart')
source = path.read_text(encoding='utf-8')

source = re.sub(
    r"^import 'package:shared_preferences/shared_preferences\.dart';\s*\n",
    '',
    source,
    flags=re.M,
)
source = re.sub(r'^\s*static const _localPurchaseKey\s*=.*?;\s*\n', '', source, flags=re.M)
source = re.sub(r'^\s*bool _localPurchaseObserved\s*=.*?;\s*\n', '', source, flags=re.M)
source = re.sub(r'^\s*final prefs = await SharedPreferences\.getInstance\(\);\s*\n', '', source, flags=re.M)
source = re.sub(r'^\s*_localPurchaseObserved\s*=\s*prefs\.getBool\(_localPurchaseKey\)\s*\?\?\s*false;\s*\n', '', source, flags=re.M)

billing_pattern = re.compile(
    r"    _billingEnforced = billing\['enforced'\] == true;\s*\n"
    r".*?"
    r"\n    if \(!paid\) \{",
    re.S,
)
billing_replacement = """    _billingEnforced = billing['enforced'] == true;
    final serverStatus = billing['status']?.toString() ?? 'inactive';
    final serverActive = serverStatus == 'active' || serverStatus == 'grace';
    final paid = serverActive ||
        (!_billingEnforced && _prelaunchBillingBypass);

    if (!paid) {"""
source, billing_count = billing_pattern.subn(billing_replacement, source, count=1)
if billing_count != 1 and "serverStatus == 'active' || serverStatus == 'grace'" not in source:
    raise RuntimeError('billing route anchor missing')

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

# Remove any residual local-entitlement statements left by formatting variants.
source = re.sub(r'^.*_localPurchaseObserved.*\n', '', source, flags=re.M)
source = re.sub(r'^.*_localPurchaseKey.*\n', '', source, flags=re.M)
source = re.sub(r'^.*SharedPreferences\.getInstance\(\).*\n', '', source, flags=re.M)

for forbidden in [
    'SharedPreferences.getInstance()',
    '_localPurchaseKey',
    '_localPurchaseObserved',
    'setBool(',
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

extra_patch = Path('tool/apply_prelaunch_ux_kyc_identity_fix.py')
if not extra_patch.exists():
    raise RuntimeError('commercial UX/KYC identity patch missing')
exec(
    compile(extra_patch.read_text(encoding='utf-8'), str(extra_patch), 'exec'),
    {'__name__': '__main__'},
)

refinement_patch = Path('tool/apply_prelaunch_ui_camera_refinement.py')
if not refinement_patch.exists():
    raise RuntimeError('prelaunch UI/camera refinement patch missing')
exec(
    compile(refinement_patch.read_text(encoding='utf-8'), str(refinement_patch), 'exec'),
    {'__name__': '__main__'},
)

product_refinement_patch = Path('tool/apply_prelaunch_product_refinement_20260817.py')
if not product_refinement_patch.exists():
    raise RuntimeError('prelaunch account/text/transcription refinement patch missing')
exec(
    compile(
        product_refinement_patch.read_text(encoding='utf-8'),
        str(product_refinement_patch),
        'exec',
    ),
    {'__name__': '__main__'},
)

product_contract_fix = Path('tool/apply_prelaunch_product_refinement_contract_fix.py')
if not product_contract_fix.exists():
    raise RuntimeError('prelaunch product contract/routing fix missing')
exec(
    compile(
        product_contract_fix.read_text(encoding='utf-8'),
        str(product_contract_fix),
        'exec',
    ),
    {'__name__': '__main__'},
)
