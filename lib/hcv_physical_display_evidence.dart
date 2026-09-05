import 'dart:math';

import 'hcv_display_risk_fusion.dart';

class HCVPhysicalDisplayEvidence {
  const HCVPhysicalDisplayEvidence._();

  static bool hasStrongHfrDisplaySignature(Map<String, dynamic>? probe) {
    if (!_hfrQualityReady(probe)) return false;
    final cells = probe?['cellResults'];
    if (cells is! List || cells.length != 9) return false;

    var periodicCells = 0;
    var stableCells = 0;
    var phaseCells = 0;
    for (final raw in cells) {
      if (raw is! Map) return false;
      final periodicity =
          (raw['periodicityStrength'] as num?)?.toDouble() ?? 0.0;
      final stability =
          (raw['dominantFrequencyStability'] as num?)?.toDouble() ?? 0.0;
      final phase = (raw['phaseStepConsistency'] as num?)?.toDouble() ?? 0.0;
      if (periodicity >= 0.10) periodicCells++;
      if (stability >= 0.70) stableCells++;
      if (phase >= 0.55) phaseCells++;
    }

    final global = probe?['globalFrameLumaTemporalSpectrum'];
    final globalMap = global is Map ? global : const <String, dynamic>{};
    final modulation =
        (globalMap['robustFrameLumaModulationDepth'] as num?)?.toDouble() ??
            0.0;
    final spectral =
        (globalMap['temporalSpectralConcentration'] as num?)?.toDouble() ?? 0.0;

    return periodicCells >= 7 &&
        stableCells >= 8 &&
        phaseCells >= 7 &&
        modulation >= 0.25 &&
        spectral >= 0.85;
  }

  static bool hasElectronicallyQuietHfr(Map<String, dynamic>? probe) {
    if (!_hfrQualityReady(probe)) return false;
    final periodicity =
        (probe?['medianCellPeriodicityStrength'] as num?)?.toDouble() ?? 1.0;
    final stability =
        (probe?['medianCellFrequencyStability'] as num?)?.toDouble() ?? 1.0;
    final phase =
        (probe?['medianCellPhaseStepConsistency'] as num?)?.toDouble() ?? 1.0;
    final global = probe?['globalFrameLumaTemporalSpectrum'];
    final globalMap = global is Map ? global : const <String, dynamic>{};
    final modulation =
        (globalMap['robustFrameLumaModulationDepth'] as num?)?.toDouble() ??
            1.0;
    final spectral =
        (globalMap['temporalSpectralConcentration'] as num?)?.toDouble() ?? 1.0;

    return periodicity <= 0.02 &&
        stability <= 0.35 &&
        phase <= 0.35 &&
        modulation <= 0.06 &&
        spectral <= 0.55;
  }

  static HCVDisplayRiskResult apply({
    required HCVDisplayRiskResult baseline,
    required Map<String, dynamic>? mlAnalysis,
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? illuminationResponseProbe,
    required bool hardDisplayCorroboration,
  }) {
    var current = _sanitizeLegacyLiveProbeReason(
      baseline,
      temporalFrequencyProbe,
    );

    final strongHfr = hasStrongHfrDisplaySignature(temporalFrequencyProbe);
    if (strongHfr) {
      final evidence = <String>{
        ...current.evidenceSources,
        'NATIVE_HFR_FREQUENCY_SIGNATURE',
      }.toList()
        ..sort();
      final strong = <String>{
        ...current.strongSources,
        'NATIVE_HFR_FREQUENCY_SIGNATURE',
      }.toList()
        ..sort();
      final reasons = <String>{
        ...current.reasons,
        'NATIVE_HFR_STRONG_PERIODIC_DISPLAY_SIGNATURE',
      }.toList();
      if (current.decision != 'STRONG_DISPLAY_RISK') {
        return HCVDisplayRiskResult(
          risk: 'HIGH',
          score: max(92, current.score),
          decision: 'STRONG_DISPLAY_RISK',
          analysisStatus: 'COMPLETE',
          evidenceSources: evidence,
          strongSources: strong,
          reasons: reasons,
        );
      }
      current = HCVDisplayRiskResult(
        risk: current.risk,
        score: current.score,
        decision: current.decision,
        analysisStatus: current.analysisStatus,
        evidenceSources: evidence,
        strongSources: strong,
        reasons: reasons,
      );
    }

    final mlOnlyStrong = current.decision == 'STRONG_DISPLAY_RISK' &&
        current.strongSources.length == 1 &&
        current.strongSources.single == 'ML_SCREEN_CLASS' &&
        !hardDisplayCorroboration;
    if (!mlOnlyStrong || strongHfr) return current;

    final screenProbability =
        (mlAnalysis?['screenProbability'] as num?)?.toDouble();
    final mediumMl = screenProbability != null && screenProbability < 0.90;
    if (!mediumMl) return current;

    final quietHfr = hasElectronicallyQuietHfr(temporalFrequencyProbe);
    final reflective = illuminationResponseProbe?['analysisStatus'] ==
            'ANALYZED' &&
        illuminationResponseProbe?['measurementQualitySufficient'] == true &&
        illuminationResponseProbe?['strongReflectiveResponse'] == true;
    if (!quietHfr && !reflective) return current;

    final evidence = <String>{...current.evidenceSources};
    final reasons = <String>{...current.reasons};
    if (quietHfr) {
      evidence.add('NATIVE_HFR_ELECTRONIC_QUIET');
      reasons.add('ML_ONLY_DISPLAY_CONFLICTS_WITH_ELECTRONICALLY_QUIET_HFR');
    }
    if (reflective) {
      evidence.add('ILLUMINATION_RESPONSE_REFLECTIVE_SURFACE');
      reasons.add('ML_ONLY_DISPLAY_CONFLICTS_WITH_STRONG_REFLECTIVE_RESPONSE');
    }

    return HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: min(69, max(55, current.score - 20)),
      decision: 'NON_CONCLUSIVE',
      analysisStatus: 'COMPLETE',
      evidenceSources: evidence.toList()..sort(),
      strongSources: const [],
      reasons: reasons.toList(),
    );
  }

  static bool _hfrQualityReady(Map<String, dynamic>? probe) {
    if (probe == null || probe['analysisStatus'] != 'ANALYZED') return false;
    final fps =
        (probe['actualFrameRateFromTimestamps'] as num?)?.toDouble() ?? 0.0;
    final exposureVerified = probe['shortExposureVerified'] == true;
    final frames = (probe['framesAnalyzed'] as num?)?.toInt() ?? 0;
    return fps >= 119.0 && exposureVerified && frames >= 24;
  }

  static HCVDisplayRiskResult _sanitizeLegacyLiveProbeReason(
    HCVDisplayRiskResult baseline,
    Map<String, dynamic>? temporalFrequencyProbe,
  ) {
    if (temporalFrequencyProbe?['analysisStatus'] != 'ANALYZED' ||
        !baseline.reasons.contains('LIVE_PROBE_MISSING')) {
      return baseline;
    }
    final reasons = baseline.reasons
        .where((reason) => reason != 'LIVE_PROBE_MISSING')
        .toSet()
      ..add('NATIVE_TEMPORAL_FREQUENCY_PROBE_REPLACES_LEGACY_LIVE_PROBE');
    return HCVDisplayRiskResult(
      risk: baseline.risk,
      score: baseline.score,
      decision: baseline.decision,
      analysisStatus: baseline.analysisStatus,
      evidenceSources: baseline.evidenceSources,
      strongSources: baseline.strongSources,
      reasons: reasons.toList(),
    );
  }
}
