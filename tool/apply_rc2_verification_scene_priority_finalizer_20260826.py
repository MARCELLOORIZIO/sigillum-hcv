from pathlib import Path

REGISTRY = Path('lib/registry_verify_page.dart')

source = REGISTRY.read_text(encoding='utf-8')

# The public scene card must never promote a live-probe REALITY result over the
# signed final display fusion. HCV-6052 is the concrete regression: the live
# probe resolved geometric REALITY/NO_DISPLAY_EVIDENCE, while the signed final
# fusion was NON_CONCLUSIVE because ML strongly classified SCREEN_MONITOR.
# Only a final NO_DISPLAY_EVIDENCE verdict is allowed to render the stronger
# "reality detected" public label.
helper_anchor = "  bool get _signedRealityScene {\n    final cert = certificate;\n"
helper_with_guard = (
    "  bool get _signedRealityScene {\n"
    "    if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;\n"
    "    final cert = certificate;\n"
)

if helper_with_guard in source:
    print('verification scene final-fusion priority guard already applied')
elif helper_anchor in source:
    source = source.replace(helper_anchor, helper_with_guard, 1)
    print('verification scene final-fusion priority guard applied')
else:
    raise RuntimeError(
        'verification scene-priority anchor missing: localized registry helper '
        'must be materialized before this finalizer'
    )

# Validate the guard in the exact getter, not merely somewhere in the file.
# This prevents an unrelated occurrence of the same condition from satisfying
# the release contract.
if helper_with_guard not in source:
    raise RuntimeError(
        'verification scene-priority guard is not installed in _signedRealityScene'
    )

for token in [
    "if (axis == 'scene' && _signedRealityScene) return _v('realityDetected');",
    "if (axis == 'scene' && value.contains('conclusiva')) return _v('sceneUncertain');",
    "if (_isDisplayNonConclusive) return _v('uncertainDetail');",
]:
    if token not in source:
        raise RuntimeError(f'verification scene-priority contract missing: {token}')

REGISTRY.write_text(source, encoding='utf-8')
print('RC2 verification scene-priority finalizer PASS')
