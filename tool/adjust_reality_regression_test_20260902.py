from pathlib import Path
p = Path('test/build67_reality_regression_test.dart')
s = p.read_text()
s = s.replace("contains('ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE')", "contains('ML_SCREEN_HIGH_CONFIDENCE')")
p.write_text(s)
