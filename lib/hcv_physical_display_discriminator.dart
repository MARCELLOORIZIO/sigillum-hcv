import 'hcv_display_risk_fusion.dart';

class HCVPhysicalDisplayDiscriminator {
  const HCVPhysicalDisplayDiscriminator._();

  static const double displayMeanThreshold = 0.36;
  static const double displayMinCellThreshold = 0.235;
  static const double realityMeanThreshold = 0.31;
  static const double realityMinCellThreshold = 0.22;
  static const double minimumDisplayLumaCompensationRatio = 0.60;

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
    final comparisonsRaw = analysis?['comparisons'];
    final comparisons = comparisonsRaw is Map
        ? Map<String, dynamic>.from(comparisonsRaw)
        : const <String, dynamic>{};
    final lumaCompensationRatio =
        (comparisons['shortExposureLumaCompensationRatio1x'] as num?)
            ?.toDouble();
    final isoCompensationClamped =
        comparisons['isoCompensationClamped1x'] == true;

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
    final display =
        displayThresholdsPassed && displayMeasurementQualitySufficient;
    final reality =
        mean <= realityMeanThreshold && minCell <= realityMinCellThreshold;

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
      'displayThresholdsPassed': displayThresholdsPassed,
      'displayMeasurementQualitySufficient':
          displayMeasurementQualitySufficient,
      'displayBlockedByExposureQuality':
          displayThresholdsPassed && !displayMeasurementQualitySufficient,
      'thresholds': thresholds,
      'policy': const {
        'requiredDisplayCoverageCells': 9,
        'allowedRealityEscapeCells': 0,
        'displayRequiresBothThresholds': true,
        'displayRequiresExposureQuality': true,
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

  static HCVDisplayRiskResult apply({
    required HCVDisplayRiskResult base,
    required Map<String, dynamic>? physicalAnalysis,
  }) {
    final physical = evaluate(physicalAnalysis);
    final decision = physical['decision']?.toString() ?? 'INDETERMINATE';

    if (decision == 'DISPLAY_CONFIRMED') {
      final evidenceSources = <String>{
        ...base.evidenceSources,
        'PHYSICAL_SHORT_1X_3X3',
      }.toList()
        ..sort();
      final strongSources = <String>{
        ...base.strongSources,
        'PHYSICAL_SHORT_1X_3X3',
      }.toList()
        ..sort();
      final reasons = <String>{
        ...base.reasons,
        'PHYSICAL_SHORT_1X_9_OF_9_DISPLAY_CONFIRMED',
      }.toList();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: base.score < 90 ? 90 : base.score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources,
        strongSources: strongSources,
        reasons: reasons,
      );
    }

    if (decision == 'REALITY_SUPPORTED' && base.decision == 'NON_CONCLUSIVE') {
      final evidenceSources = <String>{
        ...base.evidenceSources,
        'PHYSICAL_SHORT_1X_3X3',
      }.toList()
        ..sort();
      final reasons = <String>{
        ...base.reasons,
        'PHYSICAL_SHORT_1X_REALITY_RESOLVES_NON_CONCLUSIVE',
      }.toList();
      return HCVDisplayRiskResult(
        risk: 'LOW',
        score: base.score.clamp(0, 20).toInt(),
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources,
        strongSources: base.strongSources,
        reasons: reasons,
      );
    }

    return base;
  }

  static const Map<String, dynamic> thresholds = {
    'displayMeanThreshold': displayMeanThreshold,
    'displayMinCellThreshold': displayMinCellThreshold,
    'realityMeanThreshold': realityMeanThreshold,
    'realityMinCellThreshold': realityMinCellThreshold,
    'minimumDisplayLumaCompensationRatio': minimumDisplayLumaCompensationRatio,
    'source': 'ACTIVE_V1_PLUS_6_PACK_VALIDATION_2026_09_04',
    'status': 'ACTIVE_V2_EXPOSURE_QUALITY_GATED',
  };
}
