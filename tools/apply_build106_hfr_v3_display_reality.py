from pathlib import Path

probe_path = Path('lib/hcv_temporal_frequency_probe.dart')
fusion_path = Path('lib/hcv_display_risk_fusion.dart')
test_path = Path('test/hfr_v3_fullframe_mixed_scene_test.dart')

probe = probe_path.read_text()
fusion = fusion_path.read_text()
tests = test_path.read_text()

old_probe_block = '''    final legacyHfrCandidate = qualifiesCoherentDisplayPeriodicity(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      globalModulationDepth: globalModulationDepth,
      globalSpectralConcentration: globalSpectralConcentration,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      medianCellPhaseStepConsistency: medianCellPhase,
      periodicCellCount: periodicCellCount,
      stableCellCount: stableCellCount,
    );
    // BUILD105: all nine cells must belong to one physical frequency
    // family, but individual cells are allowed to be locally weaker because
    // content, glare and perspective can depress periodicity/phase metrics.
    // The unchanged strict legacy HFR gate still supplies the global physical
    // proof, while 9/9 spatial + row-time family coherence proves full-frame
    // coverage. This is deliberately not a relaxation of the HFR thresholds.
    final allNineCellsSameDisplayFamily =
        legacyHfrCandidate &&
        spatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20;
    final fullFrameDisplayV3 = qualifiesFullFrameDisplayV3(
      legacyHfrCandidate: legacyHfrCandidate,
      spatialFamilyCellCount: spatialFamilyCellCount,
      rowTimeFamilyCellCount: rowTimeFamilyCellCount,
      medianRowTimeCoherence: medianRowTimeCoherence,
    );
    final mixedSceneDetected =
        displayLikeCellCount > 0 && !fullFrameDisplayV3;
    final fullFrameRealityV3 =
        !mixedSceneDetected &&
        displayLikeCellCount == 0 &&
        realityLikeCellCount >= 6;
    final coherentDisplayPeriodicity = fullFrameDisplayV3;
'''
new_probe_block = '''    final legacyHfrCandidate = qualifiesCoherentDisplayPeriodicity(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      globalModulationDepth: globalModulationDepth,
      globalSpectralConcentration: globalSpectralConcentration,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      medianCellPhaseStepConsistency: medianCellPhase,
      periodicCellCount: periodicCellCount,
      stableCellCount: stableCellCount,
    );
    // BUILD106: the global physical display proof keeps every strict median,
    // spectral, phase, exposure and periodic-cell gate from V2. The old
    // stableCellCount >= 6 veto is not reused once V3 can prove that all nine
    // cells belong to the same spatial + row-time frequency family. This is a
    // family-coherence correction, not a generic threshold reduction.
    final displayFamilyGlobalHfrCandidate =
        qualifiesDisplayFamilyGlobalHfrV3(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      globalModulationDepth: globalModulationDepth,
      globalSpectralConcentration: globalSpectralConcentration,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      medianCellPhaseStepConsistency: medianCellPhase,
      periodicCellCount: periodicCellCount,
    );
    final allNineCellsSameDisplayFamily =
        displayFamilyGlobalHfrCandidate &&
        spatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20;
    final fullFrameDisplayV3 = qualifiesFullFrameDisplayV3(
      legacyHfrCandidate: displayFamilyGlobalHfrCandidate,
      spatialFamilyCellCount: spatialFamilyCellCount,
      rowTimeFamilyCellCount: rowTimeFamilyCellCount,
      medianRowTimeCoherence: medianRowTimeCoherence,
    );
    final mixedSceneDetected =
        displayLikeCellCount > 0 && !fullFrameDisplayV3;
    final fullFrameRealityV3 = qualifiesFullFrameRealityV3(
      actualFps: actualFps,
      framesAnalyzed: acceptedFrames,
      shortExposureVerified: raw['shortExposureVerified'] == true,
      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,
      fullFrameDisplay: fullFrameDisplayV3,
      mixedSceneDetected: mixedSceneDetected,
      displayLikeCellCount: displayLikeCellCount,
      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,
      medianCellPeriodicityStrength: medianCellPeriodicity,
      medianCellFrequencyStability: medianCellStability,
      periodicCellCount: periodicCellCount,
      stableCellCount: stableCellCount,
    );
    final coherentDisplayPeriodicity = fullFrameDisplayV3;
'''
if old_probe_block not in probe:
    raise SystemExit('BUILD105 probe decision block not found')
probe = probe.replace(old_probe_block, new_probe_block, 1)

probe = probe.replace(
    "        'legacyV2HfrCandidate': legacyHfrCandidate,\n",
    "        'legacyV2HfrCandidate': legacyHfrCandidate,\n        'displayFamilyGlobalHfrCandidateV3': displayFamilyGlobalHfrCandidate,\n        'localDisplayLikeCellCountDecisionGate': false,\n",
    1,
)
probe = probe.replace(
    "            'STRICT_GLOBAL_HFR_PLUS_ALL_9_CELLS_ONE_FREQUENCY_FAMILY;_LOCAL_WEAK_CELLS_ALLOWED;PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE',",
    "            'BUILD106_GLOBAL_HFR_PLUS_ALL_9_CELLS_ONE_FREQUENCY_FAMILY;LOCAL_STABLE_CELL_COUNT_DIAGNOSTIC_ONLY;STRONG_LOW_PERIODICITY_SIGNATURE_IS_PHYSICAL_REALITY;PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE',",
    1,
)
probe = probe.replace(
    "      'note': 'V3 BUILD105 combines native 240/120 fps timing, strict global HFR evidence, 3x3 row-profile rolling-shutter band evolution and row-by-time coherence. Full-frame display requires all nine cells in one spatial and row-time frequency family, while locally weaker cells are tolerated. Partial display coverage remains a mixed real scene.',",
    "      'note': 'V3 BUILD106 combines native 240/120 fps timing, strict global HFR evidence, 3x3 row-profile rolling-shutter band evolution and row-by-time coherence. Full-frame display uses strict global medians plus all-nine family coherence without a redundant local stable-cell-count veto. Reality V3 is an independent strong low-periodicity physical signature. Partial display coverage remains a mixed real scene.',",
    1,
)

old_fullframe_method = '''  static bool qualifiesFullFrameDisplayV3({
    required bool legacyHfrCandidate,
    required int spatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
  }) {
    return legacyHfrCandidate &&
        spatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20;
  }
'''
new_fullframe_method = '''  static bool qualifiesDisplayFamilyGlobalHfrV3({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required double? dominantTemporalFrequencyHz,
    required double globalModulationDepth,
    required double globalSpectralConcentration,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required double medianCellPhaseStepConsistency,
    required int periodicCellCount,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    if (dominantTemporalFrequencyHz == null ||
        dominantTemporalFrequencyHz < 40.0 ||
        dominantTemporalFrequencyHz > 120.0 ||
        dominantTemporalFrequencyHz > actualFps / 2.0 + 1.0) {
      return false;
    }
    return globalModulationDepth >= 0.75 &&
        globalSpectralConcentration >= 0.85 &&
        medianCellPeriodicityStrength >= 0.12 &&
        medianCellFrequencyStability >= 0.85 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6;
  }

  static bool qualifiesFullFrameDisplayV3({
    required bool legacyHfrCandidate,
    required int spatialFamilyCellCount,
    required int rowTimeFamilyCellCount,
    required double medianRowTimeCoherence,
  }) {
    return legacyHfrCandidate &&
        spatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20;
  }

  static bool qualifiesFullFrameRealityV3({
    required double? actualFps,
    required int framesAnalyzed,
    required bool shortExposureVerified,
    required bool exposureLocked,
    required bool fullFrameDisplay,
    required bool mixedSceneDetected,
    required int displayLikeCellCount,
    required double? dominantTemporalFrequencyHz,
    required double medianCellPeriodicityStrength,
    required double medianCellFrequencyStability,
    required int periodicCellCount,
    required int stableCellCount,
  }) {
    if (actualFps == null || actualFps < 120.0) return false;
    if (framesAnalyzed < 60 || !shortExposureVerified || !exposureLocked) {
      return false;
    }
    if (fullFrameDisplay || mixedSceneDetected || displayLikeCellCount != 0) {
      return false;
    }
    if (dominantTemporalFrequencyHz == null ||
        dominantTemporalFrequencyHz >= 10.0) {
      return false;
    }
    return medianCellPeriodicityStrength < 0.05 &&
        medianCellFrequencyStability < 0.60 &&
        periodicCellCount <= 1 &&
        stableCellCount <= 1;
  }
'''
if old_fullframe_method not in probe:
    raise SystemExit('full-frame V3 method not found')
probe = probe.replace(old_fullframe_method, new_fullframe_method, 1)

old_optical_helper = '''  static bool _hasNoPhysicalDisplayTrace(Map<String, dynamic>? optical) {
    if (optical == null || optical['analysisStatus'] == 'NOT_ANALYZED') {
      return false;
    }
    final frames = (optical['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final score = (optical['screenReplayRiskScore'] as num?)?.toInt();
    if (frames < 12 || score == null || score > 20) return false;

    final signals = _signals(optical);
    const hardSignalKeys = <String>[
      'displayFlicker',
      'pixelGridOrMoireHint',
      'uniformPixelGrid',
      'localRefreshFlicker',
      'horizontalRefreshBands',
      'pairedLocalRefresh',
      'temporalScreenPulse',
      'structuralDisplayTrace',
      'strongDisplayTrace',
      'confirmedDisplayTrace',
      'periodicLightTrace',
      'opticalCorroboratedTrace',
    ];
    return hardSignalKeys.every((key) => signals[key] != true);
  }
'''
new_optical_helper = old_optical_helper + '''
  static bool _hasNoStructuralOpticalDisplayTraceForV3Reality(
    Map<String, dynamic>? optical,
  ) {
    if (optical == null || optical['analysisStatus'] == 'NOT_ANALYZED') {
      return false;
    }
    final frames = (optical['framesAnalyzed'] as num?)?.toInt() ?? 0;
    if (frames < 12) return false;

    final signals = _signals(optical);
    // BUILD106: when native HFR V3 gives a strong physical-reality signature,
    // temporal-only passive cues (local flicker / paired pulse) are not allowed
    // to veto it. Spatial/structural screen evidence still blocks the override.
    const structuralSignalKeys = <String>[
      'pixelGridOrMoireHint',
      'uniformPixelGrid',
      'horizontalRefreshBands',
      'structuralDisplayTrace',
      'confirmedDisplayTrace',
      'periodicLightTrace',
      'opticalCorroboratedTrace',
    ];
    return structuralSignalKeys.every((key) => signals[key] != true);
  }
'''
if old_optical_helper not in fusion:
    raise SystemExit('optical helper not found')
fusion = fusion.replace(old_optical_helper, new_optical_helper, 1)

old_reality_block = '''    final physicalReality =
        _isStrictPhysicalRealityHfr(temporalFrequencyProbe);
    final cleanOptical = _hasNoPhysicalDisplayTrace(passiveOptical);
    final realityEvidence = physicalReality &&
        cleanOptical &&
        base.strongSources.isEmpty &&
        temporalFrames >= 2 &&
        highFullFrameScreenFrames == 0;

    if (!realityEvidence) return null;

    final reasons = base.reasons
        .where(
          (reason) =>
              reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
              reason != 'LIVE_PROBE_MISSING',
        )
        .toList()
      ..add('HFR_V3_FULL_FRAME_REALITY_SIGNATURE')
      ..add('NO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLE')
      ..add('NO_OPTICAL_DISPLAY_TRACE')
      ..add('DUAL_EVIDENCE_V3_ACTIVE');
'''
new_reality_block = '''    final physicalReality =
        _isStrictPhysicalRealityHfr(temporalFrequencyProbe);
    final cleanOptical = _hasNoPhysicalDisplayTrace(passiveOptical);
    final noStructuralOpticalDisplayTrace =
        _hasNoStructuralOpticalDisplayTraceForV3Reality(passiveOptical);
    final realityEvidence = physicalReality &&
        noStructuralOpticalDisplayTrace &&
        base.strongSources.isEmpty &&
        temporalFrames >= 2 &&
        highAnyScreenFrames == 0 &&
        highFullFrameScreenFrames == 0;

    if (!realityEvidence) return null;

    final reasons = base.reasons
        .where(
          (reason) =>
              reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
              reason != 'LIVE_PROBE_MISSING',
        )
        .toList()
      ..add('HFR_V3_FULL_FRAME_REALITY_SIGNATURE')
      ..add('NO_HIGH_SCREEN_TEMPORAL_SAMPLE')
      ..add('NO_STRUCTURAL_OPTICAL_DISPLAY_TRACE');
    if (!cleanOptical) {
      reasons.add('HFR_V3_REALITY_OVERRIDES_TEMPORAL_ONLY_PASSIVE_OPTICAL_CUE');
    }
    reasons.add('DUAL_EVIDENCE_V3_ACTIVE');
'''
if old_reality_block not in fusion:
    raise SystemExit('dual-evidence reality block not found')
fusion = fusion.replace(old_reality_block, new_reality_block, 1)

# Append BUILD106 tests before the final closing brace of main().
marker = "  test('screen presence without full-frame support cannot promote a real room'"
if marker not in tests:
    raise SystemExit('expected V3 test marker not found')
insert = r'''

  test('BUILD105 full-frame photo passes V3 family gate despite five locally stable cells', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayFamilyGlobalHfrV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.261673,
        globalModulationDepth: 0.962852,
        globalSpectralConcentration: 0.907329,
        medianCellPeriodicityStrength: 0.217227,
        medianCellFrequencyStability: 0.903614,
        medianCellPhaseStepConsistency: 0.684237,
        periodicCellCount: 9,
      ),
      isTrue,
    );
  });

  test('V3 family gate does not weaken global median stability or periodic-cell requirements', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayFamilyGlobalHfrV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.26,
        globalModulationDepth: 0.96,
        globalSpectralConcentration: 0.91,
        medianCellPeriodicityStrength: 0.22,
        medianCellFrequencyStability: 0.84,
        medianCellPhaseStepConsistency: 0.68,
        periodicCellCount: 9,
      ),
      isFalse,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesDisplayFamilyGlobalHfrV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        dominantTemporalFrequencyHz: 100.26,
        globalModulationDepth: 0.96,
        globalSpectralConcentration: 0.91,
        medianCellPeriodicityStrength: 0.22,
        medianCellFrequencyStability: 0.90,
        medianCellPhaseStepConsistency: 0.68,
        periodicCellCount: 5,
      ),
      isFalse,
    );
  });

  test('BUILD105 framed artwork video qualifies as strong physical Reality V3', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 2.864590,
        medianCellPeriodicityStrength: 0.006995,
        medianCellFrequencyStability: 0.168675,
        periodicCellCount: 0,
        stableCellCount: 0,
      ),
      isTrue,
    );
  });

  test('BUILD105 desk video qualifies as physical Reality V3 despite one weak periodic cell', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 2.864562,
        medianCellPeriodicityStrength: 0.021898,
        medianCellFrequencyStability: 0.373494,
        periodicCellCount: 1,
        stableCellCount: 1,
      ),
      isTrue,
    );
  });

  test('Reality V3 rejects mixed scenes and true high-frequency display signatures', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: true,
        displayLikeCellCount: 2,
        dominantTemporalFrequencyHz: 2.8646,
        medianCellPeriodicityStrength: 0.012,
        medianCellFrequencyStability: 0.29,
        periodicCellCount: 4,
        stableCellCount: 2,
      ),
      isFalse,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameRealityV3(
        actualFps: 240.62,
        framesAnalyzed: 84,
        shortExposureVerified: true,
        exposureLocked: true,
        fullFrameDisplay: false,
        mixedSceneDetected: false,
        displayLikeCellCount: 0,
        dominantTemporalFrequencyHz: 100.26,
        medianCellPeriodicityStrength: 0.01,
        medianCellFrequencyStability: 0.20,
        periodicCellCount: 1,
        stableCellCount: 1,
      ),
      isFalse,
    );
  });

  test('Reality V3 resolves weak artwork semantics without changing ML thresholds', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(<double>[0.7543, 0.6020]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: true,
        mixed: false,
        displayCells: 0,
        spatialFamilyCells: 7,
        rowTimeFamilyCells: 9,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('HFR_V3_FULL_FRAME_REALITY_SIGNATURE'));
  });

  test('Reality V3 overrides temporal-only passive optical false positive on desk', () {
    final temporalOnlyOptical = <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 15,
      'screenReplayRiskScore': 75,
      'signals': <String, dynamic>{
        'displayFlicker': false,
        'pixelGridOrMoireHint': false,
        'uniformPixelGrid': false,
        'localRefreshFlicker': true,
        'horizontalRefreshBands': false,
        'pairedLocalRefresh': true,
        'temporalScreenPulse': true,
        'structuralDisplayTrace': false,
        'strongDisplayTrace': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'opticalCorroboratedTrace': false,
      },
    };
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: temporalOnlyOptical,
      ml: temporalV3(<double>[0.7381, 0.1400]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: true,
        mixed: false,
        displayCells: 0,
        spatialFamilyCells: 6,
        rowTimeFamilyCells: 9,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(
      result.reasons,
      contains('HFR_V3_REALITY_OVERRIDES_TEMPORAL_ONLY_PASSIVE_OPTICAL_CUE'),
    );
  });

  test('Reality V3 cannot override structural optical screen evidence', () {
    final structuralOptical = opticalCleanV3();
    final signals = Map<String, dynamic>.from(structuralOptical['signals'] as Map);
    signals['pixelGridOrMoireHint'] = true;
    structuralOptical['signals'] = signals;
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: structuralOptical,
      ml: temporalV3(<double>[0.30, 0.25]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: true,
        mixed: false,
      ),
    );
    expect(result.decision, 'NON_CONCLUSIVE');
  });
'''
# The file ends with the closing brace for main. Insert directly before it.
last = tests.rfind('\n}')
if last < 0:
    raise SystemExit('test main closing brace not found')
tests = tests[:last] + insert + tests[last:]

probe_path.write_text(probe)
fusion_path.write_text(fusion)
test_path.write_text(tests)
print('BUILD106 HFR V3 display/reality patch applied')
