from pathlib import Path

# Validation revision: supersede the obsolete geometry-veto contract.
path = Path('test/build73_video_screen_persistence_v2_regression_test.dart')
text = path.read_text()
old = """  test('80 percent SCREEN is not enough against REALITY without strong anchor', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(geometryClass: 'REALITY'),
      _passive(score: 20),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.90,
        screenProbability: 0.95,
        score: 95,
        frames: 5,
        strongFrames: 2,
        mediumFrames: 3,
        average: 86,
        maxFrame: 95,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });
"""
new = """  test('ML-first: 80 percent SCREEN at p=.95 overrides geometry REALITY', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(geometryClass: 'REALITY'),
      _passive(score: 20),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.90,
        screenProbability: 0.95,
        score: 95,
        frames: 5,
        strongFrames: 2,
        mediumFrames: 3,
        average: 86,
        maxFrame: 95,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(
      result.reasons,
      contains('ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY'),
    );
  });
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one legacy 80 percent SCREEN contract, found {count}')
path.write_text(text.replace(old, new, 1))
print('ML-first regression contract updated')
