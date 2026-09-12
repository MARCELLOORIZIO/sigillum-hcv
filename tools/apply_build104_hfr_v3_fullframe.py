from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch anchor: {label}')
    if text.count(old) != 1:
        raise SystemExit(f'non-unique patch anchor: {label} count={text.count(old)}')
    return text.replace(old, new, 1)


probe_path = Path('lib/hcv_temporal_frequency_probe.dart')
probe = probe_path.read_text()

probe = replace_once(
    probe,
    """/// Shadow-only native physical probe for display refresh / PWM periodicity.\n///\n/// V2 deliberately does NOT use Flutter camera recording or FFmpeg. The\n/// Flutter CameraController is released before this call, then iOS owns the\n/// camera in a short isolated AVCaptureSession and returns row profiles from\n/// consecutive CMSampleBuffers together with their real presentation times.\n""",
    """/// Native HFR V3 physical probe for display-vs-reality evidence.\n///\n/// V3 keeps the isolated AVFoundation/CMSampleBuffer capture introduced by V2\n/// and adds explicit 3x3 full-frame consistency plus row-by-time analysis.\n/// A display verdict requires all nine cells to belong to one coherent physical\n/// display family; partial display-like coverage is a mixed real scene.\n""",
    'probe header',
)

probe = replace_once(
    probe,
    """    final cellResults = <Map<String, dynamic>>[];\n    for (var cell = 0; cell < 9; cell++) {\n      final result = HCVTemporalFrequencyMath.analyzeRowProfileSequence(\n        cellSequences[cell],\n      );\n      cellResults.add({'row': cell ~/ 3, 'column': cell % 3, ...result});\n    }\n""",
    """    final cellResults = <Map<String, dynamic>>[];\n    for (var cell = 0; cell < 9; cell++) {\n      final rolling = HCVTemporalFrequencyMath.analyzeRowProfileSequence(\n        cellSequences[cell],\n      );\n      final rowTime = HCVTemporalFrequencyMath.analyzeRowTimeMatrix(\n        cellSequences[cell],\n      );\n      cellResults.add({\n        'row': cell ~/ 3,\n        'column': cell % 3,\n        ...rolling,\n        ...rowTime,\n      });\n    }\n""",
    'cell analysis',
)

probe = replace_once(
    probe,
    """    final phaseConsistencies =\n        cellResults\n            .map((e) => (e['phaseStepConsistency'] as num?)?.toDouble())\n            .whereType<double>()\n            .toList()\n          ..sort();\n\n    final configuredFps = (raw['configuredFrameRate'] as num?)?.toDouble();\n""",
    """    final phaseConsistencies =\n        cellResults\n            .map((e) => (e['phaseStepConsistency'] as num?)?.toDouble())\n            .whereType<double>()\n            .toList()\n          ..sort();\n    final rowTimeCoherences =\n        cellResults\n            .map((e) => (e['rowTimeCoherenceScore'] as num?)?.toDouble())\n            .whereType<double>()\n            .toList()\n          ..sort();\n\n    final configuredFps = (raw['configuredFrameRate'] as num?)?.toDouble();\n""",
    'row time collection',
)

old_gate = """    final periodicCellCount = cellResults.where((entry) {\n      return ((entry['periodicityStrength'] as num?)?.toDouble() ?? 0.0) >=\n          0.10;\n    }).length;\n    final stableCellCount = cellResults.where((entry) {\n      return ((entry['dominantFrequencyStability'] as num?)?.toDouble() ??\n              0.0) >=\n          0.80;\n    }).length;\n    final coherentDisplayPeriodicity = qualifiesCoherentDisplayPeriodicity(\n      actualFps: actualFps,\n      framesAnalyzed: acceptedFrames,\n      shortExposureVerified: raw['shortExposureVerified'] == true,\n      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,\n      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,\n      globalModulationDepth: globalModulationDepth,\n      globalSpectralConcentration: globalSpectralConcentration,\n      medianCellPeriodicityStrength: medianCellPeriodicity,\n      medianCellFrequencyStability: medianCellStability,\n      medianCellPhaseStepConsistency: medianCellPhase,\n      periodicCellCount: periodicCellCount,\n      stableCellCount: stableCellCount,\n    );\n\n    return {\n      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',\n      'analysisStatus': 'ANALYZED',\n      'decisionRole':\n          'DECISIONAL_ONLY_FOR_STRICT_HFR_COHERENT_DISPLAY_PERIODICITY',\n      'productionDecisionChanged': coherentDisplayPeriodicity,\n      'coherentDisplayPeriodicity': coherentDisplayPeriodicity,\n      'coherentDisplayPeriodicityEvidence': {\n        'dominantTemporalFrequencyHz': dominantTemporalFrequencyHz,\n        'globalModulationDepth': globalModulationDepth,\n        'globalSpectralConcentration': globalSpectralConcentration,\n        'medianCellPeriodicityStrength': medianCellPeriodicity,\n        'medianCellFrequencyStability': medianCellStability,\n        'medianCellPhaseStepConsistency': medianCellPhase,\n        'periodicCellCount': periodicCellCount,\n        'stableCellCount': stableCellCount,\n        'requiredPeriodicCells': 6,\n        'requiredStableCells': 6,\n      },\n"""

new_gate = """    final periodicCellCount = cellResults.where((entry) {\n      return ((entry['periodicityStrength'] as num?)?.toDouble() ?? 0.0) >=\n          0.10;\n    }).length;\n    final stableCellCount = cellResults.where((entry) {\n      return ((entry['dominantFrequencyStability'] as num?)?.toDouble() ??\n              0.0) >=\n          0.80;\n    }).length;\n    final displayLikeCellCount = cellResults.where(_isV3DisplayLikeCell).length;\n    final realityLikeCellCount = cellResults.where(_isV3RealityLikeCell).length;\n    final indeterminateCellCount = 9 - displayLikeCellCount - realityLikeCellCount;\n    final spatialBins = cellResults\n        .map((entry) => (entry['dominantRowFrequencyBin'] as num?)?.toInt() ?? 0)\n        .toList(growable: false);\n    final rowTimeBins = cellResults\n        .map((entry) =>\n            (entry['rowTimeDominantTemporalFrequencyBin'] as num?)?.toInt() ?? 0)\n        .toList(growable: false);\n    final spatialFamilyCellCount = _compatibleModalBinCount(spatialBins);\n    final rowTimeFamilyCellCount = _compatibleModalBinCount(rowTimeBins);\n    final medianRowTimeCoherence = _median(rowTimeCoherences) ?? 0.0;\n\n    final legacyHfrCandidate = qualifiesCoherentDisplayPeriodicity(\n      actualFps: actualFps,\n      framesAnalyzed: acceptedFrames,\n      shortExposureVerified: raw['shortExposureVerified'] == true,\n      exposureLocked: raw['exposureLockedForEntireNativeCapture'] == true,\n      dominantTemporalFrequencyHz: dominantTemporalFrequencyHz,\n      globalModulationDepth: globalModulationDepth,\n      globalSpectralConcentration: globalSpectralConcentration,\n      medianCellPeriodicityStrength: medianCellPeriodicity,\n      medianCellFrequencyStability: medianCellStability,\n      medianCellPhaseStepConsistency: medianCellPhase,\n      periodicCellCount: periodicCellCount,\n      stableCellCount: stableCellCount,\n    );\n    final allNineCellsSameDisplayFamily =\n        displayLikeCellCount == 9 &&\n        spatialFamilyCellCount == 9 &&\n        rowTimeFamilyCellCount == 9;\n    final fullFrameDisplayV3 = qualifiesFullFrameDisplayV3(\n      legacyHfrCandidate: legacyHfrCandidate,\n      displayLikeCellCount: displayLikeCellCount,\n      spatialFamilyCellCount: spatialFamilyCellCount,\n      rowTimeFamilyCellCount: rowTimeFamilyCellCount,\n      medianRowTimeCoherence: medianRowTimeCoherence,\n    );\n    final mixedSceneDetected =\n        displayLikeCellCount > 0 && !allNineCellsSameDisplayFamily;\n    final fullFrameRealityV3 =\n        !mixedSceneDetected &&\n        displayLikeCellCount == 0 &&\n        realityLikeCellCount >= 6;\n    final coherentDisplayPeriodicity = fullFrameDisplayV3;\n\n    return {\n      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3',\n      'analysisStatus': 'ANALYZED',\n      'decisionRole': 'DECISIONAL_DISPLAY_REALITY_V3_FULL_FRAME_OR_MIXED_SCENE',\n      'productionDecisionChanged':\n          fullFrameDisplayV3 || mixedSceneDetected || fullFrameRealityV3,\n      'coherentDisplayPeriodicity': coherentDisplayPeriodicity,\n      'coherentDisplayPeriodicityEvidence': {\n        'dominantTemporalFrequencyHz': dominantTemporalFrequencyHz,\n        'globalModulationDepth': globalModulationDepth,\n        'globalSpectralConcentration': globalSpectralConcentration,\n        'medianCellPeriodicityStrength': medianCellPeriodicity,\n        'medianCellFrequencyStability': medianCellStability,\n        'medianCellPhaseStepConsistency': medianCellPhase,\n        'medianRowTimeCoherence': medianRowTimeCoherence,\n        'periodicCellCount': periodicCellCount,\n        'stableCellCount': stableCellCount,\n        'displayLikeCellCount': displayLikeCellCount,\n        'realityLikeCellCount': realityLikeCellCount,\n        'indeterminateCellCount': indeterminateCellCount,\n        'requiredDisplayLikeCells': 9,\n        'requiredSpatialFamilyCells': 9,\n        'requiredRowTimeFamilyCells': 9,\n        'legacyV2HfrCandidate': legacyHfrCandidate,\n      },\n      'displayRealityEvidenceV3': {\n        'fullFrameDisplay': fullFrameDisplayV3,\n        'fullFrameReality': fullFrameRealityV3,\n        'mixedSceneDetected': mixedSceneDetected,\n        'allNineCellsSameDisplayFamily': allNineCellsSameDisplayFamily,\n        'displayLikeCellCount': displayLikeCellCount,\n        'realityLikeCellCount': realityLikeCellCount,\n        'indeterminateCellCount': indeterminateCellCount,\n        'spatialFamilyCellCount': spatialFamilyCellCount,\n        'rowTimeFamilyCellCount': rowTimeFamilyCellCount,\n        'medianRowTimeCoherence': medianRowTimeCoherence,\n        'classificationPolicy':\n            'ALL_9_CELLS_ONE_DISPLAY_FAMILY_ELSE_PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE',\n      },\n"""
probe = replace_once(probe, old_gate, new_gate, 'V3 gate')

probe = replace_once(
    probe,
    """      'spatialPolicy': const {\n        'gridRows': 3,\n        'gridColumns': 3,\n        'decisionEnabled': true,\n        'decisionGate': 'STRICT_HFR_COHERENT_DISPLAY_PERIODICITY',\n      },\n      'nativeCaptureMetadata': _withoutRawFrames(raw),\n      'note': 'V2 measures row-profile phase evolution directly from native consecutive CMSampleBuffers. It participates in display fusion only when the strict coherent HFR periodicity gate is satisfied across the frame.',\n""",
    """      'spatialPolicy': const {\n        'gridRows': 3,\n        'gridColumns': 3,\n        'decisionEnabled': true,\n        'requiredSameDisplayFamilyCells': 9,\n        'partialDisplayCoverageMeansMixedReality': true,\n        'decisionGate': 'HFR_V3_FULL_FRAME_DISPLAY_VS_MIXED_REAL_SCENE',\n      },\n      'nativeCaptureMetadata': _withoutRawFrames(raw),\n      'note': 'V3 combines native 240/120 fps timing, 3x3 row-profile rolling-shutter band evolution, row-by-time temporal coherence and strict all-nine-cell spatial consistency. Partial display-like coverage is classified as a mixed real scene.',\n""",
    'spatial policy',
)

insert_marker = """  static Map<String, dynamic> unavailable(String reason, {Object? error}) {\n"""
helpers = """  static bool qualifiesFullFrameDisplayV3({\n    required bool legacyHfrCandidate,\n    required int displayLikeCellCount,\n    required int spatialFamilyCellCount,\n    required int rowTimeFamilyCellCount,\n    required double medianRowTimeCoherence,\n  }) {\n    return legacyHfrCandidate &&\n        displayLikeCellCount == 9 &&\n        spatialFamilyCellCount == 9 &&\n        rowTimeFamilyCellCount == 9 &&\n        medianRowTimeCoherence >= 0.20;\n  }\n\n  static bool _isV3DisplayLikeCell(Map<String, dynamic> entry) {\n    final periodicity =\n        (entry['periodicityStrength'] as num?)?.toDouble() ?? 0.0;\n    final stability =\n        (entry['dominantFrequencyStability'] as num?)?.toDouble() ?? 0.0;\n    final phase =\n        (entry['phaseStepConsistency'] as num?)?.toDouble() ?? 0.0;\n    final rowTime =\n        (entry['rowTimeCoherenceScore'] as num?)?.toDouble() ?? 0.0;\n    return periodicity >= 0.10 &&\n        stability >= 0.80 &&\n        phase >= 0.35 &&\n        rowTime >= 0.20;\n  }\n\n  static bool _isV3RealityLikeCell(Map<String, dynamic> entry) {\n    final periodicity =\n        (entry['periodicityStrength'] as num?)?.toDouble() ?? 1.0;\n    final stability =\n        (entry['dominantFrequencyStability'] as num?)?.toDouble() ?? 1.0;\n    final rowTime =\n        (entry['rowTimeCoherenceScore'] as num?)?.toDouble() ?? 1.0;\n    return periodicity < 0.02 && stability < 0.45 && rowTime < 0.15;\n  }\n\n  static int _compatibleModalBinCount(List<int> bins) {\n    final positive = bins.where((bin) => bin > 0).toList(growable: false);\n    if (positive.isEmpty) return 0;\n    var best = 0;\n    for (final candidate in positive) {\n      final count = positive.where((bin) => (bin - candidate).abs() <= 1).length;\n      if (count > best) best = count;\n    }\n    return best;\n  }\n\n"""
if insert_marker not in probe:
    raise SystemExit('missing unavailable marker')
probe = probe.replace(insert_marker, helpers + insert_marker, 1)

probe = probe.replace(
    "'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',",
    "'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3',",
)
probe = probe.replace(
    "'DECISIONAL_ONLY_FOR_STRICT_HFR_COHERENT_DISPLAY_PERIODICITY',",
    "'DECISIONAL_DISPLAY_REALITY_V3_FULL_FRAME_OR_MIXED_SCENE',",
)

probe = replace_once(
    probe,
    """      'medianTemporalDifferenceRms': medianDifferenceRms,\n      'periodicityStrength': periodicityStrength,\n    };\n  }\n\n  static Map<String, dynamic> analyzeScalarSequence(List<double> values) {\n""",
    """      'medianTemporalDifferenceRms': medianDifferenceRms,\n      'periodicityStrength': periodicityStrength,\n      'rollingShutterBandCoherence':\n          medianConcentration * frequencyStability,\n      'rollingShutterPhaseDriftConsistency': phaseStepConsistency,\n    };\n  }\n\n  static Map<String, dynamic> analyzeRowTimeMatrix(\n    List<List<double>> frames,\n  ) {\n    if (frames.length < 6 || frames.any((profile) => profile.length < 16)) {\n      return const {\n        'rowTimeAnalysisStatus': 'NOT_ANALYZED',\n        'rowTimeReason': 'ROW_TIME_MATRIX_TOO_SHORT',\n      };\n    }\n    final bins = frames.map((profile) => profile.length).reduce(min);\n    final spectra = <Map<String, double>>[];\n    for (var row = 0; row < bins; row++) {\n      final sequence = frames.map((frame) => frame[row]).toList(growable: false);\n      final mean = _mean(sequence);\n      final centered = sequence.map((value) => value - mean).toList(growable: false);\n      spectra.add(_dominantTemporalSpectrum(centered));\n    }\n\n    final weightedBins = <int, double>{};\n    for (final spectrum in spectra) {\n      final bin = spectrum['bin']?.round() ?? 0;\n      if (bin <= 0) continue;\n      final weight = spectrum['concentration'] ?? 0.0;\n      weightedBins[bin] = (weightedBins[bin] ?? 0.0) + weight;\n    }\n    var modalBin = 0;\n    var modalWeight = -1.0;\n    for (final entry in weightedBins.entries) {\n      if (entry.value > modalWeight) {\n        modalWeight = entry.value;\n        modalBin = entry.key;\n      }\n    }\n    final matching = spectra.where((spectrum) {\n      final bin = spectrum['bin']?.round() ?? 0;\n      return modalBin > 0 && (bin - modalBin).abs() <= 1;\n    }).length;\n    final stabilityAcrossRows =\n        spectra.isEmpty ? 0.0 : matching / spectra.length;\n    final concentrations =\n        spectra.map((spectrum) => spectrum['concentration'] ?? 0.0).toList()\n          ..sort();\n    final medianConcentration = _median(concentrations) ?? 0.0;\n    final coherence = stabilityAcrossRows * medianConcentration;\n    return {\n      'rowTimeAnalysisStatus': 'ANALYZED',\n      'rowTimeDominantTemporalFrequencyBin': modalBin,\n      'rowTimeFrequencyStabilityAcrossRows': stabilityAcrossRows,\n      'rowTimeMedianTemporalSpectralConcentration': medianConcentration,\n      'rowTimeCoherenceScore': coherence,\n      'rowTimeRowsAnalyzed': spectra.length,\n    };\n  }\n\n  static Map<String, dynamic> analyzeScalarSequence(List<double> values) {\n""",
    'row time math',
)

probe_path.write_text(probe)

fusion_path = Path('lib/hcv_display_risk_fusion.dart')
fusion = fusion_path.read_text()

fusion = replace_once(
    fusion,
    """    if (base.decision == 'STRONG_DISPLAY_RISK') return base;\n\n    final dualEvidence = _resolveDualEvidenceV1(\n      base: base,\n      passiveOptical: passiveOptical,\n      ml: ml,\n      temporalFrequencyProbe: temporalFrequencyProbe,\n      photoTemporalMl: photoTemporalMl,\n    );\n    if (dualEvidence != null) return dualEvidence;\n""",
    """    final dualEvidence = _resolveDualEvidenceV3(\n      base: base,\n      passiveOptical: passiveOptical,\n      ml: ml,\n      temporalFrequencyProbe: temporalFrequencyProbe,\n      photoTemporalMl: photoTemporalMl,\n    );\n    if (dualEvidence != null) return dualEvidence;\n\n    if (base.decision == 'STRONG_DISPLAY_RISK') return base;\n""",
    'fusion entry',
)

start = fusion.find('  static HCVDisplayRiskResult? _resolveDualEvidenceV1({')
end = fusion.find('  static bool _isCompleteStrictPositiveHfr(', start)
if start < 0 or end < 0:
    raise SystemExit('missing dual evidence method block')
new_dual = r'''  static HCVDisplayRiskResult? _resolveDualEvidenceV3({
    required HCVDisplayRiskResult base,
    required Map<String, dynamic>? passiveOptical,
    required Map<String, dynamic>? ml,
    required Map<String, dynamic>? temporalFrequencyProbe,
    Map<String, dynamic>? photoTemporalMl,
  }) {
    final temporalMl = photoTemporalMl ?? ml;
    final temporalFrames = _temporalFrameCount(temporalMl);
    final highFullFrameScreenFrames =
        _temporalHighFullFrameScreenFrameCount(temporalMl);
    final mixedScene = _isV3MixedRealScene(temporalFrequencyProbe);

    // A monitor/TV inside a wider real scene is reality for SIGILLUM. This
    // veto runs before any inherited STRONG ML decision so semantic screen
    // presence can never turn a mixed physical scene into a screen recapture.
    if (mixedScene) {
      final reasons = base.reasons
          .where(
            (reason) =>
                reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
                reason != 'LIVE_PROBE_MISSING',
          )
          .toList()
        ..add('HFR_V3_MIXED_REAL_SCENE')
        ..add('HFR_V3_PARTIAL_DISPLAY_COVERAGE_IS_REALITY')
        ..add('DUAL_EVIDENCE_V3_ACTIVE');
      return HCVDisplayRiskResult(
        risk: 'LOW',
        score: min(base.score, 20),
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: base.evidenceSources
            .where((source) => !source.contains('SCREEN'))
            .toList(),
        strongSources: const <String>[],
        reasons: reasons,
      );
    }

    final physicalDisplay =
        _isCompleteStrictPositiveHfr(temporalFrequencyProbe);
    final persistentVisualDisplay =
        temporalFrames >= 2 && highFullFrameScreenFrames >= 2;

    if (physicalDisplay || persistentVisualDisplay) {
      final evidenceSources = <String>{...base.evidenceSources};
      final strongSources = <String>{...base.strongSources};
      final reasons = base.reasons
          .where(
            (reason) =>
                reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
                reason != 'LIVE_PROBE_MISSING',
          )
          .toList();

      if (physicalDisplay) {
        evidenceSources.add('HFR_V3_FULL_FRAME_DISPLAY_PHYSICS');
        strongSources.add('HFR_V3_FULL_FRAME_DISPLAY_PHYSICS');
        reasons.add('HFR_V3_ALL_NINE_CELLS_ONE_DISPLAY_FAMILY');
      }
      if (persistentVisualDisplay) {
        evidenceSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');
        strongSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');
        reasons.add('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES');
      }
      reasons.add('DUAL_EVIDENCE_V3_ACTIVE');

      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: max(base.score, 95),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources.toList(),
        strongSources: strongSources.toList(),
        reasons: reasons,
      );
    }

    final physicalReality =
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

    return HCVDisplayRiskResult(
      risk: 'LOW',
      score: min(base.score, 20),
      decision: 'NO_DISPLAY_EVIDENCE',
      analysisStatus: 'COMPLETE',
      evidenceSources: base.evidenceSources,
      strongSources: base.strongSources,
      reasons: reasons,
    );
  }

'''
fusion = fusion[:start] + new_dual + fusion[end:]

start = fusion.find('  static bool _isCompleteStrictPositiveHfr(')
end = fusion.find('  static bool _isStrictPhysicalRealityHfr(', start)
if start < 0 or end < 0:
    raise SystemExit('missing positive HFR block')
positive = r'''  static bool _isCompleteStrictPositiveHfr(Map<String, dynamic>? probe) {
    if (probe == null ||
        !_isSupportedHfrType(probe['type']) ||
        probe['analysisStatus'] != 'ANALYZED' ||
        probe['coherentDisplayPeriodicity'] != true ||
        probe['shortExposureVerified'] != true ||
        probe['exposureLockedForEntireNativeCapture'] != true) {
      return false;
    }
    final frames = (probe['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final fps =
        (probe['actualFrameRateFromTimestamps'] as num?)?.toDouble() ?? 0.0;
    if (frames < 60 || fps < 120.0) return false;
    if (probe['type'] == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3') {
      final v3 = _v3Evidence(probe);
      return v3?['fullFrameDisplay'] == true &&
          v3?['mixedSceneDetected'] != true &&
          (v3?['displayLikeCellCount'] as num?)?.toInt() == 9 &&
          (v3?['spatialFamilyCellCount'] as num?)?.toInt() == 9 &&
          (v3?['rowTimeFamilyCellCount'] as num?)?.toInt() == 9;
    }
    return true;
  }

  static bool _isSupportedHfrType(Object? type) =>
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2' ||
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3';

  static Map<String, dynamic>? _v3Evidence(Map<String, dynamic>? probe) {
    final raw = probe?['displayRealityEvidenceV3'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static bool _isV3MixedRealScene(Map<String, dynamic>? probe) {
    if (probe?['type'] != 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3' ||
        probe?['analysisStatus'] != 'ANALYZED') {
      return false;
    }
    return _v3Evidence(probe)?['mixedSceneDetected'] == true;
  }

'''
fusion = fusion[:start] + positive + fusion[end:]

start = fusion.find('  static bool _isStrictPhysicalRealityHfr(')
end = fusion.find('  static int _temporalFrameCount(', start)
if start < 0 or end < 0:
    raise SystemExit('missing physical reality block')
reality = r'''  static bool _isStrictPhysicalRealityHfr(Map<String, dynamic>? probe) {
    if (!_isCompleteStrictNegativeHfr(probe)) return false;
    if (probe?['type'] == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3') {
      final v3 = _v3Evidence(probe);
      if (v3 == null || v3['mixedSceneDetected'] == true) return false;
      return v3['fullFrameReality'] == true &&
          ((v3['displayLikeCellCount'] as num?)?.toInt() ?? 9) == 0;
    }
    final raw = probe?['coherentDisplayPeriodicityEvidence'];
    if (raw is! Map) return false;
    final evidence = Map<String, dynamic>.from(raw);
    final frequency =
        (evidence['dominantTemporalFrequencyHz'] as num?)?.toDouble();
    final periodicity =
        (evidence['medianCellPeriodicityStrength'] as num?)?.toDouble();
    final stability =
        (evidence['medianCellFrequencyStability'] as num?)?.toDouble();
    final periodicCells =
        (evidence['periodicCellCount'] as num?)?.toInt();
    final stableCells = (evidence['stableCellCount'] as num?)?.toInt();
    if (frequency == null ||
        periodicity == null ||
        stability == null ||
        periodicCells == null ||
        stableCells == null) {
      return false;
    }
    return frequency < 10.0 &&
        periodicity < 0.02 &&
        stability < 0.45 &&
        periodicCells == 0 &&
        stableCells == 0;
  }

'''
fusion = fusion[:start] + reality + fusion[end:]

start = fusion.find('  static int _temporalHighScreenFrameCount(')
end = fusion.find('  static bool _isCompleteStrictNegativeHfr(', start)
if start < 0 or end < 0:
    raise SystemExit('missing temporal high screen block')
fullframe = r'''  static int _temporalHighFullFrameScreenFrameCount(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List) return 0;
    var count = 0;
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map) continue;
      final probability =
          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      final rawSignals = rawFrame['signals'];
      if (rawSignals is! Map) continue;
      final signals = Map<String, dynamic>.from(rawSignals);
      final fullFrame =
          (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      final contentArea =
          (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
      if (probability >= 0.90 && fullFrame >= 90 && contentArea >= 85) {
        count++;
      }
    }
    return count;
  }

'''
fusion = fusion[:start] + fullframe + fusion[end:]

fusion = replace_once(
    fusion,
    """    if (probe == null ||\n        probe['type'] != 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2' ||\n        probe['analysisStatus'] != 'ANALYZED' ||\n""",
    """    if (probe == null ||\n        !_isSupportedHfrType(probe['type']) ||\n        probe['analysisStatus'] != 'ANALYZED' ||\n""",
    'negative HFR type',
)

fusion_path.write_text(fusion)

# Existing BUILD103 dual-evidence test: keep it as a compatibility test but make
# high-screen samples explicitly full-frame; screen probability alone is no
# longer sufficient.
dual_path = Path('test/dual_display_reality_evidence_v1_test.dart')
dual = dual_path.read_text()
dual = replace_once(
    dual,
    """Map<String, dynamic> temporal(List<double> probabilities) => <String, dynamic>{\n  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',\n  'analysisStatus': 'ANALYZED',\n  'framesAnalyzed': probabilities.length,\n  'videoFrameAnalyses': <Map<String, dynamic>>[\n    for (var i = 0; i < probabilities.length; i++)\n      <String, dynamic>{\n        'videoFrameIndex': i,\n        'screenProbability': probabilities[i],\n      },\n  ],\n};\n""",
    """Map<String, dynamic> temporal(\n  List<double> probabilities, {\n  int fullFrameRiskScore = 96,\n  int contentAreaRiskScore = 95,\n}) => <String, dynamic>{\n  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',\n  'analysisStatus': 'ANALYZED',\n  'framesAnalyzed': probabilities.length,\n  'videoFrameAnalyses': <Map<String, dynamic>>[\n    for (var i = 0; i < probabilities.length; i++)\n      <String, dynamic>{\n        'videoFrameIndex': i,\n        'screenProbability': probabilities[i],\n        'signals': <String, dynamic>{\n          'fullFrameRiskScore': fullFrameRiskScore,\n          'contentAreaRiskScore': contentAreaRiskScore,\n        },\n      },\n  ],\n};\n""",
    'dual temporal helper',
)
dual_path.write_text(dual)

contract_path = Path('test/native_temporal_frequency_v2_contract_test.dart')
contract = contract_path.read_text()
contract = contract.replace(
    "V2 probe is native, consecutive and decision-limited to strict coherent HFR periodicity",
    "V3 probe is native, consecutive and decision-limited to full-frame display versus mixed reality",
)
contract = contract.replace(
    "contains('SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2')",
    "contains('SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3')",
)
contract = contract.replace(
    "contains('DECISIONAL_ONLY_FOR_STRICT_HFR_COHERENT_DISPLAY_PERIODICITY')",
    "contains('DECISIONAL_DISPLAY_REALITY_V3_FULL_FRAME_OR_MIXED_SCENE')",
)
contract = contract.replace(
    "test('unavailable V2 evidence cannot change production decision'",
    "test('unavailable V3 evidence cannot change production decision'",
)
contract = contract.replace(
    "'DECISIONAL_ONLY_FOR_STRICT_HFR_COHERENT_DISPLAY_PERIODICITY'",
    "'DECISIONAL_DISPLAY_REALITY_V3_FULL_FRAME_OR_MIXED_SCENE'",
)
contract_path.write_text(contract)

v3_test = r'''import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

HCVDisplayRiskResult unresolvedV3() => const HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: 45,
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'PARTIAL',
      evidenceSources: <String>[],
      strongSources: <String>[],
      reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
    );

Map<String, dynamic> opticalCleanV3() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 15,
      'screenReplayRiskScore': 20,
      'signals': <String, dynamic>{
        'displayFlicker': false,
        'pixelGridOrMoireHint': false,
        'uniformPixelGrid': false,
        'localRefreshFlicker': false,
        'horizontalRefreshBands': false,
        'pairedLocalRefresh': false,
        'temporalScreenPulse': false,
        'structuralDisplayTrace': false,
        'strongDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'opticalCorroboratedTrace': false,
      },
    };

Map<String, dynamic> v3Probe({
  required bool fullFrameDisplay,
  required bool fullFrameReality,
  required bool mixed,
  int displayCells = 0,
  int spatialFamilyCells = 0,
  int rowTimeFamilyCells = 0,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': fullFrameDisplay,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrameDisplay,
        'fullFrameReality': fullFrameReality,
        'mixedSceneDetected': mixed,
        'displayLikeCellCount': displayCells,
        'spatialFamilyCellCount': spatialFamilyCells,
        'rowTimeFamilyCellCount': rowTimeFamilyCells,
      },
    };

Map<String, dynamic> temporalV3(
  List<double> probabilities, {
  int fullFrame = 96,
  int content = 95,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (var i = 0; i < probabilities.length; i++)
          <String, dynamic>{
            'videoFrameIndex': i,
            'screenProbability': probabilities[i],
            'signals': <String, dynamic>{
              'fullFrameRiskScore': fullFrame,
              'contentAreaRiskScore': content,
            },
          },
      ],
    };

void main() {
  test('V3 full-frame display requires all nine cells in one family', () {
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(
        legacyHfrCandidate: true,
        displayLikeCellCount: 9,
        spatialFamilyCellCount: 9,
        rowTimeFamilyCellCount: 9,
        medianRowTimeCoherence: 0.50,
      ),
      isTrue,
    );
    expect(
      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(
        legacyHfrCandidate: true,
        displayLikeCellCount: 8,
        spatialFamilyCellCount: 8,
        rowTimeFamilyCellCount: 8,
        medianRowTimeCoherence: 0.50,
      ),
      isFalse,
    );
  });

  test('row-by-time matrix exposes coherent temporal rhythm', () {
    final frames = <List<double>>[];
    for (var t = 0; t < 24; t++) {
      frames.add(List<double>.generate(32, (row) {
        final temporal = sin(2 * pi * 4 * t / 24);
        final rowPhase = 0.15 * sin(2 * pi * row / 8);
        return 0.5 + 0.18 * temporal + rowPhase;
      }));
    }
    final result = HCVTemporalFrequencyMath.analyzeRowTimeMatrix(frames);
    expect(result['rowTimeAnalysisStatus'], 'ANALYZED');
    expect((result['rowTimeCoherenceScore'] as num).toDouble(), greaterThan(0.50));
  });

  test('mixed monitor plus room is reality even with strong screen ML', () {
    final strongBase = const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 98,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['ML_SCREEN'],
      strongSources: <String>['ML_SCREEN'],
      reasons: <String>['ML_SCREEN_STRONG'],
    );
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: strongBase,
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(<double>[0.98, 0.97, 0.96]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: false,
        mixed: true,
        displayCells: 4,
        spatialFamilyCells: 4,
        rowTimeFamilyCells: 4,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('HFR_V3_MIXED_REAL_SCENE'));
  });

  test('full-frame text monitor can use repeated full-frame ML when HFR is quiet', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolvedV3(),
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(<double>[0.97, 0.96, 0.95]),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: true,
        mixed: false,
      ),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.reasons, contains('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES'));
  });

  test('screen presence without full-frame support cannot promote a real room', () {
    final base = unresolvedV3();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: opticalCleanV3(),
      ml: temporalV3(
        <double>[0.98, 0.97, 0.96],
        fullFrame: 62,
        content: 93,
      ),
      temporalFrequencyProbe: v3Probe(
        fullFrameDisplay: false,
        fullFrameReality: false,
        mixed: false,
      ),
    );
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });
}
'''
Path('test/hfr_v3_fullframe_mixed_scene_test.dart').write_text(v3_test)

print('BUILD104 HFR V3 patch applied')
