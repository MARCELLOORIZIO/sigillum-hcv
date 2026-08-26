from pathlib import Path
import subprocess

EXPECTED_COMMIT_SUBJECT = 'RC2: materialize finalized release source'

subject = subprocess.check_output(
    ['git', 'log', '-1', '--pretty=%s'],
    text=True,
).strip()

if subject != EXPECTED_COMMIT_SUBJECT:
    raise RuntimeError(
        'release source is not materialized: expected HEAD subject '
        f'{EXPECTED_COMMIT_SUBJECT!r}, got {subject!r}'
    )

required = {
    Path('lib/registry_verify_page.dart'): [
        "if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;",
        "_v('sceneUncertain')",
    ],
    Path('lib/hcv_display_risk_fusion.dart'): [
        "reasons.add('ML_GEOMETRY_CONFLICT')",
        "reasons.add('ACTIVE_DISPLAY_GEOMETRY_CONFLICT')",
        "final strongDisplayFamilies = <String>{};",
    ],
    Path('test/rc2_real_world_decision_regression_test.dart'): [
        'HCV 6052 strong monitor ML plus REALITY geometry remains non-conclusive',
        'HCV 3F31 mixed 3D scene with display cues cannot resolve as no display evidence',
    ],
    Path('test/rc2_verification_scene_priority_contract_test.dart'): [
        'public scene label cannot override signed final display fusion',
    ],
}

for path, tokens in required.items():
    source = path.read_text(encoding='utf-8')
    for token in tokens:
        if token not in source:
            raise RuntimeError(f'materialized release token missing in {path}: {token}')

print('SIGILLUM materialized source release gate PASS')
