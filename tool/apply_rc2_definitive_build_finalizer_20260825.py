from pathlib import Path


def replace_once_idempotent(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    if not file.exists():
        raise RuntimeError(f'{label}: required file missing: {path}')
    source = file.read_text(encoding='utf-8')
    old_count = source.count(old)
    new_count = source.count(new)
    if old_count == 1 and new_count == 0:
        file.write_text(source.replace(old, new, 1), encoding='utf-8')
        print(f'{label}: applied')
        return
    if old_count == 0 and new_count == 1:
        print(f'{label}: already applied')
        return
    raise RuntimeError(
        f'{label}: unexpected source state (old={old_count}, new={new_count})'
    )


# ---------------------------------------------------------------------------
# Final display-risk fusion contract.
# A high-confidence SCREEN_* ML result remains evidence even when the active
# geometry probe reports reflected reality. The disagreement is explicitly
# NON_CONCLUSIVE unless a second independent display source corroborates ML.
# Thresholds are intentionally unchanged.
# ---------------------------------------------------------------------------
fusion_old = """    final mlModerate = !reflectedRealityEvidence &&
        mlSaysScreen &&
        mlScore >= 88 &&
        (mlConfidence == null || mlConfidence >= 0.70);
    if (mlModerate) evidenceSources.add('ML_SCREEN_CLASS');
    if (mlStrong) {
      strongSources.add('ML_SCREEN_CLASS');
      reasons.add('ML_SCREEN_HIGH_CONFIDENCE');
    } else if (mlModerate) {
      reasons.add('ML_SCREEN_MODERATE_CONFIDENCE');
    }
"""

fusion_new = """    final mlModerate = mlStrong ||
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

replace_once_idempotent(
    'lib/hcv_display_risk_fusion.dart',
    fusion_old,
    fusion_new,
    'strong ML/reflected-reality conflict fusion',
)


# ---------------------------------------------------------------------------
# Text certification CTA. Keep the existing localization key so every caller
# remains stable; change only the public copy in all four supported locales.
# ---------------------------------------------------------------------------
localization_path = 'lib/sigillum_localization.dart'
copy_replacements = [
    (
        "'certifyTextButton': 'Certifica testo',",
        "'certifyTextButton': 'Crea e Certifica testo',",
        'Italian text certification CTA',
    ),
    (
        "'certifyTextButton': 'Certify Text',",
        "'certifyTextButton': 'Create and Certify Text',",
        'English text certification CTA',
    ),
    (
        "'certifyTextButton': 'Certificar texto',",
        "'certifyTextButton': 'Crear y certificar texto',",
        'Spanish text certification CTA',
    ),
    (
        "'certifyTextButton': 'Сертифицировать текст',",
        "'certifyTextButton': 'Создать и сертифицировать текст',",
        'Russian text certification CTA',
    ),
]
for old, new, label in copy_replacements:
    replace_once_idempotent(localization_path, old, new, label)


# ---------------------------------------------------------------------------
# Contract assertions on the exact final source.
# ---------------------------------------------------------------------------
fusion = Path('lib/hcv_display_risk_fusion.dart').read_text(encoding='utf-8')
for token in [
    'final mlModerate = mlStrong ||',
    "evidenceSources.add('ML_SCREEN_CLASS')",
    "reasons.add('ML_SCREEN_AND_REFLECTED_REALITY_CONFLICT')",
]:
    if token not in fusion:
        raise RuntimeError(f'definitive fusion token missing: {token}')

localization = Path(localization_path).read_text(encoding='utf-8')
for token in [
    "'certifyTextButton': 'Crea e Certifica testo',",
    "'certifyTextButton': 'Create and Certify Text',",
    "'certifyTextButton': 'Crear y certificar texto',",
    "'certifyTextButton': 'Создать и сертифицировать текст',",
]:
    if localization.count(token) != 1:
        raise RuntimeError(f'definitive localized CTA missing or duplicated: {token}')

print('RC2 definitive-build finalizer PASS')
