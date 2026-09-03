from pathlib import Path

path = Path('test/build72_video_reality_and_container_regression_test.dart')
text = path.read_text()
old = """  test('short semantic REALITY does not override PLANAR geometry', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        rawActive: true,
        activeDisplay: true,
      ),
      _passive(score: 20, structural: false),
      _ml(
        predictedClass: 'REALITY_PAPER',
        confidence: 0.80,
        screenProbability: 0.10,
        score: 10,
        frames: 2,
        strongFrames: 0,
        mediumFrames: 0,
        average: 8,
        maxFrame: 10,
        frameClasses: const ['REALITY_PAPER', 'REALITY_PAPER'],
      ),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });
"""
new = """  test('ML-first: short strong REALITY is not vetoed by PLANAR alone', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        rawActive: true,
        activeDisplay: true,
      ),
      _passive(score: 20, structural: false),
      _ml(
        predictedClass: 'REALITY_PAPER',
        confidence: 0.80,
        screenProbability: 0.10,
        score: 10,
        frames: 2,
        strongFrames: 0,
        mediumFrames: 0,
        average: 8,
        maxFrame: 10,
        frameClasses: const ['REALITY_PAPER', 'REALITY_PAPER'],
      ),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('ML_FIRST_VIDEO_NO_SCREEN_MAJORITY_LOW_PROBABILITY'),
    );
  });
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one PLANAR geometry veto contract, found {count}')
path.write_text(text.replace(old, new, 1))
print('build72 ML-first contract updated')
