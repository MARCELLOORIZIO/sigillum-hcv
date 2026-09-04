import 'dart:math';

import 'hcv_display_risk_fusion.dart';

class HCVPhysicalDisplayDiscriminator {
  const HCVPhysicalDisplayDiscriminator._();

  static const double displayMeanThreshold = 0.36;
  static const double displayMinCellThreshold = 0.235;
  static const double realityMeanThreshold = 0.31;
  static const double realityMinCellThreshold = 0.22;
  static const double minimumDisplayLumaCompensationRatio = 0.60;
  static const double activeProbeMotionRejectionThreshold = 0.08;
  static const double directCellMinimumRowColumnRatio = 1.40;
  static const double directCellMinimumLatticeScore = 0.92;
  static const double directCellMaximumHighFrequencyLumaEnergy = 0.03;

  static Map<String, dynamic> _directDisplayCellSupport(Map rawCell) {
    final cell = Map<String, dynamic>.from(rawCell);
    final axis = (cell['structuredTemporalAxisRatio'] as num?)?.toDouble();
    final row = (cell['rowTemporalCoherence'] as num?)?.toDouble();
    final column = (cell['columnTemporalCoherence'] as num?)?.toDouble();
    final lattice = (cell['flatFieldLatticeScore'] as num?)?.toDouble();
    final highFrequencyLuma =
        (cell['highFrequencyLumaEnergy'] as num?)?.toDouble();
    final rowColumnRatio =
        row == null || column == null ? null : row / max(1e-6, column);

    final temporalSupport = axis != null && axis >= displayMinCellThreshold;
    final directionalRefreshSupport = rowColumnRatio != null &&
        rowColumnRatio >= directCellMinimumRowColumnRatio;
    final latticeEmissionSupport = lattice != null &&
        highFrequencyLuma != null &&
        lattice >= directCellMinimumLatticeScore &&
        highFrequencyLuma <= directCellMaximumHighFrequencyLumaEnergy;
    final directSupport = temporalSupport &&
        (directionalRefreshSupport || latticeEmissionSupport);

    return {
      'row': cell['row'],
      'column': cell['column'],
      'directDisplaySupport': directSupport,
      'temporalSupport': temporalSupport,
      'directionalRefreshSupport': directionalRefreshSupport,
      'latticeEmissionSupport': latticeEmissionSupport,
      'structuredTemporalAxisRatio': axis,
      'rowColumnTemporalCoherenceRatio': rowColumnRatio,
      'flatFieldLatticeScore': lattice,
      'highFrequencyLumaEnergy': highFrequencyLuma,
    };
  }

  static Map<String, dynamic> evaluate(Map<String, dynamic>? analysis) {
    final phaseResultsRaw = analysis?['phaseResults'];
    final phaseResults = phaseResultsRaw is Map
        ? Map<String, dynamic>.from(phaseResultsRaw)
        : const <String, dynamic>{};
    final shortRaw = phaseResults['SHORT_1X'];
    final short = shortRaw is Map
        ? Map<String, dynamic>.from(shortRaw)
        : const <String, dynamic>{};

    final mean = (short['structuredTemporalAxisRatio'] as num?)?.toDouble();
    final minCell =
        (short['minimumCellStructuredTemporalAxisRatio'] as num?)?.toDouble();
    final cells = (short['cellsAnalyzed'] as num?)?.toInt() ?? 0;
    final rawCells = short['cells'];
    final directCellResults = rawCells is List
        ? rawCells.whereType<Map>().map(_directDisplayCellSupport).toList()
        : <Map<String, dynamic>>[];
    final directDisplayCellCount = directCellResults
        .where((cell) => cell['directDisplaySupport'] == true)
        .length;
    final directDisplayCoverageConfirmed =
        directCellResults.length == 9 && directDisplayCellCount == 9;

    final comparisonsRaw = analysis?['comparisons'];
    final comparisons = comparisonsRaw is Map
        ? Map<String, dynamic>.from(comparisonsRaw)
        : const <String, dynamic>{};
    final lumaCompensationRatio =
        (comparisons['shortExposureLumaCompensationRatio1x'] as num?)
            ?.toDouble();
    final isoCompensationClamped =
        comparisons['isoCompensationClamped1x'] == true;
    final sceneMotionScore = (short['sceneMotionScore'] as num?)?.toDouble();
    final activeMotionRejected =
        short['motionRejectedForActiveDecision'] == true ||
            (sceneMotionScore != null &&
                sceneMotionScore > activeProbeMotionRejectionThreshold);
    final activeMotionQualitySufficient =
        sceneMotionScore != null && !activeMotionRejected;

    if (mean == null || minCell == null || cells < 9) {
      return {
        'type': 'SIGILLUM_PHYSICAL_DISPLAY_DISCRIMINATOR_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'decision': 'INDETERMINATE',
        'reason': 'SHORT_1X_9_CELL_METRICS_UNAVAILABLE',
        'thresholds': thresholds,
      };
    }

    final displayThresholdsPassed =
        mean >= displayMeanThreshold && minCell >= displayMinCellThreshold;
    final displayMeasurementQualitySufficient = lumaCompensationRatio != null &&
        lumaCompensationRatio >= minimumDisplayLumaCompensationRatio;
    final display = displayThresholdsPassed &&
        displayMeasurementQualitySufficient &&
        activeMotionQualitySufficient &&
        directDisplayCoverageConfirmed;
    final reality = activeMotionQualitySufficient &&
        mean <= realityMeanThreshold &&
        minCell <= realityMinCellThreshold;

    return {
      'type': 'SIGILLUM_PHYSICAL_DISPLAY_DISCRIMINATOR_V1',
      'analysisStatus': 'ANALYZED',
      'decision': display
          ? 'DISPLAY_CONFIRMED'
          : reality
              ? 'REALITY_SUPPORTED'
              : 'INDETERMINATE',
      'short1xMeanStructuredTemporalAxisRatio': mean,
      'short1xMinimumCellStructuredTemporalAxisRatio': minCell,
      'cellsAnalyzed': cells,
      'shortExposureLumaCompensationRatio1x': lumaCompensationRatio,
      'isoCompensationClamped1x': isoCompensationClamped,
      'short1xSceneMotionScore': sceneMotionScore,
      'activeMotionRejected': activeMotionRejected,
      'activeMotionQualitySufficient': activeMotionQualitySufficient,
      'directDisplayCellCount': directDisplayCellCount,
      'directDisplayCoverageConfirmed': directDisplayCoverageConfirmed,
      'directDisplayCellResults': directCellResults,
      'displayThresholdsPassed': displayThresholdsPassed,
      'displayMeasurementQualitySufficient':
          displayMeasurementQualitySufficient,
      'displayBlockedByExposureQuality':
          displayThresholdsPassed && !displayMeasurementQualitySufficient,
      'displayBlockedByMotion': displayThresholdsPassed && activeMotionRejected,
      'displayBlockedByDirectCellCoverage': displayThresholdsPassed &&
          displayMeasurementQualitySufficient &&
          activeMotionQualitySufficient &&
          !directDisplayCoverageConfirmed,
      'thresholds': thresholds,
      'policy': const {
        'requiredDisplayCoverageCells': 9,
        'allowedRealityEscapeCells': 0,
        'displayRequiresBothThresholds': true,
        'displayRequiresExposureQuality': true,
        'displayRequiresActiveMotionQuality': true,
        'displayRequiresDirectCellCoverage9of9': true,
        'realityRequiresBothThresholds': true,
      },
    };
  }

  static Map<String, dynamic>? analysisFromPhotoTemporalProbe(
    Map<String, dynamic>? temporalProbe,
  ) {
    final physicalRaw = temporalProbe?['displayMicrotextureShadowProbe'];
    if (physicalRaw is! Map) return null;
    final analysisRaw = physicalRaw['analysis'];
    if (analysisRaw is! Map) return null;
    return Map<String, dynamic>.from(analysisRaw);
  }

  static HCVDisplayRiskResult _normalizeLegacyLiveProbeReason(
    HCVDisplayRiskResult base,
    Map<String, dynamic> physical,
  ) {
    if (physical['analysisStatus'] != 'ANALYZED') return base;
    final reasons =
        base.reasons.where((r) => r != 'LIVE_PROBE_MISSING').toSet();
    reasons.add('ACTIVE_PHYSICAL_PROBE_REPLACES_LEGACY_LIVE_PROBE');
    final hasOtherMissing =
        reasons.any((reason) => reason.endsWith('_MISSING'));
    return HCVDisplayRiskResult(
      risk: base.risk,
      score: base.score,
      decision: base.decision,
      analysisStatus: base.analysisStatus == 'PARTIAL' && !hasOtherMissing
          ? 'COMPLETE'
          : base.analysisStatus,
      evidenceSources: base.evidenceSources,
      strongSources: base.strongSources,
      reasons: reasons.toList(),
    );
  }

  static bool _mlOnlyStrong(HCVDisplayRiskResult result) =>
      result.strongSources.isNotEmpty &&
      result.strongSources.every((source) => source == 'ML_SCREEN_CLASS');

  static HCVDisplayRiskResult _downgradeToConflict(
    HCVDisplayRiskResult base,
    String reason,
  ) {
    final reasons = <String>{...base.reasons, reason}.toList();
    return HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: base.score.clamp(45, 69).toInt(),
      decision: 'NON_CONCLUSIVE',
      analysisStatus: base.analysisStatus,
      evidenceSources: base.evidenceSources,
      strongSources: base.strongSources,
      reasons: reasons,
    );
  }

  static HCVDisplayRiskResult apply({
    required HCVDisplayRiskResult base,
    required Map<String, dynamic>? physicalAnalysis,
  }) {
    final physical = evaluate(physicalAnalysis);
    final normalizedBase = _normalizeLegacyLiveProbeReason(base, physical);
    final decision = physical['decision']?.toString() ?? 'INDETERMINATE';

    if (decision == 'DISPLAY_CONFIRMED') {
      final evidenceSources = <String>{
        ...normalizedBase.evidenceSources,
        'PHYSICAL_SHORT_1X_3X3',
        'PHYSICAL_DIRECT_DISPLAY_9_OF_9',
      }.toList()
        ..sort();
      final strongSources = <String>{
        ...normalizedBase.strongSources,
        'PHYSICAL_SHORT_1X_3X3',
        'PHYSICAL_DIRECT_DISPLAY_9_OF_9',
      }.toList()
        ..sort();
      final reasons = <String>{
        ...normalizedBase.reasons,
        'PHYSICAL_SHORT_1X_DIRECT_EMISSION_9_OF_9_DISPLAY_CONFIRMED',
      }.toList();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: normalizedBase.score < 90 ? 90 : normalizedBase.score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources,
        strongSources: strongSources,
        reasons: reasons,
      );
    }

    if (decision == 'REALITY_SUPPORTED' &&
        normalizedBase.decision == 'STRONG_DISPLAY_RISK' &&
        _mlOnlyStrong(normalizedBase)) {
      return _downgradeToConflict(
        normalizedBase,
        'PHYSICAL_REALITY_CONFLICTS_WITH_ML_ONLY_DISPLAY',
      );
    }

    if (decision == 'REALITY_SUPPORTED' &&
        normalizedBase.decision == 'NON_CONCLUSIVE') {
      final evidenceSources = <String>{
        ...normalizedBase.evidenceSources,
        'PHYSICAL_SHORT_1X_3X3',
      }.toList()
        ..sort();
      final reasons = <String>{
        ...normalizedBase.reasons,
        'PHYSICAL_SHORT_1X_REALITY_RESOLVES_NON_CONCLUSIVE',
      }.toList();
      return HCVDisplayRiskResult(
        risk: 'LOW',
        score: normalizedBase.score.clamp(0, 20).toInt(),
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources,
        strongSources: normalizedBase.strongSources,
        reasons: reasons,
      );
    }

    final photoVideoEquivalentMlOnly =
        normalizedBase.decision == 'STRONG_DISPLAY_RISK' &&
            normalizedBase.reasons.contains('PHOTO_VIDEO_EQUIVALENT_METHOD') &&
            _mlOnlyStrong(normalizedBase);
    if (photoVideoEquivalentMlOnly) {
      return _downgradeToConflict(
        normalizedBase,
        'PHOTO_VIDEO_EQUIVALENT_REQUIRES_PHYSICAL_DISPLAY_CONFIRMATION',
      );
    }

    return normalizedBase;
  }

  static const Map<String, dynamic> thresholds = {
    'displayMeanThreshold': displayMeanThreshold,
    'displayMinCellThreshold': displayMinCellThreshold,
    'realityMeanThreshold': realityMeanThreshold,
    'realityMinCellThreshold': realityMinCellThreshold,
    'minimumDisplayLumaCompensationRatio': minimumDisplayLumaCompensationRatio,
    'activeProbeMotionRejectionThreshold': activeProbeMotionRejectionThreshold,
    'directCellMinimumRowColumnRatio': directCellMinimumRowColumnRatio,
    'directCellMinimumLatticeScore': directCellMinimumLatticeScore,
    'directCellMaximumHighFrequencyLumaEnergy':
        directCellMaximumHighFrequencyLumaEnergy,
    'source': 'BUILD_84_13_PACK_PLUS_PRIOR_6_PACK_2026_09_04',
    'status': 'ACTIVE_V3_DIRECT_CELL_AND_MOTION_GATED',
  };
}
