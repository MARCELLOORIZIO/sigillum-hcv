from pathlib import Path

GATE = Path('lib/commercial_gate.dart')
if GATE.as_posix() != 'lib/commercial_gate.dart':
    raise RuntimeError('public-home routing patch escaped commercial allowlist')

source = GATE.read_text(encoding='utf-8')

old_bootstrap = '''      _applyEnvelope(envelope);\n      await _routeAuthenticated();'''
new_bootstrap = '''      _applyEnvelope(envelope);\n      await _routeAuthenticated(returnToLandingIfUnpaid: true);'''
if old_bootstrap in source:
    source = source.replace(old_bootstrap, new_bootstrap, 1)
elif new_bootstrap not in source:
    raise RuntimeError('bootstrap authenticated-route anchor missing')

old_signature = '  Future<void> _routeAuthenticated() async {'
new_signature = '''  Future<void> _routeAuthenticated({\n    bool returnToLandingIfUnpaid = false,\n  }) async {'''
if old_signature in source:
    source = source.replace(old_signature, new_signature, 1)
elif new_signature not in source:
    raise RuntimeError('authenticated-route signature anchor missing')

old_inactive = '''    if (!serverActive) {\n      await _prepareBilling();\n      if (mounted) setState(() => _stage = _GateStage.billing);\n      return;\n    }'''
new_inactive = '''    if (!serverActive) {\n      if (returnToLandingIfUnpaid) {\n        if (mounted) setState(() => _stage = _GateStage.landing);\n        return;\n      }\n      await _prepareBilling();\n      if (mounted) setState(() => _stage = _GateStage.billing);\n      return;\n    }'''
if old_inactive in source:
    source = source.replace(old_inactive, new_inactive, 1)
elif new_inactive not in source:
    raise RuntimeError('inactive-entitlement routing anchor missing')

required = [
    'await _routeAuthenticated(returnToLandingIfUnpaid: true);',
    'bool returnToLandingIfUnpaid = false,',
    'if (returnToLandingIfUnpaid)',
    'setState(() => _stage = _GateStage.landing)',
    'await _prepareBilling();',
    'setState(() => _stage = _GateStage.billing)',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'public-home routing token missing: {token}')

# Guard the intended split: restored unpaid sessions return to the public home,
# while explicit Creator/login flows still use the default route and therefore
# reach the paywall when entitlement is inactive.
if source.count('returnToLandingIfUnpaid: true') != 1:
    raise RuntimeError('public-home bypass must be bootstrap-only')

GATE.write_text(source, encoding='utf-8')
print('Expired/restored Creator sessions return to public home; Creator entry remains paywalled')

# Keep the verification-picker correction in the same commercial/prelaunch
# transformation chain so Codemagic applies it automatically after the
# commercial shell without touching the frozen HCV/camera engine.
picker_patch = Path('tool/apply_media_specific_verification_picker_fix_20260822.py')
if not picker_patch.exists():
    raise RuntimeError('media-specific verification picker patch missing')
exec(
    compile(
        picker_patch.read_text(encoding='utf-8'),
        str(picker_patch),
        'exec',
    ),
    {'__name__': '__main__'},
)

# Apply the final StoreKit price presentation only after all commercial and
# nested release transformations. Product.displayPrice is the authoritative
# localized Apple price; no capture/HCV/Registry source is modified here.
price_patch = Path('tool/apply_storekit_localized_price_ui_fix_20260826.py')
if not price_patch.exists():
    raise RuntimeError('StoreKit localized-price finalizer missing')
exec(
    compile(
        price_patch.read_text(encoding='utf-8'),
        str(price_patch),
        'exec',
    ),
    {'__name__': '__main__'},
)
