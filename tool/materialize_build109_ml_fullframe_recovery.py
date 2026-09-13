from pathlib import Path

path = Path('lib/hcv_display_risk_fusion.dart')
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    text = text.replace(old, new, 1)


replace_once(
    """    final highFullFrameScreenFrames =
        _temporalHighFullFrameScreenFrameCount(temporalMl);
    final mixedScene = _isV3MixedRealScene(temporalFrequencyProbe);
""",
    """    final highFullFrameScreenFrames =
        _temporalHighFullFrameScreenFrameCount(temporalMl);
    final recoveredFullFrameScreenFrames =
        _temporalRecoveredFullFrameScreenFrameCountV109(temporalMl);
    final mixedScene = _isV3MixedRealScene(temporalFrequencyProbe);
""",
    'recovered frame count insertion',
)

replace_once(
    """    final physicalDisplay =
        _isCompleteStrictPositiveHfr(temporalFrequencyProbe);

    final screenPresentButNotFullFrame =
        v3Analyzed &&
        !physicalDisplay &&
        temporalFrames >= 2 &&
        highAnyScreenFrames >= 2 &&
        highFullFrameScreenFrames == 0;
""",
    """    final physicalDisplay =
        _isCompleteStrictPositiveHfr(temporalFrequencyProbe);
    final mlStrongScreenFrames =
        (temporalMl?['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mlAverageScreenRisk =
        (temporalMl?['averageScreenReplayRiskScore'] as num?)?.toDouble() ??
            0.0;
    final narrowThreeFrameFullFrameRecoveryV109 =
        v3Analyzed &&
        !mixedScene &&
        !physicalDisplay &&
        temporalFrames == 3 &&
        highAnyScreenFrames == 3 &&
        highFullFrameScreenFrames == 0 &&
        recoveredFullFrameScreenFrames >= 2 &&
        _hasExactlyThreeHighProbabilityScreenSemanticFramesV109(temporalMl) &&
        mlStrongScreenFrames == 3 &&
        mlAverageScreenRisk >= 90.0 &&
        base.decision == 'STRONG_DISPLAY_RISK' &&
        base.reasons.contains('ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY') &&
        base.reasons.contains('ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION');

    final screenPresentButNotFullFrame =
        v3Analyzed &&
        !physicalDisplay &&
        !narrowThreeFrameFullFrameRecoveryV109 &&
        temporalFrames >= 2 &&
        highAnyScreenFrames >= 2 &&
        highFullFrameScreenFrames == 0;
""",
    'narrow recovery gate insertion',
)

replace_once(
    """    final persistentVisualDisplay =
        temporalFrames >= 2 && highFullFrameScreenFrames >= 2;

    if (physicalDisplay || persistentVisualDisplay) {
""",
    """    final strictPersistentVisualDisplay =
        temporalFrames >= 2 && highFullFrameScreenFrames >= 2;
    final persistentVisualDisplay = strictPersistentVisualDisplay ||
        narrowThreeFrameFullFrameRecoveryV109;

    if (physicalDisplay || persistentVisualDisplay) {
""",
    'persistent visual display extension',
)

replace_once(
    """      if (persistentVisualDisplay) {
        evidenceSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');
        strongSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');
        reasons.add('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES');
      }
""",
    """      if (persistentVisualDisplay) {
        evidenceSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');
        strongSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');
        if (narrowThreeFrameFullFrameRecoveryV109) {
          reasons.add('THREE_HIGH_PROBABILITY_SCREEN_SEMANTIC_FRAMES');
          reasons.add('TWO_FULL_FRAME_SCREEN_SAMPLES_WITH_CONTENT_SUPPORT_75');
          reasons.add('ML_THREE_FRAME_FULL_FRAME_SCREEN_RECOVERY_V109');
        } else {
          reasons.add('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES');
        }
      }
""",
    'recovery reasons insertion',
)

anchor = """  static bool _isCompleteStrictNegativeHfr(Map<String, dynamic>? probe) {
"""
helpers = """  static bool _hasExactlyThreeHighProbabilityScreenSemanticFramesV109(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (framesAnalyzed != 3 || rawFrames is! List || rawFrames.length != 3) {
      return false;
    }
    return rawFrames.every((rawFrame) {
      if (rawFrame is! Map) return false;
      final predictedClass = rawFrame['predictedClass']?.toString() ?? '';
      final probability =
          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      return predictedClass.startsWith('SCREEN_') && probability >= 0.90;
    });
  }

  static int _temporalRecoveredFullFrameScreenFrameCountV109(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List) return 0;
    var count = 0;
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map) continue;
      final predictedClass = rawFrame['predictedClass']?.toString() ?? '';
      final probability =
          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      final rawSignals = rawFrame['signals'];
      if (rawSignals is! Map) continue;
      final signals = Map<String, dynamic>.from(rawSignals);
      final fullFrame =
          (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      final contentArea =
          (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
      if (predictedClass.startsWith('SCREEN_') &&
          probability >= 0.90 &&
          fullFrame >= 90 &&
          contentArea >= 75) {
        count++;
      }
    }
    return count;
  }

"""
if text.count(anchor) != 1:
    raise SystemExit(f'helper insertion anchor: expected one match, found {text.count(anchor)}')
text = text.replace(anchor, helpers + anchor, 1)

# Guard the frozen V3 threshold: the existing strict temporal full-frame path
# must remain at contentAreaRiskScore >= 85. The new >=75 floor exists only in
# the dedicated V109 recovery helper above.
if text.count("contentArea >= 85") < 1:
    raise SystemExit('strict content-area >=85 gate missing after patch')
if text.count("contentArea >= 75") != 1:
    raise SystemExit('expected exactly one dedicated content-area >=75 recovery gate')
if text.count('ML_THREE_FRAME_FULL_FRAME_SCREEN_RECOVERY_V109') != 1:
    raise SystemExit('expected exactly one V109 recovery reason')

path.write_text(text)
print('BUILD109 ML full-frame recovery materialization applied exactly once')
