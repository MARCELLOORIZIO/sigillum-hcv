from pathlib import Path
import re

BILLING = Path('lib/commercial_billing_service.dart')
GATE = Path('lib/commercial_gate.dart')

billing = BILLING.read_text(encoding='utf-8')

weekly_const = "  static const weeklyProductId = 'com.sigillum.hcv.creator.weekly';\n"
if weekly_const not in billing:
    anchor = "  static const monthlyProductId = 'com.sigillum.hcv.creator.monthly';\n"
    if anchor not in billing:
        raise RuntimeError('monthly product-id anchor missing')
    billing = billing.replace(anchor, weekly_const + anchor, 1)

# Normalize the accepted Creator product set semantically. dart format expands
# this set across lines, so never depend on its byte layout.
product_ids_pattern = re.compile(
    r"  static const productIds\s*=\s*\{.*?\};",
    re.S,
)
product_ids_match = product_ids_pattern.search(billing)
if not product_ids_match:
    raise RuntimeError('Creator productIds semantic region missing')
product_ids_block = '''  static const productIds = {
    weeklyProductId,
    monthlyProductId,
    annualProductId,
  };'''
billing = (
    billing[:product_ids_match.start()]
    + product_ids_block
    + billing[product_ids_match.end():]
)

# App Store does not guarantee ProductDetails ordering. Keep the intended sales
# ladder stable regardless of localized price/currency: 7 days, monthly, annual.
rank_method = '''  static int productRank(String productId) {
    if (productId == weeklyProductId) return 0;
    if (productId == monthlyProductId) return 1;
    if (productId == annualProductId) return 2;
    return 99;
  }

'''
if 'static int productRank(String productId)' not in billing:
    anchor = '  final InAppPurchase _iap = InAppPurchase.instance;\n'
    if anchor not in billing:
        raise RuntimeError('billing service field anchor missing')
    billing = billing.replace(anchor, rank_method + anchor, 1)

if not (
    'productRank(a.id)' in billing
    and 'productRank(b.id)' in billing
):
    raw_sort_pattern = re.compile(
        r"\.\.sort\(\(a, b\)\s*=>\s*a\.rawPrice\.compareTo\(b\.rawPrice\)\);"
    )
    billing, sort_count = raw_sort_pattern.subn(
        '..sort((a, b) => productRank(a.id).compareTo(productRank(b.id)));',
        billing,
        count=1,
    )
    if sort_count != 1:
        raise RuntimeError('product ordering semantic anchor missing')

for token in [
    "weeklyProductId = 'com.sigillum.hcv.creator.weekly'",
    'static const productIds',
    'weeklyProductId,',
    'monthlyProductId,',
    'annualProductId,',
    'static int productRank(String productId)',
    'productRank(a.id)',
    'productRank(b.id)',
]:
    if token not in billing:
        raise RuntimeError(f'weekly billing contract missing: {token}')

BILLING.write_text(billing, encoding='utf-8')


gate = GATE.read_text(encoding='utf-8')

# The commercial localization patch has already materialized _commercialGateCopy
# before this finalizer runs. Add the weekly label to all four supported locales.
weekly_copy = {
    "'monthly': 'MENSILE',": "'monthly': 'MENSILE',\n    'weekly': '7 GIORNI',",
    "'monthly': 'MONTHLY',": "'monthly': 'MONTHLY',\n    'weekly': '7 DAYS',",
    "'monthly': 'MENSUAL',": "'monthly': 'MENSUAL',\n    'weekly': '7 DÍAS',",
    "'monthly': 'МЕСЯЧНАЯ',": "'monthly': 'МЕСЯЧНАЯ',\n    'weekly': '7 ДНЕЙ',",
}
for old, new in weekly_copy.items():
    weekly_value = new.split("'weekly': ", 1)[1].rstrip(',')
    if weekly_value not in gate:
        if old not in gate:
            raise RuntimeError(f'weekly localization anchor missing: {old}')
        gate = gate.replace(old, new, 1)

label_helper = '''  String _creatorPlanLabel(ProductDetails product) {
    if (product.id == CommercialBillingService.weeklyProductId) {
      return _t('weekly');
    }
    if (product.id == CommercialBillingService.annualProductId) {
      return _t('annual');
    }
    return _t('monthly');
  }

'''
if 'String _creatorPlanLabel(ProductDetails product)' not in gate:
    anchor = '  Widget _billing() {\n'
    if anchor not in gate:
        raise RuntimeError('commercial billing widget anchor missing')
    gate = gate.replace(anchor, label_helper + anchor, 1)

# Replace the historical annual/monthly ternary independent of formatter layout.
if '_creatorPlanLabel(product)' not in gate:
    pattern = re.compile(
        r"product\.id\s*==\s*CommercialBillingService\.annualProductId\s*"
        r"\?\s*_t\('annual'\)\s*:\s*_t\('monthly'\)"
    )
    gate, count = pattern.subn('_creatorPlanLabel(product)', gate, count=1)
    if count != 1:
        raise RuntimeError('Creator plan-label ternary semantic anchor missing')

for token in [
    "'weekly': '7 GIORNI'",
    "'weekly': '7 DAYS'",
    "'weekly': '7 DÍAS'",
    "'weekly': '7 ДНЕЙ'",
    'CommercialBillingService.weeklyProductId',
    "return _t('weekly');",
    '_creatorPlanLabel(product)',
]:
    if token not in gate:
        raise RuntimeError(f'weekly Creator UI contract missing: {token}')

GATE.write_text(gate, encoding='utf-8')
print('Creator 7-day weekly subscription finalized for IT/EN/ES/RU')
