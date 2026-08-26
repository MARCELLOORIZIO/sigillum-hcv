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

working_tree = subprocess.check_output(
    ['git', 'status', '--porcelain'],
    text=True,
).strip()
if working_tree:
    raise RuntimeError(
        'materialized release commit left a dirty working tree:\n' + working_tree
    )

changed_in_commit = set(
    subprocess.check_output(
        ['git', 'diff', '--name-only', 'HEAD^', 'HEAD'],
        text=True,
    ).splitlines()
)
for required_path in [
    'lib/registry_verify_page.dart',
    'lib/hcv_display_risk_fusion.dart',
]:
    if required_path not in changed_in_commit:
        raise RuntimeError(
            f'materialization commit did not contain required source path: {required_path}'
        )

signed_reality_getter = (
    "  bool get _signedRealityScene {\n"
    "    if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;\n"
    "    final cert = certificate;\n"
)

required = {
    Path('lib/registry_verify_page.dart'): [
        signed_reality_getter,
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
        'signedRealityGetter',
    ],
    Path('.github/workflows/materialize-rc2-source-20260826.yml'): [
        'Reproduce Codemagic pre-finalizer verification',
        'Prove release finalizer idempotence with pass 2',
        'Validate exact pre-archive source',
    ],
}

for path, tokens in required.items():
    source = path.read_text(encoding='utf-8')
    for token in tokens:
        if token not in source:
            raise RuntimeError(f'materialized release token missing in {path}: {token}')

workflow = Path('.github/workflows/materialize-rc2-source-20260826.yml').read_text(
    encoding='utf-8'
)
if 'dart format lib test' in workflow:
    raise RuntimeError(
        'materialization workflow contains broad formatting that is not part of Codemagic'
    )

print('SIGILLUM materialized source release gate PASS')
