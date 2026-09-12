from pathlib import Path

OLD_ROLE = 'DECISIONAL_DISPLAY_REALITY_V3_FULL_FRAME_OR_MIXED_SCENE'
NEW_ROLE = 'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V31_ADVANCED_PHYSICS_DIAGNOSTIC_ONLY'

# BUILD107 deliberately keeps the already validated V3 display/mixed-scene
# decision path active while the new V3.1 exposure/spatial physics remains
# diagnostic-only until physical validation. Update only stale contract text.
role_contracts = {
    Path('test/frequency_probe_session_safety_contract_test.dart'): 1,
    Path('test/temporal_frequency_probe_contract_test.dart'): 1,
    Path('test/native_temporal_frequency_v2_contract_test.dart'): 2,
}

for path, expected_count in role_contracts.items():
    text = path.read_text()
    actual_count = text.count(OLD_ROLE)
    if actual_count != expected_count:
        raise SystemExit(
            f'{path}: expected {expected_count} stale decisionRole occurrence(s), '
            f'found {actual_count}'
        )
    text = text.replace(OLD_ROLE, NEW_ROLE)
    if OLD_ROLE in text or text.count(NEW_ROLE) < expected_count:
        raise SystemExit(f'{path}: BUILD107 decisionRole contract replacement failed')
    path.write_text(text)

# BUILD107 also corrects the epistemic meaning of a quiet/negative HFR result:
# absence of a display signature is not positive physical-reality evidence.
path = Path('test/hfr_v3_fullframe_mixed_scene_test.dart')
text = path.read_text()

old_reason_assertion = "expect(result.reasons, contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE'));"
if old_reason_assertion in text:
    text = text.replace(
        old_reason_assertion,
        "expect(result.reasons, isNot(contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE')));",
        1,
    )

possible_names = [
    "test('quiet HFR alone cannot override temporal-only passive optical cue', () {",
    "test('Reality V3 overrides temporal-only passive optical false positive on desk', () {",
    "test('quiet HFR cannot override temporal-only passive optical false positive on desk', () {",
]
name = next((candidate for candidate in possible_names if candidate in text), None)
if name is None:
    raise SystemExit('desk quiet-HFR contract test not found after BUILD107 patch')

canonical_name = "test('quiet HFR cannot override temporal-only passive optical false positive on desk', () {"
if name != canonical_name:
    text = text.replace(name, canonical_name, 1)

pos = text.index(canonical_name)
end = text.index('\n  });', pos)
block = text[pos:end]

# Accept the typed or string form produced by the BUILD106/BUILD107 test source,
# but the final BUILD107 expectation must be NON_CONCLUSIVE.
block = block.replace(
    "expect(result.decision, 'NO_DISPLAY_EVIDENCE');",
    "expect(result.decision, 'NON_CONCLUSIVE');",
    1,
)
block = block.replace(
    'expect(result.decision, DisplayRiskDecision.NO_DISPLAY_EVIDENCE);',
    'expect(result.decision, DisplayRiskDecision.NON_CONCLUSIVE);',
    1,
)
if 'NON_CONCLUSIVE' not in block:
    raise SystemExit('desk quiet-HFR NON_CONCLUSIVE contract not found')

reason = 'HFR_V3_REALITY_OVERRIDES_TEMPORAL_ONLY_PASSIVE_OPTICAL_CUE'
positive = f"contains('{reason}')"
negative = f"isNot(contains('{reason}'))"
if negative not in block:
    if positive not in block:
        raise SystemExit('desk quiet-HFR reason assertion not found')
    block = block.replace(positive, negative, 1)
if negative not in block:
    raise SystemExit('desk quiet-HFR negative reason assertion replacement failed')

text = text[:pos] + block + text[end:]
path.write_text(text)
