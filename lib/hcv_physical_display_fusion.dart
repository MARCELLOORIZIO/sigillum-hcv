import 'dart:math';

import 'hcv_display_risk_fusion.dart';

class HCVPhysicalDisplayFusion {
  const HCVPhysicalDisplayFusion._();

  static const double hfrMinPeriodicity = 0.10;
  static const double hfrMinFrequencyStability = 0.70;
  static const double hfrMinPhaseConsistency = 0.55;
  static const double hfrMinSpectralConcentration = 0.85;

  static bool hasStrongHfrDisplaySignature(Map<String, dynamic>? probe) {
    if (probe == null || probe['analysisStatus'] != 'ANALYZED') return false;
    final periodicity =
        (probe['medianCellPeriodicityStrength'] as num?)?.toDouble() ?? 0.0;
    final stability =
        (probe['medianCellFrequencyStability'] as num?)?.toDouble() ?? 0.0;
    final phase =
        (probe['medianCellPhaseStepConsistency'] as num?)?.toDouble() ?? 0.0;
    final spectrumRaw = probe['globalFrameLumaTemporalSpectrum'];
    final spectrum = spectrumRaw is Map ? spectrumRaw : const {};
    final concentration =
        (spectrum['temporalSpectralConcentration'] as num?)?.toDouble() ?? 0.0;
    return periodicity >= hfrMinPeriodicity &&
        stability >= hfrMinFrequencyStability &&
        phase >= hfrMinPhaseConsistency &&
        concentration >= hfrMinSpectralConcentration;
  }

  static bool hasStrongReflectiveResponse(Map<String, dynamic>? probe) {
    if (probe == null || probe['analysisStatus'] != 'ANALYZED') return false;
    return probe['strongReflectiveResponseCandidate'] == true &&
        ((probe['medianCellRelativeTorchResponse'] as num?)?.toDouble() ??
                0.0) >=
            0.35 &&
        ((probe['reflectiveCellsAt20Percent'] as num?)?.toInt() ?? 0) >= 6 &&
        ((probe['medianCellReversibility'] as num?)?.toDouble() ?? 0.0) >= 0.55;
  }

  static HCVDisplayRiskResult apply({
    required HCVDisplayRiskResult baseline,
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? illuminationResponseProbe,
    required bool hardDisplayCorroboration,
  }) {
    final hfrDisplay = hasStrongHfrDisplaySignature(temporalFrequencyProbe);
    final reflective = hasStrongReflectiveResponse(illuminationResponseProbe);
    final cleanedReasons =
        baseline.reasons.where((r) => r != 'LIVE_PROBE_MISSING').toList();
    if (temporalFrequencyProbe?['analysisStatus'] == 'ANALYZED' &&
        !cleanedReasons.contains('NATIVE_HFR_PHYSICAL_PROBE_AVAILABLE')) {
      cleanedReasons.add('NATIVE_HFR_PHYSICAL_PROBE_AVAILABLE');
    }

    if (hfrDisplay && baseline.decision != 'STRONG_DISPLAY_RISK') {
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: max(90, baseline.score),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: baseline.analysisStatus,
        evidenceSources:
            {...baseline.evidenceSources, 'NATIVE_HFR_PERIODICITY'}.toList(),
        strongSources:
            {...baseline.strongSources, 'NATIVE_HFR_PERIODICITY'}.toList(),
        reasons: {...cleanedReasons, 'PHYSICAL_HFR_DISPLAY_RESCUE_V1'}.toList(),
      );
    }

    if (baseline.decision == 'STRONG_DISPLAY_RISK' &&
        reflective &&
        !hfrDisplay &&
        !hardDisplayCorroboration) {
      return HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: min(69, max(45, baseline.score)),
        decision: 'NON_CONCLUSIVE',
        analysisStatus: baseline.analysisStatus,
        evidenceSources: {
          ...baseline.evidenceSources,
          'ILLUMINATION_REFLECTION_RESPONSE'
        }.toList(),
        strongSources: const [],
        reasons: {
          ...cleanedReasons,
          'REFLECTIVE_ILLUMINATION_RESPONSE_BLOCKS_UNCORROBORATED_DISPLAY_WARNING'
        }.toList(),
      );
    }

    if (cleanedReasons.length != baseline.reasons.length ||
        !baseline.reasons.every(cleanedReasons.contains)) {
      return HCVDisplayRiskResult(
        risk: baseline.risk,
        score: baseline.score,
        decision: baseline.decision,
        analysisStatus: baseline.analysisStatus,
        evidenceSources: baseline.evidenceSources,
        strongSources: baseline.strongSources,
        reasons: cleanedReasons,
      );
    }
    return baseline;
  }
}
