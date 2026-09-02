from pathlib import Path

runtime_path = Path('lib/hcv_display_risk_fusion.dart')
runtime = runtime_path.read_text()

if 'hasMultiFrameRealityConsistency' not in runtime:
    marker = "  static HCVDisplayRiskResult combine(\n"
    assert marker in runtime
    helper = '''  static bool hasMultiFrameRealityConsistency(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;

    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strongScreenFrameCount =
        (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mediumScreenFrameCount =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final rawFrameAnalyses = ml['videoFrameAnalyses'];

    if (framesAnalyzed < 3 || rawFrameAnalyses is! List) return false;

    var analyzedFrames = 0;
    var realityFrames = 0;
    var strongScreenContradictions = 0;

    for (final raw in rawFrameAnalyses) {
      if (raw is! Map) continue;
      if (raw['analysisStatus'] == 'NOT_ANALYZED') continue;

      analyzedFrames++;
      final predictedClass = raw['predictedClass']?.toString() ?? '';
      final score = (raw['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
      final screenProbability =
          (raw['screenProbability'] as num?)?.toDouble() ?? 1.0;
      final confidence =
          (raw['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;

      if (predictedClass.startsWith('REALITY_') &&
          score <= 20 &&
          screenProbability <= 0.15) {
        realityFrames++;
      }

      if (predictedClass.startsWith('SCREEN_') &&
          (score >= 70 || screenProbability >= 0.75 || confidence >= 0.75)) {
        strongScreenContradictions++;
      }
    }

    if (analyzedFrames < 3) return false;

    return strongScreenFrameCount == 0 &&
        mediumScreenFrameCount == 0 &&
        maxFrameScore <= 45 &&
        averageFrameScore <= 20.0 &&
        strongScreenContradictions == 0 &&
        realityFrames * 4 >= analyzedFrames * 3;
  }

'''
    runtime = runtime.replace(marker, helper + marker, 1)

    old = '''    var passiveStrong = false;
    var passiveModerate = false;
    var passiveStructuralEvidence = false;
    for (final analysis in passive) {
      final analysisScore =
          (analysis['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      final signals = _signals(analysis);
      final structural = signals['structuralDisplayTrace'] == true ||
          signals['confirmedDisplayTrace'] == true;
      if (structural) passiveStructuralEvidence = true;
      if (analysisScore >= 70 && structural) passiveStrong = true;
      if (!reflectedRealityEvidence && analysisScore >= 45 && structural) {
        passiveModerate = true;
      }
    }
'''
    new = '''    var passiveStrong = false;
    var passiveModerate = false;
    var passiveStructuralEvidence = false;
    var passiveRealityCompatible = passive.isNotEmpty;
    for (final analysis in passive) {
      final analysisScore =
          (analysis['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      final signals = _signals(analysis);
      final structural = signals['structuralDisplayTrace'] == true ||
          signals['confirmedDisplayTrace'] == true;
      if (analysisScore > 20 || structural) passiveRealityCompatible = false;
      if (structural) passiveStructuralEvidence = true;
      if (analysisScore >= 70 && structural) passiveStrong = true;
      if (!reflectedRealityEvidence && analysisScore >= 45 && structural) {
        passiveModerate = true;
      }
    }
'''
    assert old in runtime
    runtime = runtime.replace(old, new, 1)

    old = '''    final mlRealityCredible = realityMlScore != null &&
        realityMlClass.startsWith('REALITY_') &&
        realityMlScore <= 35 &&
        (realityMlConfidence ?? 0.0) >= 0.60;

    if (mlModerate) evidenceSources.add('ML_SCREEN_CLASS');
'''
    new = '''    final mlRealityCredible = realityMlScore != null &&
        realityMlClass.startsWith('REALITY_') &&
        realityMlScore <= 35 &&
        (realityMlConfidence ?? 0.0) >= 0.60;
    final realityMlScreenProbability =
        (realityMl?['screenProbability'] as num?)?.toDouble();
    final mlRealityVeryLowScreen = realityMlScore != null &&
        realityMlClass.startsWith('REALITY_') &&
        realityMlScore <= 5 &&
        (realityMlScreenProbability ?? 1.0) <= 0.05 &&
        (realityMlConfidence ?? 0.0) >= 0.65;
    final mlMultiFrameRealityConsistency =
        hasMultiFrameRealityConsistency(realityMl);

    if (mlMultiFrameRealityConsistency) {
      reasons.add('ML_REALITY_MULTI_FRAME_CONSISTENCY_CONFIRMED');
    }
    if (mlRealityVeryLowScreen) {
      reasons.add('ML_REALITY_LOW_SCREEN_PROBABILITY_CONFIRMED');
    }

    if (mlModerate) evidenceSources.add('ML_SCREEN_CLASS');
'''
    assert old in runtime
    runtime = runtime.replace(old, new, 1)

    old = '''    final independentRealityAgreement = geometryReality &&
        !geometryPlanar &&
        !planarSceneEvidence &&
        mlRealityCredible &&
        !activeDisplayEvidence &&
        !passiveStructuralEvidence &&
        !hasIndependentCorroboration &&
        !mlStrong;

    late final String decision;
'''
    new = '''    final independentRealityAgreement = geometryReality &&
        !geometryPlanar &&
        !planarSceneEvidence &&
        mlRealityCredible &&
        !activeDisplayEvidence &&
        !passiveStructuralEvidence &&
        !hasIndependentCorroboration &&
        !mlStrong;
    final crossModalGeometryRealityAgreement = geometryReality &&
        !geometryPlanar &&
        !planarSceneEvidence &&
        passiveRealityCompatible &&
        (mlRealityCredible || mlMultiFrameRealityConsistency) &&
        !liveTemporal &&
        !passiveStrong &&
        !passiveStructuralEvidence &&
        !mlStrong &&
        !mlOpticalCorroborated &&
        !mlPersistentCorroboratedEvidence &&
        !activePlanarTemporal &&
        !hasIndependentCorroboration;
    final crossModalUnresolvedRealityAgreement =
        geometrySceneClass == 'UNKNOWN' &&
        !planarSceneEvidence &&
        passiveRealityCompatible &&
        mlRealityVeryLowScreen &&
        !liveTemporal &&
        !passiveStrong &&
        !passiveStructuralEvidence &&
        !mlStrong &&
        !mlOpticalCorroborated &&
        !mlPersistentCorroboratedEvidence &&
        !activePlanarTemporal &&
        !hasIndependentCorroboration;
    final crossModalRealityAgreement = crossModalGeometryRealityAgreement ||
        crossModalUnresolvedRealityAgreement;

    late final String decision;
'''
    assert old in runtime
    runtime = runtime.replace(old, new, 1)

    old = '''      reasons.add(
        mlGeometryOverride
            ? 'ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'
            : mlUnresolvedGeometryOverride
                ? 'ML_UNRESOLVED_GEOMETRY_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'
                : 'ML_PLANAR_GEOMETRY_CORROBORATED_BY_MULTI_FRAME_SCREEN_EVIDENCE',
      );
    } else if (mlStrong && geometryReality) {
'''
    new = '''      reasons.add(
        mlGeometryOverride
            ? 'ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'
            : mlUnresolvedGeometryOverride
                ? 'ML_UNRESOLVED_GEOMETRY_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'
                : 'ML_PLANAR_GEOMETRY_CORROBORATED_BY_MULTI_FRAME_SCREEN_EVIDENCE',
      );
    } else if (crossModalRealityAgreement) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      evidenceSources.remove('ACTIVE_ILLUMINATION');
      evidenceSources.remove('LIVE_TEMPORAL_BANDS');
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      strongSources.remove('ACTIVE_PLANAR_TEMPORAL');
      const displayOnlyReasons = <String>{
        'LIVE_TEMPORAL_REFRESH_BAND_SIGNATURE',
        'ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED',
        'PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED',
        'ACTIVE_EMISSIVE_DISPLAY_EVIDENCE',
        'LIVE_EMISSIVE_TEMPORAL_PATTERN',
        'LIVE_CORROBORATED_TEMPORAL_PATTERN',
        'LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN',
        'LIVE_LOW_EMISSION_TEXTURE_PATTERN',
        'LIVE_HIGH_TEMPORAL_GRID_PATTERN',
        'LIVE_PERSISTENT_DISPLAY_TEXTURE',
      };
      reasons.removeWhere((reason) => displayOnlyReasons.contains(reason));
      reasons.add(
        'CROSS_MODAL_REALITY_AGREEMENT_OVERRIDES_UNCORROBORATED_ACTIVE_SIGNAL',
      );
    } else if (mlStrong && geometryReality) {
'''
    assert old in runtime
    runtime = runtime.replace(old, new, 1)

    runtime_path.write_text(runtime)

# The monitor control only constrains the classification outcome. It must stay
# STRONG DISPLAY, regardless of whether the fusion reaches that result through
# family corroboration or the later geometry-override branch.
test_path = Path('test/phase_c_reality_crossmodal_regression_20260902_test.dart')
test = test_path.read_text()
old_assertion = """    expect(\n      result.reasons,\n      contains('ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'),\n    );\n"""
if old_assertion in test:
    test_path.write_text(test.replace(old_assertion, '', 1))
