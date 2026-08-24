from pathlib import Path
import re

GATE = Path('lib/commercial_gate.dart')
PATCH = Path('tool/apply_prelaunch_legal_localization_20260818.py')

gate = GATE.read_text(encoding='utf-8')
patch = PATCH.read_text(encoding='utf-8')

# Restore the literal translation table after UI replacements. This prevents
# string-replacement rules from turning const translation values into _t(...)
# calls. The canonical table is extracted from the legal/localization patch.
match = re.search(r"copy_block = r'''(.*?)'''\n\nif 'const _commercialGateCopy'", patch, re.S)
if not match:
    raise RuntimeError('canonical commercial translation block not found')
canonical = match.group(1).strip('\n')

gate, count = re.subn(
    r"const _commercialGateCopy = <String, Map<String, String>>\{.*?\n\};\n\nenum _GateStage",
    canonical + "\n\nenum _GateStage",
    gate,
    count=1,
    flags=re.S,
)
if count != 1:
    raise RuntimeError('commercial translation table restore failed')

# Dynamic localized labels cannot live inside const InputDecoration widgets.
gate = gate.replace('decoration: const InputDecoration(', 'decoration: InputDecoration(')

# Localize variants introduced by earlier billing refinement scripts.
gate = gate.replace(
    "_message = 'Verifica dell’abbonamento con App Store in corso…';",
    "_message = _t('checkingSubscription');",
)
gate = gate.replace(
    "'L’abbonamento non risulta attivo dopo la verifica App Store.'",
    "_t('subscriptionInactive')",
)
gate = gate.replace(
    "_message = 'Abbonamento verificato.';",
    "_message = _t('subscriptionVerified');",
)
gate = gate.replace(
    "_message = 'Verifica abbonamento non riuscita: $error';",
    "_message = \"${_t('subscriptionFailed')}: $error\";",
)
gate = gate.replace(
    "purchase.error?.message ?? 'Acquisto non completato.'",
    "purchase.error?.message ?? _t('purchaseFailed')",
)

# A non-const localized expression cannot be passed through a const exception.
gate = re.sub(
    r"throw const CommercialAccountException\(\s*(_t\('[^']+'\))\s*,?\s*\);",
    r"throw CommercialAccountException(\1);",
    gate,
    flags=re.S,
)
gate = gate.replace(
    'throw const CommercialAccountException(\n              _t(',
    'throw CommercialAccountException(\n              _t(',
)

# Later commercial refinements rewrite _register(). Ensure every registration
# call carries the selected language to the server-side clickwrap record.
def add_register_language(match):
    block = match.group(0)
    if 'languageCode:' in block:
        return block
    return block.replace(
        'adultConfirmed: _adult,',
        'adultConfirmed: _adult,\n          languageCode: _languageCode,',
        1,
    )

gate = re.sub(
    r"await _account\.register\(.*?adultConfirmed:\s*_adult,.*?\);",
    add_register_language,
    gate,
    flags=re.S,
)

# All commercial routes reachable before or during onboarding use the same
# selected language. This includes the quick guide introduced by a later patch.
gate = gate.replace(
    "const SigillumQuickGuidePage(languageCode: 'it')",
    'SigillumQuickGuidePage(languageCode: _languageCode)',
)

# Guard against accidental recursion/invalid expressions inside the const map.
map_match = re.search(
    r"const _commercialGateCopy = <String, Map<String, String>>\{.*?\n\};",
    gate,
    re.S,
)
if not map_match:
    raise RuntimeError('commercial translation table missing after restore')
if '_t(' in map_match.group(0):
    raise RuntimeError('dynamic translation call remains inside const translation table')

required_tokens = [
    "'it': {",
    "'en': {",
    "'es': {",
    "'ru': {",
    'Widget _languageSelector()',
    'languageCode: _languageCode',
]
# The simple legacy landing uses landingSubtitle directly. The approved visual
# landing is localized by the dedicated presentation patch that runs next.
if "ValueKey('landing-visual-v2')" not in gate:
    required_tokens.append("_t('landingSubtitle')")

for required in required_tokens:
    if required not in gate:
        raise RuntimeError(f'compile guard required token missing: {required}')

register_calls = re.findall(r"await _account\.register\((.*?)\);", gate, re.S)
if not register_calls:
    raise RuntimeError('commercial registration call missing')
for block in register_calls:
    if 'languageCode: _languageCode' not in block:
        raise RuntimeError('registration call missing selected language')

for forbidden in [
    "SigillumQuickGuidePage(languageCode: 'it')",
    "ImportPage(languageCode: 'it')",
    "LegalInfoPage(languageCode: 'it')",
]:
    if forbidden in gate:
        raise RuntimeError(f'hard-coded Italian commercial route remains: {forbidden}')

GATE.write_text(gate, encoding='utf-8')
print('Commercial localization compile guard applied; selected language propagates through onboarding and HCV engine remains untouched')

# Billing lifecycle is deliberately applied after localization has stabilized
# the commercial gate. The isolated patch only rewrites the StoreKit purchase
# handler and never touches capture/HCV/Registry core files.
billing_lifecycle_patch = Path('tool/apply_storekit_transaction_lifecycle_fix_20260821.py')
if not billing_lifecycle_patch.exists():
    raise RuntimeError('StoreKit transaction lifecycle patch missing')
exec(
    compile(
        billing_lifecycle_patch.read_text(encoding='utf-8'),
        str(billing_lifecycle_patch),
        'exec',
    ),
    {'__name__': '__main__'},
)
