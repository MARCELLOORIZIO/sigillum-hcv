from pathlib import Path

path = Path('test/build71_video_semantic_persistence_regression_test.dart')
text = path.read_text()
replacements = {
"""  test('REALITY override is blocked by one semantic SCREEN frame', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        activeIndeterminate: true,
      ),
      _passive(score: 20),
      _reality43Ml(includeScreenFrame: true),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });
""":
"""  test('ML-first: one weak SCREEN frame cannot veto low-probability REALITY majority', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        activeIndeterminate: true,
      ),
      _passive(score: 20),
      _reality43Ml(includeScreenFrame: true),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('ML_FIRST_VIDEO_NO_SCREEN_MAJORITY_LOW_PROBABILITY'),
    );
  });
""",
"""  test('REALITY override is blocked by active display evidence', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        rawActive: true,
        activeDisplay: true,
        activeIndeterminate: true,
      ),
      _passive(score: 20),
      _reality43Ml(),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });
""":
"""  test('ML-first: active-only evidence is diagnostic, not a veto of strong REALITY ML', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        rawActive: true,
        activeDisplay: true,
        activeIndeterminate: true,
      ),
      _passive(score: 20),
      _reality43Ml(),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('ML_FIRST_VIDEO_NO_SCREEN_MAJORITY_LOW_PROBABILITY'),
    );
  });
""",
"""  test('SCREEN semantic persistence cannot defeat reflected REALITY evidence', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _d3Live(reflectedReality: true),
      _passive(score: 0),
      _d3Ml(),
    ]);

    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });
""":
"""  test('ML-first: reflected REALITY cannot veto unanimous high-probability SCREEN ML', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _d3Live(reflectedReality: true),
      _passive(score: 0),
      _d3Ml(),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(
      result.reasons,
      contains('ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY'),
    );
  });
""",
}
for old, new in replacements.items():
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one build71 contract block, found {count}')
    text = text.replace(old, new, 1)
path.write_text(text)
print('build71 ML-first contracts updated')
