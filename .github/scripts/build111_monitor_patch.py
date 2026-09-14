from pathlib import Path

p = Path('lib/hcv_display_risk_fusion.dart')
s = p.read_text()
old = '''    final screenPresentButNotFullFrame =
        v3Analyzed &&
        !physicalDisplay &&
        !narrowThreeFrameFullFrameRecoveryV109 &&
        !videoPhotoSpatialFullFrameCorroboration &&
        temporalFrames >= 2 &&
        highAnyScreenFrames >= 2 &&
        highFullFrameScreenFrames == 0;
'''
new = '''    final stillSignals = _signals(ml);
    final stillPredictedClass = ml?['predictedClass']?.toString() ?? '';
    final stillScreenProbability =
        (ml?['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final stillScreenRisk =
        (ml?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final stillFullFrameRisk =
        (stillSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final stillContentAreaRisk =
        (stillSignals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
    final photoStillTemporalScreenCorroboration =
        photoTemporalMl != null &&
        v3Analyzed &&
        !mixedScene &&
        !physicalDisplay &&
        temporalFrames >= 3 &&
        highAnyScreenFrames == temporalFrames &&
        mlStrongScreenFrames >= 3 &&
        mlAverageScreenRisk >= 90.0 &&
        stillPredictedClass.startsWith('SCREEN_') &&
        stillScreenProbability >= 0.92 &&
        stillScreenRisk >= 92 &&
        stillFullFrameRisk >= 92 &&
        stillContentAreaRisk >= 85 &&
        base.decision == 'STRONG_DISPLAY_RISK';

    final screenPresentButNotFullFrame =
        v3Analyzed &&
        !physicalDisplay &&
        !narrowThreeFrameFullFrameRecoveryV109 &&
        !videoPhotoSpatialFullFrameCorroboration &&
        !photoStillTemporalScreenCorroboration &&
        temporalFrames >= 2 &&
        highAnyScreenFrames >= 2 &&
        highFullFrameScreenFrames == 0;
'''
if old not in s:
    raise SystemExit('target block not found')
s = s.replace(old, new, 1)
old2 = '''    final persistentVisualDisplay =
        strictPersistentVisualDisplay ||
        narrowThreeFrameFullFrameRecoveryV109 ||
        videoPhotoSpatialFullFrameCorroboration;
'''
new2 = '''    final persistentVisualDisplay =
        strictPersistentVisualDisplay ||
        narrowThreeFrameFullFrameRecoveryV109 ||
        videoPhotoSpatialFullFrameCorroboration ||
        photoStillTemporalScreenCorroboration;
'''
if old2 not in s:
    raise SystemExit('persistent block not found')
s = s.replace(old2, new2, 1)
old3 = '''        if (videoPhotoSpatialFullFrameCorroboration) {
          evidenceSources.add('VIDEO_PHOTO_SPATIAL_CORROBORATION');
          strongSources.add('VIDEO_PHOTO_SPATIAL_CORROBORATION');
          reasons.add('VIDEO_PHOTO_SPATIAL_STABLE_SCREEN_SEQUENCE');
          reasons.add('VIDEO_PHOTO_SPATIAL_FULL_FRAME_CORROBORATION');
        }
'''
new3 = old3 + '''        if (photoStillTemporalScreenCorroboration) {
          evidenceSources.add('PHOTO_STILL_TEMPORAL_SCREEN_CORROBORATION');
          strongSources.add('PHOTO_STILL_TEMPORAL_SCREEN_CORROBORATION');
          reasons.add('PHOTO_STILL_STRONG_SCREEN_WITH_TEMPORAL_SCREEN_SEQUENCE');
        }
'''
if old3 not in s:
    raise SystemExit('reason block not found')
s = s.replace(old3, new3, 1)
p.write_text(s)
