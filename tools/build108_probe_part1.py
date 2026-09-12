from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)

probe_path = Path('lib/hcv_temporal_frequency_probe.dart')
fusion_path = Path('lib/hcv_display_risk_fusion.dart')
swift_path = Path('ios/Runner/AppDelegate.swift')
test_path = Path('test/hfr_v32_harmonic_reality_physics_test.dart')

probe = probe_path.read_text()
probe = replace_once(probe,
    '/// Native HFR V3.1 physical display probe.',
    '/// Native HFR V3.2 physical display probe.',
    'probe header')
probe = replace_once(probe,
    '''/// BUILD107 preserves the validated V3 full-frame display decision and adds a
/// same-session short-exposure sweep, higher-resolution row-by-time diagnostics,
/// and 2-D spatial lattice/moire diagnostics. New V3.1 physics is diagnostic
/// until physically validated. Absence of temporal display evidence is never
/// treated as positive proof of physical reality.''',
    '''/// BUILD108 preserves the validated V3 full-frame display decision, adds a
/// tightly corroborated harmonic-family recovery path, upgrades short-exposure
/// microtexture diagnostics, and adds an active illumination reality challenge.
/// Absence of temporal display evidence is never treated as positive proof of
/// physical reality; positive-reality physics remains diagnostic until iPhone validation.''',
    'probe description')
probe = replace_once(probe,
    '''    final spatialFamilyCellCount = _compatibleModalBinCount(spatialBins);
    final rowTimeFamilyCellCount = _compatibleModalBinCount(rowTimeBins);
    final medianRowTimeCoherence = _median(rowTimeCoherences) ?? 0.0;

    final legacyHfrCandidate = qualifiesCoherentDisplayPeriodicity(''',
    '''    final spatialFamilyCellCount = _compatibleModalBinCount(spatialBins);
    final harmonicAwareSpatialFamilyCellCount = harmonicAwareModalBinCount(spatialBins);
    final rowTimeFamilyCellCount = _compatibleModalBinCount(rowTimeBins);
    final medianRowTimeCoherence = _median(rowTimeCoherences) ?? 0.0;
    final advancedPhysicsV32 = _analyzeAdvancedDisplayPhysicsV32(raw);

    final legacyHfrCandidate = qualifiesCoherentDisplayPeriodicity(''',
    'advanced before hfr')
probe = replace_once(probe,
    '''    final allNineCellsSameDisplayFamily =
        displayFamilyGlobalHfrCandidate &&
        spatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20;
    final fullFrameDisplayV3 = qualifiesFullFrameDisplayV3(
      legacyHfrCandidate: displayFamilyGlobalHfrCandidate,
      spatialFamilyCellCount: spatialFamilyCellCount,
      rowTimeFamilyCellCount: rowTimeFamilyCellCount,
      medianRowTimeCoherence: medianRowTimeCoherence,
    );''',
    '''    final strictFullFrameDisplayV3 = qualifiesFullFrameDisplayV3(
      legacyHfrCandidate: displayFamilyGlobalHfrCandidate,
      spatialFamilyCellCount: spatialFamilyCellCount,
      rowTimeFamilyCellCount: rowTimeFamilyCellCount,
      medianRowTimeCoherence: medianRowTimeCoherence,
    );
    final harmonicRecoveryGlobalHfrCandidate =
        qualifiesHarmonicRecoveredGlobalHfrV32(
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
    final harmonicExposureCorroborated =
        advancedPhysicsV32['harmonicRecoveryExposureCorroborated'] == true;
    final harmonicFullFrameDisplayRecovery =
        !strictFullFrameDisplayV3 &&
        harmonicRecoveryGlobalHfrCandidate &&
        harmonicAwareSpatialFamilyCellCount == 9 &&
        rowTimeFamilyCellCount == 9 &&
        medianRowTimeCoherence >= 0.20 &&
        harmonicExposureCorroborated;
    final fullFrameDisplayV3 =
        strictFullFrameDisplayV3 || harmonicFullFrameDisplayRecovery;
    final allNineCellsSameDisplayFamily =
        fullFrameDisplayV3 &&
        rowTimeFamilyCellCount == 9 &&
        (spatialFamilyCellCount == 9 ||
            harmonicAwareSpatialFamilyCellCount == 9);''',
    'full frame recovery')
probe = replace_once(probe,
    '''    const fullFrameRealityV3 = false;
    final advancedPhysicsV31 = _analyzeAdvancedDisplayPhysicsV31(raw);
    final coherentDisplayPeriodicity = fullFrameDisplayV3;''',
    '''    const fullFrameRealityV3 = false;
    final activeIlluminationV32 = _analyzeActiveIlluminationRealityV32(raw);
    final coherentDisplayPeriodicity = fullFrameDisplayV3;''',
    'old advanced placement')
probe = replace_once(probe,
    '''      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V31_ADVANCED_PHYSICS_DIAGNOSTIC_ONLY',''',
    '''      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V32_HARMONIC_DISPLAY_RECOVERY_CANDIDATE;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',''',
    'type role')
probe = replace_once(probe,
    '''        'displayFamilyGlobalHfrCandidateV3': displayFamilyGlobalHfrCandidate,
        'localDisplayLikeCellCountDecisionGate': false,''',
    '''        'displayFamilyGlobalHfrCandidateV3': displayFamilyGlobalHfrCandidate,
        'harmonicRecoveryGlobalHfrCandidateV32': harmonicRecoveryGlobalHfrCandidate,
        'harmonicFullFrameDisplayRecoveryV32': harmonicFullFrameDisplayRecovery,
        'harmonicRecoveryExposureCorroboratedV32': harmonicExposureCorroborated,
        'harmonicAwareSpatialFamilyCellCount': harmonicAwareSpatialFamilyCellCount,
        'localDisplayLikeCellCountDecisionGate': false,''',
    'evidence additions')
probe = replace_once(probe,
    '''        'spatialFamilyCellCount': spatialFamilyCellCount,
        'rowTimeFamilyCellCount': rowTimeFamilyCellCount,
        'medianRowTimeCoherence': medianRowTimeCoherence,
        'classificationPolicy':
            'BUILD107_VALIDATED_V3_DISPLAY_UNCHANGED;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE;V31_ADVANCED_DISPLAY_PHYSICS_DIAGNOSTIC_ONLY',
      },
      'advancedDisplayPhysicsV31': advancedPhysicsV31,''',
    '''        'spatialFamilyCellCount': spatialFamilyCellCount,
        'harmonicAwareSpatialFamilyCellCount': harmonicAwareSpatialFamilyCellCount,
        'rowTimeFamilyCellCount': rowTimeFamilyCellCount,
        'medianRowTimeCoherence': medianRowTimeCoherence,
        'harmonicDisplayRecovery': harmonicFullFrameDisplayRecovery,
        'displayFamilyMode': harmonicFullFrameDisplayRecovery
            ? 'HARMONIC_2_TO_1_CORROBORATED'
            : 'STRICT_SINGLE_FAMILY',
        'classificationPolicy':
            'BUILD108_VALIDATED_V3_DISPLAY_PRESERVED;HARMONIC_2_TO_1_REQUIRES_GLOBAL_HFR_PLUS_ROW_TIME_9_OF_9_PLUS_TWO_SHORT_EXPOSURE_CORROBORATIONS;NO_TEMPORAL_SIGNATURE_IS_NOT_REALITY;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',
      },
      'advancedDisplayPhysicsV32': advancedPhysicsV32,
      'activeIlluminationRealityV32': activeIlluminationV32,''',
    'display evidence advanced')
probe = replace_once(probe,
    '''      'note': 'V3.1 BUILD107 preserves validated V3 full-frame display/mixed-scene decisions and adds same-session exposure sweep, 128-bin row-time diagnostics, and 2-D microtexture lattice diagnostics. New advanced physics is diagnostic-only pending iPhone validation. A quiet temporal signature is explicitly not positive reality evidence.',''',
    '''      'note': 'V3.2 BUILD108 preserves validated V3 decisions, adds a tightly corroborated 2:1 harmonic display-family recovery, 64x64 short-exposure microtexture diagnostics, and an active illumination reality challenge. Quiet temporal signatures remain non-evidence for reality; active reality physics is diagnostic-only pending iPhone validation.',''',
    'note')
probe = replace_once(probe,
    '  static bool qualifiesNoTemporalDisplaySignatureV31({',
    '''  static bool qualifiesHarmonicRecoveredGlobalHfrV32({
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
        medianCellFrequencyStability >= 0.80 &&
        medianCellPhaseStepConsistency >= 0.40 &&
        periodicCellCount >= 6;
  }

  static bool qualifiesNoTemporalDisplaySignatureV31({''',
    'harmonic global function')
probe = replace_once(probe,
    '''  static int _compatibleModalBinCount(List<int> bins) {
    final positive = bins.where((bin) => bin > 0).toList(growable: false);
    if (positive.isEmpty) return 0;
    var best = 0;
    for (final candidate in positive) {
      final count = positive.where((bin) => (bin - candidate).abs() <= 1).length;
      if (count > best) best = count;
    }
    return best;
  }


  static Map<String, dynamic> _analyzeAdvancedDisplayPhysicsV31(''',
    '''  static int _compatibleModalBinCount(List<int> bins) {
    final positive = bins.where((bin) => bin > 0).toList(growable: false);
    if (positive.isEmpty) return 0;
    var best = 0;
    for (final candidate in positive) {
      final count = positive.where((bin) => (bin - candidate).abs() <= 1).length;
      if (count > best) best = count;
    }
    return best;
  }

  static int harmonicAwareModalBinCount(List<int> bins) {
    final positive = bins.where((bin) => bin > 0).toList(growable: false);
    if (positive.isEmpty) return 0;
    bool compatible(int a, int b) {
      if ((a - b).abs() <= 1) return true;
      final lower = min(a, b);
      final upper = max(a, b);
      if (lower < 2) return false;
      return (upper - 2 * lower).abs() <= 1;
    }
    var best = 0;
    for (final candidate in positive) {
      final count = positive.where((bin) => compatible(bin, candidate)).length;
      if (count > best) best = count;
    }
    return best;
  }

  static int _compatibleLatticeSignatureCount(
    List<Map<String, dynamic>> lattice,
  ) {
    if (lattice.isEmpty) return 0;
    var best = 0;
    for (final candidate in lattice) {
      final hx = (candidate['horizontalPeakLag'] as num?)?.toInt() ?? 0;
      final vy = (candidate['verticalPeakLag'] as num?)?.toInt() ?? 0;
      if (hx <= 0 || vy <= 0) continue;
      final count = lattice.where((entry) {
        final ex = (entry['horizontalPeakLag'] as num?)?.toInt() ?? 0;
        final ey = (entry['verticalPeakLag'] as num?)?.toInt() ?? 0;
        return ex > 0 && ey > 0 &&
            (ex - hx).abs() <= 1 &&
            (ey - vy).abs() <= 1;
      }).length;
      if (count > best) best = count;
    }
    return best;
  }

  static Map<String, dynamic> _analyzeAdvancedDisplayPhysicsV32(''',
    'advanced rename helpers')
probe_path.write_text(probe)
