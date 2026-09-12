from pathlib import Path

path = Path('test/hfr_v3_fullframe_mixed_scene_test.dart')
text = path.read_text()

text = text.replace(
    "expect(result.reasons, contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE'));",
    "expect(result.reasons, isNot(contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE')));",
    1,
)

old_name = "test('Reality V3 overrides temporal-only passive optical false positive on desk', () {"
new_name = "test('quiet HFR cannot override temporal-only passive optical false positive on desk', () {"
if old_name not in text:
    raise SystemExit('desk Reality V3 test name not found')
text = text.replace(old_name, new_name, 1)

pos = text.index(new_name)
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
if old_reason not in block:
    raise SystemExit('desk Reality V3 reason assertion not found')
block = block.replace(old_reason, new_reason, 1)
text = text[:pos] + block + text[end:]

path.write_text(text)
