from pathlib import Path

path = Path('test/hfr_v3_fullframe_mixed_scene_test.dart')
text = path.read_text()

old_reason_assertion = "expect(result.reasons, contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE'));"
if old_reason_assertion in text:
    text = text.replace(
        old_reason_assertion,
        "expect(result.reasons, isNot(contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE')));",
        1,
    )

# The main BUILD107 patch already renames this test. Support that exact
# materialized name so this correction remains deterministic when replayed
# from the clean BUILD106 source.
possible_names = [
    "test('quiet HFR alone cannot override temporal-only passive optical cue', () {",
    "test('Reality V3 overrides temporal-only passive optical false positive on desk', () {",
]
name = next((candidate for candidate in possible_names if candidate in text), None)
if name is None:
    raise SystemExit('desk quiet-HFR contract test not found after BUILD107 patch')

canonical_name = "test('quiet HFR cannot override temporal-only passive optical false positive on desk', () {"
text = text.replace(name, canonical_name, 1)

pos = text.index(canonical_name)
end = text.index('\n  });', pos)
block = text[pos:end]
block = block.replace(
    "expect(result.decision, 'NO_DISPLAY_EVIDENCE');",
    "expect(result.decision, 'NON_CONCLUSIVE');",
    1,
)
old_reason = """    expect(
      result.reasons,
      contains('HFR_V3_REALITY_OVERRIDES_TEMPORAL_ONLY_PASSIVE_OPTICAL_CUE'),
    );
"""
new_reason = """    expect(
      result.reasons,
      isNot(contains('HFR_V3_REALITY_OVERRIDES_TEMPORAL_ONLY_PASSIVE_OPTICAL_CUE')),
    );
"""
if old_reason in block:
    block = block.replace(old_reason, new_reason, 1)
elif "HFR_V3_REALITY_OVERRIDES_TEMPORAL_ONLY_PASSIVE_OPTICAL_CUE" not in block:
    raise SystemExit('desk quiet-HFR reason assertion not found')
text = text[:pos] + block + text[end:]

path.write_text(text)
