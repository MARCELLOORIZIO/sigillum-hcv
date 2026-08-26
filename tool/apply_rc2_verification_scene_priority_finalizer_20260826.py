from pathlib import Path

REGISTRY = Path('lib/registry_verify_page.dart')

source = REGISTRY.read_text(encoding='utf-8')

# The public scene card must never promote a live-probe REALITY result over the
# signed final display fusion. HCV-6052 is the concrete regression: the live
# probe resolved geometric REALITY/NO_DISPLAY_EVIDENCE, while the signed final
# fusion was NON_CONCLUSIVE because ML strongly classified SCREEN_MONITOR.
# Only a final NO_DISPLAY_EVIDENCE verdict is allowed to render the stronger
# "reality detected" public label.
guard = "    if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;\n"
helper_anchor = "  bool get _signedRealityScene {\n    final cert = certificate;\n"
helper_with_guard = (
    "  bool get _signedRealityScene {\n"
    "    if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;\n"
    "    final cert = certificate;\n"
)

if guard not in source:
    if helper_anchor not in source:
        raise RuntimeError(
            'verification scene-priority anchor missing: localized registry helper '
            'must be materialized before this finalizer'
        )
    source = source.replace(helper_anchor, helper_with_guard, 1)
    print('verification scene final-fusion priority guard applied')
else:
    print('verification scene final-fusion priority guard already applied')

# Contract checks: the stronger reality label remains available only after the
# final fusion guard, while NON_CONCLUSIVE continues to map to sceneUncertain.
for token in [
    "if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;",
    "if (axis == 'scene' && _signedRealityScene) return _v('realityDetected');",
    "if (axis == 'scene' && value.contains('conclusiva')) return _v('sceneUncertain');",
    "if (_isDisplayNonConclusive) return _v('uncertainDetail');",
]:
    if token not in source:
        raise RuntimeError(f'verification scene-priority contract missing: {token}')

REGISTRY.write_text(source, encoding='utf-8')
print('RC2 verification scene-priority finalizer PASS')
