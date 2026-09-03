from pathlib import Path

# Trigger validation after workflow creation.
path = Path('lib/hcv_display_risk_fusion.dart')
text = path.read_text()
old = """    if (predictedClass.startsWith('SCREEN_') && screenProbability >= 0.90) {
      final score = mlScore.clamp(90, 100).toInt();
"""
new = """    if (predictedClass.startsWith('SCREEN_') && screenProbability >= 0.80) {
      final score = mlScore.clamp(80, 100).toInt();
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected exactly one photo ML-first threshold block, found {count}')
path.write_text(text.replace(old, new, 1))
print('photo ML-first SCREEN threshold changed from 0.90 to 0.80')
