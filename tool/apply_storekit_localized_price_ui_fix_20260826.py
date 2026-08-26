from pathlib import Path
import re

BILLING = Path('lib/commercial_billing_service.dart')
GATE = Path('lib/commercial_gate.dart')

billing = BILLING.read_text(encoding='utf-8')

# StoreKit 2 Product.displayPrice is Apple's localized display string and is
# the authoritative UI price. Keep ProductDetails.price only as a fallback for
# non-iOS platforms or a temporary StoreKit query failure.
storekit_import = "import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';\n"
if storekit_import not in billing:
    anchor = "import 'package:in_app_purchase/in_app_purchase.dart';\n"
    if anchor not in billing:
        raise RuntimeError('in_app_purchase import anchor missing')
    billing = billing.replace(anchor, anchor + storekit_import, 1)

wrappers_import = "import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';\n"
if wrappers_import not in billing:
    anchor = storekit_import
    if anchor not in billing:
        raise RuntimeError('StoreKit package import anchor missing')
    billing = billing.replace(anchor, anchor + wrappers_import, 1)

foundation_import = "import 'package:flutter/foundation.dart';\n"
if foundation_import not in billing:
    anchor = "import 'dart:async';\n\n"
    if anchor not in billing:
        raise RuntimeError('billing import boundary missing')
    billing = billing.replace(anchor, anchor + foundation_import, 1)

localized_method = r'''  Future<Map<String, String>> localizedDisplayPrices(
    Iterable<ProductDetails> products,
  ) async {
    final fallback = <String, String>{
      for (final product in products) product.id: product.price,
    };
    if (defaultTargetPlatform != TargetPlatform.iOS || fallback.isEmpty) {
      return fallback;
    }

    try {
      final storeKitProducts = await SK2Product.products(fallback.keys.toList());
      for (final product in storeKitProducts) {
        final displayPrice = product.displayPrice.trim();
        if (displayPrice.isNotEmpty) {
          fallback[product.id] = displayPrice;
        }
      }
    } catch (_) {
      // A price-rendering refresh must never block the purchase flow. The
      // generic ProductDetails price remains available as a safe fallback.
    }
    return fallback;
  }

'''
if 'Future<Map<String, String>> localizedDisplayPrices(' not in billing:
    anchor = '  void startListening() {\n'
    if anchor not in billing:
        raise RuntimeError('billing startListening anchor missing')
    billing = billing.replace(anchor, localized_method + anchor, 1)

for token in [
    "in_app_purchase_storekit/in_app_purchase_storekit.dart",
    'SK2Product.products(fallback.keys.toList())',
    'product.displayPrice.trim()',
    'Future<Map<String, String>> localizedDisplayPrices(',
]:
    if token not in billing:
        raise RuntimeError(f'localized StoreKit price contract missing: {token}')

BILLING.write_text(billing, encoding='utf-8')


gate = GATE.read_text(encoding='utf-8')

if 'Map<String, String> _productDisplayPrices = const {};' not in gate:
    anchor = '  List<ProductDetails> _products = const [];\n'
    if anchor not in gate:
        raise RuntimeError('commercial product state anchor missing')
    gate = gate.replace(
        anchor,
        anchor + '  Map<String, String> _productDisplayPrices = const {};\n',
        1,
    )

prepare_pattern = re.compile(
    r"  Future<void> _prepareBilling\(\) async \{.*?\n  \}\n\n  Future<void> _onPurchases",
    re.S,
)
match = prepare_pattern.search(gate)
if not match:
    raise RuntimeError('commercial prepareBilling semantic region missing')
prepare = match.group(0)
if 'localizedDisplayPrices(_products)' not in prepare:
    old = '''      _products = _storeAvailable
          ? await CommercialBillingService.instance.loadProducts()
          : const [];
'''
    new = '''      _products = _storeAvailable
          ? await CommercialBillingService.instance.loadProducts()
          : const [];
      _productDisplayPrices = _products.isEmpty
          ? const {}
          : await CommercialBillingService.instance
              .localizedDisplayPrices(_products);
'''
    if old not in prepare:
        raise RuntimeError('commercial product loading anchor missing')
    prepare = prepare.replace(old, new, 1)
    prepare = prepare.replace(
        "      _products = const [];\n    }\n  }\n\n  Future<void> _onPurchases",
        "      _products = const [];\n      _productDisplayPrices = const {};\n    }\n  }\n\n  Future<void> _onPurchases",
        1,
    )
    gate = gate[:match.start()] + prepare + gate[match.end():]

old_price = "${product.id == CommercialBillingService.annualProductId ? 'ANNUALE' : 'MENSILE'} — ${product.price}"
new_price = "${product.id == CommercialBillingService.annualProductId ? 'ANNUALE' : 'MENSILE'} — ${_productDisplayPrices[product.id] ?? product.price}"
if new_price not in gate:
    if old_price not in gate:
        raise RuntimeError('commercial billing visible-price anchor missing')
    gate = gate.replace(old_price, new_price, 1)

# Make the two identities explicit inside SIGILLUM. The Apple purchase sheet
# is owned by StoreKit and may legitimately show a different App Store account.
account_marker = "Account SIGILLUM: ${_email.text.trim()}"
if account_marker not in gate:
    anchor = "        const SizedBox(height: 18),\n        if (_products.isEmpty)\n"
    insert = '''        const SizedBox(height: 14),
        if (_email.text.trim().isNotEmpty)
          Text(
            'Account SIGILLUM: ${_email.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SigillumTheme.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 12),
        if (_products.isEmpty)
'''
    if anchor not in gate:
        raise RuntimeError('commercial billing account-label anchor missing')
    gate = gate.replace(anchor, insert, 1)

# Reset any previously resolved storefront display price when the visible
# SIGILLUM session is cleared.
gate = gate.replace(
    '      _products = const [];\n      _message = \'\';',
    '      _products = const [];\n      _productDisplayPrices = const {};\n      _message = \'\';',
)

for token in [
    'Map<String, String> _productDisplayPrices = const {};',
    'localizedDisplayPrices(_products)',
    '_productDisplayPrices[product.id] ?? product.price',
    'Account SIGILLUM: ${_email.text.trim()}',
]:
    if token not in gate:
        raise RuntimeError(f'commercial localized-price UI contract missing: {token}')

GATE.write_text(gate, encoding='utf-8')
print('StoreKit2 localized display price and explicit SIGILLUM account UI finalized')
