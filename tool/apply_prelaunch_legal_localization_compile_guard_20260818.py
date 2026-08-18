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

# Also handle formatted multi-line constructor calls with a trailing comma.
gate = gate.replace('throw const CommercialAccountException(\n              _t(', 'throw CommercialAccountException(\n              _t(')

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

for required in [
    "'it': {",
    "'en': {",
    "'es': {",
    "'ru': {",
    'Widget _languageSelector()',
    'languageCode: _languageCode',
    "_t('landingSubtitle')",
]:
    if required not in gate:
        raise RuntimeError(f'compile guard required token missing: {required}')

GATE.write_text(gate, encoding='utf-8')
print('Commercial localization compile guard applied; translation table remains const and HCV engine untouched')
