import 'dart:math';

import 'hcv_display_risk_fusion.dart';

/// BUILD124 multi-evidence DISPLAY/REALITY policy.
///
/// Decision inputs:
/// - HFR physical evidence using the real certificate schema;
/// - PHOTO still ML + PHOTO technical mini-video ML;
/// - VIDEO persistent ML frame evidence;
/// - optical evidence may corroborate score/reasons but never decides alone.
///
/// Scene context, geometry and sensors are deliberately excluded from the
/// DISPLAY/REALITY verdict. Borderline screen-like cases become NON_CONCLUSIVE
/// rather than being silently converted into REALITY.
class HCVMultiEvidenceDisplayPolicy {
  const HCVMultiEvidenceDisplayPolicy._();

  static HCVDisplayRiskResult resolvePhoto({
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? stillMl,
    required Map<String, dynamic>? temporalMl,
    Map<String, dynamic>? stillOptical,
    Map<String, dynamic>? temporalOptical,
  }) {
    final hfr = _hfrEvidence(temporalFrequencyProbe);
    final hfrDecisionEligible = _hfrDecisionEligible(temporalFrequencyProbe);
    final hfrNonDecisionable = _hfrNonDecisionable(temporalFrequencyProbe);
    final still = _mlEvidence(stillMl);
    final temporal = _videoMlEvidence(temporalMl);

    if (hfr.fullFrameDisplay) {
      return _display(
        98,
        'BUILD124_HFR_FULL_FRAME_DISPLAY',
        const <String>['BUILD124_HFR_FULL_FRAME_DISPLAY'],
      );
    }

    if (hfr.partialCorroboratedDisplay) {
      return _display(
        95,
        'BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY',
        const <String>[
          'HFR_ZERO_REALITY_LIKE_CELLS',
          'HFR_PARTIAL_DISPLAY_CELLS_WITH_PERIODIC_STABLE_FULL_GRID_FAMILY',
        ],
      );
    }

    if (still.isScreen &&
        !still.v3RealityVeto &&
        still.probability >= 0.90 &&
        still.fullFrameRisk >= 90 &&
        still.contentAreaRisk >= 75) {
      return _display(
        max(90, max(still.fullFrameRisk, still.contentAreaRisk)),
        'BUILD124_PHOTO_STILL_STRONG_DISPLAY',
        const <String>[
          'PHOTO_SCREEN_CLASS_PROBABILITY_AT_LEAST_0_90',
          'PHOTO_FULL_FRAME_RISK_AT_LEAST_90',
          'PHOTO_CONTENT_AREA_RISK_AT_LEAST_75',
        ],
      );
    }

    // BUILD124 PHOTO multi-evidence recovery:
    // requires three different observations to agree. This recovers the BMW
    // and Gentlemen PHOTO patterns without re-admitting the historical
    // wallpaper/textile false positives.
    if (still.isScreen &&
        still.probability >= 0.55 &&
        still.contentAreaRisk >= 80 &&
        temporal.screenClassFrames >= 2 &&
        hfr.displayLikeCells >= 2 &&
        hfr.realityLikeCells == 0) {
      final score = max(
        90,
        max(
          still.contentAreaRisk,
          max(still.fullFrameRisk, temporal.maxFullFrameRisk),
        ),
      );
      return _display(
        score.clamp(90, 100).toInt(),
        'BUILD124_PHOTO_MULTI_EVIDENCE_DISPLAY',
        const <String>[
          'PHOTO_STILL_SCREEN_SEMANTICS',
          'PHOTO_TEMPORAL_SCREEN_SEMANTICS',
          'PHOTO_HFR_LOCAL_DISPLAY_CORROBORATION',
          'PHOTO_NO_HFR_REALITY_LIKE_CELLS',
        ],
      );
    }

    if (_borderlinePhoto(still, temporal, hfr) ||
        (hfrNonDecisionable && still.isScreen && still.probability >= 0.50)) {
      return _nonConclusive(
        hfrNonDecisionable
            ? 'BUILD125_PHOTO_HFR_FOV_NOT_DECISIONABLE'
            : 'BUILD124_PHOTO_BORDERLINE_SCREEN_EVIDENCE',
      );
    }

    if (!hfrDecisionEligible &&
        !still.available &&
        (temporalMl == null || temporalMl['analysisStatus'] != 'ANALYZED')) {
      return _nonConclusive(
        'BUILD124_PHOTO_DECISION_EVIDENCE_UNAVAILABLE',
      );
    }

    return _reality(
      stillOptical: stillOptical,
      temporalOptical: temporalOptical,
      reason: 'BUILD124_PHOTO_NO_CORROBORATED_DISPLAY_EVIDENCE',
    );
  }

  static HCVDisplayRiskResult resolveVideo({
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? ml,
    Map<String, dynamic>? passiveOptical,
  }) {
    final hfr = _hfrEvidence(temporalFrequencyProbe);
    final hfrDecisionEligible = _hfrDecisionEligible(temporalFrequencyProbe);
    final hfrNonDecisionable = _hfrNonDecisionable(temporalFrequencyProbe);
    final video = _videoMlEvidence(ml);
    final aggregate = _mlEvidence(ml);

    if (hfr.fullFrameDisplay) {
      return _display(
        98,
        'BUILD124_HFR_FULL_FRAME_DISPLAY',
        const <String>['BUILD124_HFR_FULL_FRAME_DISPLAY'],
      );
    }

    if (hfr.partialCorroboratedDisplay) {
      return _display(
        95,
        'BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY',
        const <String>[
          'HFR_ZERO_REALITY_LIKE_CELLS',
          'HFR_PARTIAL_DISPLAY_CELLS_WITH_PERIODIC_STABLE_FULL_GRID_FAMILY',
        ],
      );
    }

    if (aggregate.isScreen &&
        aggregate.probability >= 0.80 &&
        video.framesAtLeast80 >= 2 &&
        video.framesAtLeast90 >= 1) {
      return _display(
        max(90, video.maxFullFrameRisk).clamp(90, 100).toInt(),
        'BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY',
        const <String>[
          'VIDEO_SCREEN_CLASS_PROBABILITY_AT_LEAST_0_80',
          'VIDEO_AT_LEAST_TWO_FULL_FRAME_SAMPLES_AT_80',
          'VIDEO_AT_LEAST_ONE_FULL_FRAME_SAMPLE_AT_90',
        ],
      );
    }

    // BUILD124 VIDEO multi-evidence recovery:
    // moderate temporal persistence is accepted only when native HFR finds
    // local display-like cells and zero reality-like cells.
    if (aggregate.isScreen &&
        aggregate.probability >= 0.65 &&
        video.framesAtLeast60 >= 2 &&
        hfr.displayLikeCells >= 2 &&
        hfr.realityLikeCells == 0) {
      return _display(
        max(90, video.maxFullFrameRisk).clamp(90, 100).toInt(),
        'BUILD124_VIDEO_MULTI_EVIDENCE_DISPLAY',
        const <String>[
          'VIDEO_MODERATE_PERSISTENT_SCREEN_SEMANTICS',
          'VIDEO_HFR_LOCAL_DISPLAY_CORROBORATION',
          'VIDEO_NO_HFR_REALITY_LIKE_CELLS',
        ],
      );
    }

    if (_borderlineVideo(aggregate, video, hfr) ||
        (hfrNonDecisionable &&
            aggregate.isScreen &&
            aggregate.probability >= 0.50 &&
            video.screenClassFrames >= 2)) {
      return _nonConclusive(
        hfrNonDecisionable
            ? 'BUILD125_VIDEO_HFR_FOV_NOT_DECISIONABLE'
            : 'BUILD124_VIDEO_BORDERLINE_SCREEN_EVIDENCE',
      );
    }

    if (!hfrDecisionEligible && !aggregate.available) {
      return _nonConclusive(
        'BUILD124_VIDEO_DECISION_EVIDENCE_UNAVAILABLE',
      );
    }

    return _reality(
      stillOptical: passiveOptical,
      reason: 'BUILD124_VIDEO_NO_CORROBORATED_DISPLAY_EVIDENCE',
    );
  }

  static bool _hfrDecisionEligible(Map<String, dynamic>? probe) =>
      probe != null &&
      probe['analysisStatus'] == 'ANALYZED' &&
      probe['hfrSpatialComparability'] == 'COMPARABLE';

  static bool _hfrNonDecisionable(Map<String, dynamic>? probe) =>
      probe != null &&
      probe['analysisStatus'] == 'ANALYZED' &&
      probe['hfrSpatialComparability'] != 'COMPARABLE';

  static _HfrEvidence _hfrEvidence(Map<String, dynamic>? probe) {
    if (probe == null || !_hfrDecisionEligible(probe)) {
      // HFR is preserved in the certificate for diagnostics but may
      // corroborate DISPLAY only when its FOV equivalence is demonstrated.
      return const _HfrEvidence();
    }

    final v3 = _map(probe['displayRealityEvidenceV3']);
    final coherent = _map(probe['coherentDisplayPeriodicityEvidence']);

    final displayLike = (v3['displayLikeCellCount'] as num?)?.toInt() ?? 0;
    final realityLike = (v3['realityLikeCellCount'] as num?)?.toInt() ?? 0;
    final periodic = (coherent['periodicCellCount'] as num?)?.toInt() ?? 0;
    final stable = (coherent['stableCellCount'] as num?)?.toInt() ?? 0;
    final spatial = (v3['spatialFamilyCellCount'] as num?)?.toInt() ?? 0;
    final harmonic =
        (v3['harmonicAwareSpatialFamilyCellCount'] as num?)?.toInt() ?? 0;
    final rowTime = (v3['rowTimeFamilyCellCount'] as num?)?.toInt() ?? 0;
    final medianPeriodicity =
        (coherent['medianCellPeriodicityStrength'] as num?)?.toDouble() ?? 0.0;

    final partial = realityLike == 0 &&
        displayLike >= 5 &&
        periodic >= 6 &&
        stable >= 5 &&
        spatial == 9 &&
        harmonic == 9 &&
        rowTime == 9 &&
        medianPeriodicity >= 0.15;

    return _HfrEvidence(
      fullFrameDisplay: v3['fullFrameDisplay'] == true,
      partialCorroboratedDisplay: partial,
      displayLikeCells: displayLike,
      realityLikeCells: realityLike,
      periodicCells: periodic,
      stableCells: stable,
      medianPeriodicity: medianPeriodicity,
    );
  }

  static _MlEvidence _mlEvidence(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] != 'ANALYZED') {
      return const _MlEvidence();
    }
    final signals = _map(ml['signals']);
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    return _MlEvidence(
      available: true,
      isScreen: predictedClass.startsWith('SCREEN_'),
      probability: (ml['screenProbability'] as num?)?.toDouble() ?? 0.0,
      fullFrameRisk: (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0,
      contentAreaRisk: (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0,
      v3RealityVeto: signals['v3RealityVeto'] == true ||
          ml['v3RealityVeto'] == true,
    );
  }

  static _VideoEvidence _videoMlEvidence(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] != 'ANALYZED') {
      return const _VideoEvidence();
    }
    final frames = ml['videoFrameAnalyses'];
    if (frames is! List) return const _VideoEvidence();

    var ge60 = 0;
    var ge80 = 0;
    var ge90 = 0;
    var screenClassFrames = 0;
    var maxRisk = 0;
    for (final rawFrame in frames) {
      if (rawFrame is! Map) continue;
      final frame = Map<String, dynamic>.from(rawFrame);
      final signals = _map(frame['signals']);
      final score = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      if (score >= 60) ge60++;
      if (score >= 80) ge80++;
      if (score >= 90) ge90++;
      if ((frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_')) {
        screenClassFrames++;
      }
      if (score > maxRisk) maxRisk = score;
    }

    return _VideoEvidence(
      framesAtLeast60: ge60,
      framesAtLeast80: ge80,
      framesAtLeast90: ge90,
      screenClassFrames: screenClassFrames,
      maxFullFrameRisk: maxRisk,
    );
  }

  static bool _borderlinePhoto(
    _MlEvidence still,
    _VideoEvidence temporal,
    _HfrEvidence hfr,
  ) {
    return (still.isScreen &&
            still.probability >= 0.50 &&
            temporal.screenClassFrames >= 2 &&
            hfr.displayLikeCells >= 1 &&
            hfr.realityLikeCells == 0) ||
        (hfr.realityLikeCells == 0 &&
            hfr.displayLikeCells >= 5 &&
            hfr.periodicCells >= 5 &&
            hfr.stableCells >= 5 &&
            hfr.medianPeriodicity >= 0.14);
  }

  static bool _borderlineVideo(
    _MlEvidence aggregate,
    _VideoEvidence video,
    _HfrEvidence hfr,
  ) {
    return (aggregate.isScreen &&
            aggregate.probability >= 0.60 &&
            video.framesAtLeast60 >= 2 &&
            hfr.displayLikeCells >= 1 &&
            hfr.realityLikeCells == 0) ||
        (hfr.realityLikeCells == 0 &&
            hfr.displayLikeCells >= 5 &&
            hfr.periodicCells >= 5 &&
            hfr.stableCells >= 5 &&
            hfr.medianPeriodicity >= 0.14);
  }

  static HCVDisplayRiskResult _display(
    int score,
    String reason,
    List<String> details,
  ) {
    return HCVDisplayRiskResult(
      risk: 'HIGH',
      score: score.clamp(90, 100).toInt(),
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['BUILD124_MULTI_EVIDENCE_FUSION'],
      strongSources: <String>['BUILD124_MULTI_EVIDENCE_FUSION'],
      reasons: <String>[reason, ...details],
    );
  }

  static HCVDisplayRiskResult _reality({
    Map<String, dynamic>? stillOptical,
    Map<String, dynamic>? temporalOptical,
    required String reason,
  }) {
    final opticalCorroboration =
        _hasNoStrongOpticalDisplayTrace(stillOptical) &&
            _hasNoStrongOpticalDisplayTrace(temporalOptical);
    return HCVDisplayRiskResult(
      risk: 'LOW',
      score: 20,
      decision: 'NO_DISPLAY_EVIDENCE',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>[
        'BUILD124_MULTI_EVIDENCE_FUSION',
        if (opticalCorroboration) 'OPTICAL_NO_STRONG_DISPLAY_TRACE',
      ],
      strongSources: const <String>[],
      reasons: <String>[
        reason,
        if (opticalCorroboration) 'OPTICAL_USED_AS_NEGATIVE_CORROBORATION_ONLY',
        'SCENE_CONTEXT_NOT_USED_FOR_DISPLAY_VERDICT',
      ],
    );
  }

  static HCVDisplayRiskResult _nonConclusive(String reason) =>
      HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: 45,
        decision: 'NON_CONCLUSIVE',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['BUILD124_MULTI_EVIDENCE_FUSION'],
        strongSources: const <String>[],
        reasons: <String>[
          reason,
          'ABSENCE_OF_DISPLAY_PROOF_IS_NOT_POSITIVE_REALITY_PROOF',
          'SCENE_CONTEXT_NOT_USED_FOR_DISPLAY_VERDICT',
        ],
      );

  static bool _hasNoStrongOpticalDisplayTrace(Map<String, dynamic>? raw) {
    if (raw == null) return true;
    final signals = _map(raw['signals']);
    return signals['strongDisplayTrace'] != true &&
        signals['structuralDisplayTrace'] != true &&
        signals['confirmedDisplayTrace'] != true;
  }

  static Map<String, dynamic> _map(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
}

class _HfrEvidence {
  const _HfrEvidence({
    this.fullFrameDisplay = false,
    this.partialCorroboratedDisplay = false,
    this.displayLikeCells = 0,
    this.realityLikeCells = 0,
    this.periodicCells = 0,
    this.stableCells = 0,
    this.medianPeriodicity = 0.0,
  });

  final bool fullFrameDisplay;
  final bool partialCorroboratedDisplay;
  final int displayLikeCells;
  final int realityLikeCells;
  final int periodicCells;
  final int stableCells;
  final double medianPeriodicity;
}

class _MlEvidence {
  const _MlEvidence({
    this.available = false,
    this.isScreen = false,
    this.probability = 0.0,
    this.fullFrameRisk = 0,
    this.contentAreaRisk = 0,
    this.v3RealityVeto = false,
  });

  final bool available;
  final bool isScreen;
  final double probability;
  final int fullFrameRisk;
  final int contentAreaRisk;
  final bool v3RealityVeto;
}

class _VideoEvidence {
  const _VideoEvidence({
    this.framesAtLeast60 = 0,
    this.framesAtLeast80 = 0,
    this.framesAtLeast90 = 0,
    this.screenClassFrames = 0,
    this.maxFullFrameRisk = 0,
  });

  final int framesAtLeast60;
  final int framesAtLeast80;
  final int framesAtLeast90;
  final int screenClassFrames;
  final int maxFullFrameRisk;
}
