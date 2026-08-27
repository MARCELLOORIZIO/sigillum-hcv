from pathlib import Path

path = Path('lib/commercial_gate.dart')
source = path.read_text(encoding='utf-8')

old_lookup = """      _productDisplayPrices = _products.isEmpty
          ? const {}
          : await CommercialBillingService.instance
              .localizedDisplayPrices(_products);
      _productDisplayPrices = _products.isEmpty
          ? const {}
          : await CommercialBillingService.instance.localizedDisplayPrices(
              _products,
            );
"""
new_lookup = """      _productDisplayPrices = _products.isEmpty
          ? const {}
          : await CommercialBillingService.instance
              .localizedDisplayPrices(_products);
"""
if source.count(old_lookup) != 1:
    raise SystemExit('expected exactly one duplicate localized price lookup block')
source = source.replace(old_lookup, new_lookup, 1)

old_button = """            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await CommercialBillingService.instance.purchase(product);
                    }),
              child: Text(
                '${_creatorPlanLabel(product)} — ${_productDisplayPrices[product.id] ?? product.price}',
              ),
            ),
"""
new_button = """            FilledButton(
              onPressed: _busy || !_productDisplayPrices.containsKey(product.id)
                  ? null
                  : () => _run(() async {
                      await CommercialBillingService.instance.purchase(product);
                    }),
              child: Text(
                '${_creatorPlanLabel(product)} — ${_productDisplayPrices[product.id] ?? '…'}',
              ),
            ),
"""
if source.count(old_button) != 1:
    raise SystemExit('expected exactly one Creator paywall product button block')
source = source.replace(old_button, new_button, 1)

if '?? product.price' in source:
    raise SystemExit('unlocalized ProductDetails.price fallback remains')
if source.count('localizedDisplayPrices(_products)') != 1:
    raise SystemExit('localized price lookup is not single-pass')

path.write_text(source, encoding='utf-8')
