from pathlib import Path

# Trigger full validation after workflow update.
path = Path('test/ml_calibration_corpus_v1_test.dart')
text = path.read_text()
old = """  test('photo thresholds preserve a wide gray zone', () {
    final almostScreen = {
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.899,
      'screenReplayRiskScore': 90,
      'framesAnalyzed': 1,
    };
"""
new = """  test('photo thresholds preserve the 0.80/0.20 gray zone', () {
    final almostScreen = {
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.799,
      'screenReplayRiskScore': 79,
      'framesAnalyzed': 1,
    };
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected exactly one calibration photo-threshold contract, found {count}')
path.write_text(text.replace(old, new, 1))
print('calibration photo gray-zone contract updated for 0.80 SCREEN threshold')
