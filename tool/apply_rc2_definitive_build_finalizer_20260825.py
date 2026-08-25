from pathlib import Path


def replace_semantic_region(
    path: str,
    start_marker: str,
    end_marker: str,
    new_region: str,
    required_tokens: list[str],
    label: str,
) -> None:
    file = Path(path)
    if not file.exists():
        raise RuntimeError(f'{label}: required file missing: {path}')

    source = file.read_text(encoding='utf-8')
    if source.count(start_marker) != 1 or source.count(end_marker) != 1:
        raise RuntimeError(
            f'{label}: semantic markers are not unique '
            f'(start={source.count(start_marker)}, end={source.count(end_marker)})'
        )

    start = source.index(start_marker)
    end = source.index(end_marker, start)
    line_start = source.rfind('\n', 0, start) + 1
    current_region = source[line_start:end]

    if all(token in current_region for token in required_tokens):
        print(f'{label}: already applied')
        return

    file.write_text(
        source[:line_start] + new_region + source[end:],
        encoding='utf-8',
    )
    print(f'{label}: applied')


def ensure_copy_line(
    path: str,
    key: str,
    desired: str,
    accepted_old_values: list[str],
    label: str,
) -> None:
    file = Path(path)
    if not file.exists():
        raise RuntimeError(f'{label}: required file missing: {path}')

    source = file.read_text(encoding='utf-8')
    desired_line = f"      '{key}': '{desired}',"
    if source.count(desired_line) == 1:
        print(f'{label}: already applied')
        return
    if source.count(desired_line) > 1:
        raise RuntimeError(f'{label}: desired copy duplicated')

    candidates = [f"      '{key}': '{value}'," for value in accepted_old_values]
    matches = [line for line in candidates if source.count(line) == 1]
    if len(matches) != 1:
        raise RuntimeError(
            f'{label}: unexpected source state '
            f'(matching_old_variants={len(matches)})'
        )

    file.write_text(source.replace(matches[0], desired_line, 1), encoding='utf-8')
    print(f'{label}: applied')


# ---------------------------------------------------------------------------
# Final display-risk fusion contract.
# A high-confidence SCREEN_* ML result remains evidence even when the active
# geometry probe reports reflected reality. The disagreement is explicitly
# NON_CONCLUSIVE unless a second independent display source corroborates ML.
# Thresholds are intentionally unchanged.
#
# IMPORTANT: previous release finalizers can reformat or partially rewrite this
# block before this script runs. Replace the semantic region bounded by the ML
# block and the independent-corroboration block instead of matching one fragile
# byte-for-byte source snapshot.
# ---------------------------------------------------------------------------
fusion_region = """    final mlModerate = mlStrong ||
        (!reflectedRealityEvidence &&
            mlSaysScreen &&
            mlScore >= 88 &&
            (mlConfidence == null || mlConfidence >= 0.70));
    if (mlModerate) evidenceSources.add('ML_SCREEN_CLASS');
    if (mlStrong) {
      strongSources.add('ML_SCREEN_CLASS');
      reasons.add('ML_SCREEN_HIGH_CONFIDENCE');
      if (reflectedRealityEvidence) {
        reasons.add('ML_SCREEN_AND_REFLECTED_REALITY_CONFLICT');
      }
    } else if (mlModerate) {
      reasons.add('ML_SCREEN_MODERATE_CONFIDENCE');
    }

"""

replace_semantic_region(
    'lib/hcv_display_risk_fusion.dart',
    'final mlModerate =',
    'final hasIndependentCorroboration =',
    fusion_region,
    [
        'final mlModerate = mlStrong ||',
        "evidenceSources.add('ML_SCREEN_CLASS')",
        "strongSources.add('ML_SCREEN_CLASS')",
        "reasons.add('ML_SCREEN_AND_REFLECTED_REALITY_CONFLICT')",
    ],
    'strong ML/reflected-reality conflict fusion',
)


# ---------------------------------------------------------------------------
# Text certification CTA.
# UserHomePage renders certifyTextTitle; TextCertPage renders certifyTextButton.
# Keep both keys stable and set the requested public copy in every supported
# locale. The accepted variants cover both the committed source and the older
# build-time finalizer output so this step is safe to run repeatedly.
# ---------------------------------------------------------------------------
localization_path = 'lib/sigillum_localization.dart'
copy_contracts = [
    (
        'certifyTextTitle',
        'Crea e Certifica testo',
        ['Certifica testo'],
        'Italian text certification home CTA',
    ),
    (
        'certifyTextButton',
        'Crea e Certifica testo',
        ['CERTIFICA TESTO', 'Certifica testo'],
        'Italian text certification action CTA',
    ),
    (
        'certifyTextTitle',
        'Create and Certify Text',
        ['Certify text', 'Certify Text'],
        'English text certification home CTA',
    ),
    (
        'certifyTextButton',
        'Create and Certify Text',
        ['CERTIFY TEXT', 'Certify Text'],
        'English text certification action CTA',
    ),
    (
        'certifyTextTitle',
        'Crear y certificar texto',
        ['Certificar texto'],
        'Spanish text certification home CTA',
    ),
    (
        'certifyTextButton',
        'Crear y certificar texto',
        ['CERTIFICAR TEXTO', 'Certificar texto'],
        'Spanish text certification action CTA',
    ),
    (
        'certifyTextTitle',
        'Создать и сертифицировать текст',
        ['Сертифицировать текст'],
        'Russian text certification home CTA',
    ),
    (
        'certifyTextButton',
        'Создать и сертифицировать текст',
        ['СЕРТИФИЦИРОВАТЬ ТЕКСТ', 'Сертифицировать текст'],
        'Russian text certification action CTA',
    ),
]

for key, desired, old_values, label in copy_contracts:
    ensure_copy_line(localization_path, key, desired, old_values, label)


# ---------------------------------------------------------------------------
# Contract assertions on the exact final source that proceeds to the IPA.
# ---------------------------------------------------------------------------
fusion = Path('lib/hcv_display_risk_fusion.dart').read_text(encoding='utf-8')
for token in [
    'final mlModerate = mlStrong ||',
    "evidenceSources.add('ML_SCREEN_CLASS')",
    "strongSources.add('ML_SCREEN_CLASS')",
    "reasons.add('ML_SCREEN_AND_REFLECTED_REALITY_CONFLICT')",
]:
    if token not in fusion:
        raise RuntimeError(f'definitive fusion token missing: {token}')

localization = Path(localization_path).read_text(encoding='utf-8')
for key, desired in [
    ('certifyTextTitle', 'Crea e Certifica testo'),
    ('certifyTextButton', 'Crea e Certifica testo'),
    ('certifyTextTitle', 'Create and Certify Text'),
    ('certifyTextButton', 'Create and Certify Text'),
    ('certifyTextTitle', 'Crear y certificar texto'),
    ('certifyTextButton', 'Crear y certificar texto'),
    ('certifyTextTitle', 'Создать и сертифицировать текст'),
    ('certifyTextButton', 'Создать и сертифицировать текст'),
]:
    token = f"      '{key}': '{desired}',"
    if localization.count(token) != 1:
        raise RuntimeError(f'definitive localized CTA missing or duplicated: {token}')

print('RC2 definitive-build finalizer PASS')
