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
/// Scene context never establishes DISPLAY or REALITY by itself. For VIDEO,
/// positive multi-depth geometry may only act as a contradiction guard when
/// independent initial-window ML/optical evidence conflicts with HFR/ML display
/// evidence. Such conflicts become NON_CONCLUSIVE, never automatic REALITY.
class HCVMultiEvidenceDisplayPolicy {
  const HCVMultiEvidenceDisplayPolicy._();

  static HCVDisplayRiskResult resolvePhoto({
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? stillMl,
    required Map<String, dynamic>? temporalMl,
    Map<String, dynamic>? stillOptical,
    Map<String, dynamic>? temporalOptical,
    Map<String, dynamic>? videoEquivalentDisplayRisk,
  }) {
    final hfr = _hfrEvidence(temporalFrequencyProbe);
    final hfrDecisionEligible = _hfrDecisionEligible(temporalFrequencyProbe);
    final hfrNonDecisionable = _hfrNonDecisionable(temporalFrequencyProbe);
    final still = _mlEvidence(stillMl);
    final temporalAggregate = _mlEvidence(temporalMl);
    final temporal = _videoMlEvidence(temporalMl);

    if (hfr.fullFrameDisplay) {
      return _display(
        98,
        'BUILD124_HFR_FULL_FRAME_DISPLAY',
        const <String>['BUILD124_HFR_FULL_FRAME_DISPLAY'],
      );
    }

    if (hfr.partialCorroboratedDisplay) {
      if (_photoHfrPartialRealityConflict(
        still: still,
        temporal: temporalAggregate,
        stillOptical: stillOptical,
        temporalOptical: temporalOptical,
        videoEquivalentDisplayRisk: videoEquivalentDisplayRisk,
      )) {
        return _nonConclusive(
          'PHOTO_HFR_PARTIAL_CONFLICT_WITH_DUAL_REALITY_EVIDENCE',
        );
      }
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
        still.probability >= 0.80 &&
        _physicalRepeatingTextureGuard(
          stillOptical: stillOptical,
          temporalOptical: temporalOptical,
        )) {
      return _nonConclusive(
        'BUILD127_PHOTO_PHYSICAL_REPEATING_TEXTURE_GUARD',
      );
    }

    // PHOTO only: the temporal video ML result alone is not an independent
    // display proof (PHOTO paper and upholstery archive counterexamples).
    // Promote only when the temporal OPTICAL analyzer independently reports a
    // strong display trace, no comparable HFR reality-like cells are present,
    // and neither residual V3 nor physical texture evidence vetoes the scene.
    final temporalDisplay = videoEquivalentDisplayRisk?['decision'] ==
            'STRONG_DISPLAY_RISK' &&
        videoEquivalentDisplayRisk?['risk'] == 'HIGH';
    final temporalOpticalSignals = _map(temporalOptical?['signals']);
    final independentOpticalTrace =
        temporalOptical?['analysisStatus'] == 'ANALYZED' &&
            temporalOpticalSignals['strongDisplayTrace'] == true;
    if (still.isScreen &&
        still.probability >= 0.80 &&
        !still.v3RealityVeto &&
        temporalDisplay &&
        independentOpticalTrace &&
        (!hfrDecisionEligible || hfr.realityLikeCells == 0)) {
      return _display(
        90,
        'PHOTO_TEMPORAL_INDEPENDENT_OPTICAL_DISPLAY_CONFIRMATION',
        const <String>[
          'PHOTO_STILL_SCREEN_V2_AT_LEAST_0_80',
          'PHOTO_TEMPORAL_HIGH',
          'PHOTO_TEMPORAL_OPTICAL_STRONG_DISPLAY_TRACE',
          'PHOTO_NO_COMPARABLE_HFR_REALITY_CONFLICT',
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
      reason: still.v3RealityVeto
          ? 'BUILD127_V3_RESIDUAL_VETO_NO_CORROBORATED_DISPLAY_EVIDENCE'
          : 'BUILD124_PHOTO_NO_CORROBORATED_DISPLAY_EVIDENCE',
    );
  }

  static HCVDisplayRiskResult resolveVideo({
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? ml,
    Map<String, dynamic>? passiveOptical,
    Map<String, dynamic>? passiveSceneContext,
  }) {
    final hfr = _hfrEvidence(temporalFrequencyProbe);
    final hfrDecisionEligible = _hfrDecisionEligible(temporalFrequencyProbe);
    final hfrNonDecisionable = _hfrNonDecisionable(temporalFrequencyProbe);
    final initialOptical = _initialVideoOptical(passiveOptical);
    final video = _videoMlEvidence(
      ml,
      maxDecisionSecond: 6.0,
    );
    final aggregate = _videoInitialMlAggregate(
      ml,
      maxDecisionSecond: 6.0,
    );

    if (hfr.fullFrameDisplay) {
      return _display(
        98,
        'BUILD124_HFR_FULL_FRAME_DISPLAY',
        const <String>['BUILD124_HFR_FULL_FRAME_DISPLAY'],
      );
    }

    if (hfr.partialCorroboratedDisplay) {
      if (_videoHfrPartialRealityConflict(
        aggregate: aggregate,
        video: video,
        passiveOptical: initialOptical,
        passiveSceneContext: passiveSceneContext,
      )) {
        return _nonConclusive(
          'VIDEO_INITIAL_SCENE_HFR_CONFLICT_WITH_MULTI_DEPTH_REALITY',
          sceneContextConflictGuardUsed: true,
        );
      }
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
        _hasPhysicalRepeatingTexture(initialOptical) &&
        _hasNoStrongOpticalDisplayTrace(initialOptical)) {
      return _nonConclusive(
        'BUILD127_VIDEO_PHYSICAL_REPEATING_TEXTURE_GUARD',
      );
    }

    // Archive 90: at extreme zoom a fabric surface can lose the visible
    // lattice entirely. Do not invent physical-texture evidence when it is
    // absent; keep the semantic-only verdict NON_CONCLUSIVE when the optical
    // video is both flat and low-information, without a true display trace.
    // Confirmed HFR paths above remain authoritative.
    if (aggregate.isScreen &&
        aggregate.probability >= 0.80 &&
        video.framesAtLeast80 >= 2 &&
        _isLowInformationSemanticOnlyVideo(initialOptical)) {
      return _nonConclusive(
        'BUILD127_VIDEO_LOW_INFORMATION_SEMANTIC_ONLY',
      );
    }

    if (aggregate.isScreen &&
        aggregate.probability >= 0.80 &&
        video.framesAtLeast80 >= 2 &&
        video.framesAtLeast90 >= 1 &&
        _videoMlPhysicalRealityConflict(
          hfrDecisionEligible: hfrDecisionEligible,
          hfr: hfr,
          passiveOptical: initialOptical,
          passiveSceneContext: passiveSceneContext,
        )) {
      return _nonConclusive(
        'VIDEO_STRONG_ML_CONFLICT_WITH_POSITIVE_MULTI_DEPTH_REALITY',
        sceneContextConflictGuardUsed: true,
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
      stillOptical: initialOptical,
      reason: 'VIDEO_INITIAL_SCENE_NO_CORROBORATED_DISPLAY_EVIDENCE',
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
      isReality: predictedClass.startsWith('REALITY_'),
      probability: (ml['screenProbability'] as num?)?.toDouble() ?? 0.0,
      fullFrameRisk: (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0,
      contentAreaRisk: (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0,
      v3RealityVeto: signals['v3RealityVeto'] == true ||
          ml['v3RealityVeto'] == true,
    );
  }

  static List<Map<String, dynamic>> _videoDecisionFrames(
    Map<String, dynamic>? ml, {
    double? maxDecisionSecond,
  }) {
    if (ml == null || ml['analysisStatus'] != 'ANALYZED') {
      return const <Map<String, dynamic>>[];
    }
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List) return const <Map<String, dynamic>>[];

    final frames = <Map<String, dynamic>>[];
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map) continue;
      final frame = Map<String, dynamic>.from(rawFrame);
      final second = (frame['approxVideoSecond'] as num?)?.toDouble();
      // Legacy fixtures/certificates may not carry per-frame timestamps.
      // Preserve their historical behaviour instead of silently discarding
      // their ML evidence. Modern VIDEO analyses always carry the timestamp.
      if (maxDecisionSecond != null &&
          second != null &&
          second > maxDecisionSecond + 0.001) {
        continue;
      }
      frames.add(frame);
    }
    frames.sort((a, b) {
      final aSecond = (a['approxVideoSecond'] as num?)?.toDouble() ?? 0.0;
      final bSecond = (b['approxVideoSecond'] as num?)?.toDouble() ?? 0.0;
      return aSecond.compareTo(bSecond);
    });
    return frames;
  }

  static _MlEvidence _videoInitialMlAggregate(
    Map<String, dynamic>? ml, {
    required double maxDecisionSecond,
  }) {
    if (ml == null || ml['analysisStatus'] != 'ANALYZED') {
      return const _MlEvidence();
    }

    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List || rawFrames.isEmpty) {
      return _mlEvidence(ml);
    }

    // Historical certificates/tests did not always persist the timestamp and
    // complete semantic output on each sampled frame. Those records must keep
    // the exact pre-initial-window behaviour: top-level aggregate ML plus the
    // legacy frame counters. Only modern timestamped frame evidence is scoped
    // to the first six seconds.
    final modernTimedFrames = rawFrames.whereType<Map>().every((raw) {
      final frame = Map<String, dynamic>.from(raw);
      return frame['approxVideoSecond'] is num &&
          frame['screenProbability'] is num &&
          (frame['predictedClass']?.toString().isNotEmpty ?? false);
    });
    if (!modernTimedFrames) {
      return _mlEvidence(ml);
    }

    final frames = _videoDecisionFrames(
      ml,
      maxDecisionSecond: maxDecisionSecond,
    );
    if (frames.isEmpty) return _mlEvidence(ml);

    Map<String, dynamic>? worst;
    var worstProbability = -1.0;
    for (final frame in frames) {
      final probability =
          (frame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      if (probability > worstProbability) {
        worst = frame;
        worstProbability = probability;
      }
    }
    return _mlEvidence(worst);
  }

  static _VideoEvidence _videoMlEvidence(
    Map<String, dynamic>? ml, {
    double? maxDecisionSecond,
  }) {
    final frames = _videoDecisionFrames(
      ml,
      maxDecisionSecond: maxDecisionSecond,
    );
    if (frames.isEmpty) return const _VideoEvidence();

    var ge60 = 0;
    var ge80 = 0;
    var ge90 = 0;
    var screenClassFrames = 0;
    var maxRisk = 0;
    for (final frame in frames) {
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
      initialFrameCount: frames.length,
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

  static HCVDisplayRiskResult _nonConclusive(
    String reason, {
    bool sceneContextConflictGuardUsed = false,
  }) =>
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
          sceneContextConflictGuardUsed
              ? 'SCENE_CONTEXT_USED_ONLY_AS_CONTRADICTION_GUARD'
              : 'SCENE_CONTEXT_NOT_USED_FOR_DISPLAY_VERDICT',
        ],
      );

  static bool _photoHfrPartialRealityConflict({
    required _MlEvidence still,
    required _MlEvidence temporal,
    Map<String, dynamic>? stillOptical,
    Map<String, dynamic>? temporalOptical,
    Map<String, dynamic>? videoEquivalentDisplayRisk,
  }) {
    return still.available &&
        still.isReality &&
        still.probability <= 0.05 &&
        temporal.available &&
        temporal.isReality &&
        temporal.probability <= 0.05 &&
        videoEquivalentDisplayRisk?['decision'] == 'NO_DISPLAY_EVIDENCE' &&
        _hasNoStrongOpticalDisplayTrace(stillOptical) &&
        _hasNoStrongOpticalDisplayTrace(temporalOptical);
  }

  static bool _physicalRepeatingTextureGuard({
    Map<String, dynamic>? stillOptical,
    Map<String, dynamic>? temporalOptical,
  }) {
    final physicalTexture = _hasPhysicalRepeatingTexture(stillOptical) ||
        _hasPhysicalRepeatingTexture(temporalOptical);
    if (!physicalTexture) return false;

    return _hasNoStrongOpticalDisplayTrace(stillOptical) &&
        _hasNoStrongOpticalDisplayTrace(temporalOptical);
  }

  static Map<String, dynamic>? _initialVideoOptical(
    Map<String, dynamic>? raw, {
    double maxDecisionSecond = 6.0,
  }) {
    if (raw == null || raw['analysisStatus'] != 'ANALYZED') return raw;
    final rawSegments = raw['segments'];
    if (rawSegments is! List) return raw;

    final initial = <Map<String, dynamic>>[];
    for (final entry in rawSegments) {
      if (entry is! Map) continue;
      final segment = Map<String, dynamic>.from(entry);
      final start = (segment['startSecond'] as num?)?.toDouble();
      if (start == null || start > maxDecisionSecond + 0.001) continue;
      initial.add(segment);
    }
    if (initial.isEmpty) return raw;

    initial.sort((a, b) {
      final aScore = (a['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      final bScore = (b['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      return bScore.compareTo(aScore);
    });
    final worst = initial.first;
    return <String, dynamic>{
      ...raw,
      ...worst,
      'analysisStatus': 'ANALYZED',
      'scanMode': raw['scanMode'] ?? 'EVERY_15_SECONDS_FAST_SAMPLE',
      'segments': initial,
      'segmentsAnalyzed': initial.length,
      'worstSegmentSecond': worst['startSecond'],
      'signals': _map(worst['signals']),
      'decisionWindowSeconds': maxDecisionSecond,
      'laterSegmentsDiagnosticOnly': true,
    };
  }

  static bool _videoHfrPartialRealityConflict({
    required _MlEvidence aggregate,
    required _VideoEvidence video,
    Map<String, dynamic>? passiveOptical,
    Map<String, dynamic>? passiveSceneContext,
  }) {
    if (!aggregate.available ||
        !aggregate.isReality ||
        aggregate.probability > 0.45 ||
        video.initialFrameCount < 2 ||
        video.screenClassFrames != 0 ||
        video.maxFullFrameRisk > 45) {
      return false;
    }

    if (passiveOptical == null ||
        passiveOptical['analysisStatus'] != 'ANALYZED' ||
        !_hasNoStrongOpticalDisplayTrace(passiveOptical)) {
      return false;
    }
    final opticalScore =
        (passiveOptical['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    if (opticalScore > 30) return false;

    if (passiveSceneContext == null ||
        passiveSceneContext['analysisStatus'] != 'ANALYZED') {
      return false;
    }
    final geometry = _map(passiveSceneContext['geometryChallenge']);
    if (geometry['sceneClass'] != 'REALITY' ||
        geometry['realityEvidence'] != true ||
        geometry['planarEvidence'] == true) {
      return false;
    }
    final rawReasons = geometry['reasons'];
    final reasons = rawReasons is List
        ? rawReasons.map((value) => value.toString()).toSet()
        : const <String>{};
    return reasons.contains('MULTI_DEPTH_PARALLAX_DETECTED') &&
        reasons.contains('NON_PLANAR_CAMERA_MOTION_RESPONSE');
  }

  static bool _videoMlPhysicalRealityConflict({
    required bool hfrDecisionEligible,
    required _HfrEvidence hfr,
    Map<String, dynamic>? passiveOptical,
    Map<String, dynamic>? passiveSceneContext,
  }) {
    if (!hfrDecisionEligible ||
        hfr.fullFrameDisplay ||
        hfr.partialCorroboratedDisplay ||
        hfr.displayLikeCells != 0 ||
        hfr.realityLikeCells != 0 ||
        hfr.periodicCells != 0 ||
        hfr.stableCells != 0 ||
        hfr.medianPeriodicity >= 0.05) {
      return false;
    }

    if (passiveOptical == null ||
        passiveOptical['analysisStatus'] != 'ANALYZED' ||
        passiveOptical['scanMode'] != 'EVERY_15_SECONDS_FAST_SAMPLE' ||
        !_hasNoStrongOpticalDisplayTrace(passiveOptical)) {
      return false;
    }
    final opticalSignals = _map(passiveOptical['signals']);
    final opticalScore =
        (passiveOptical['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final rgbPhase =
        (opticalSignals['rgbPhaseConsistencyScore'] as num?)?.toDouble() ?? 1.0;
    if (opticalScore > 30 ||
        opticalSignals['flatSceneUniformity'] != true ||
        opticalSignals['lowMicroVariation'] != true ||
        rgbPhase >= 0.50) {
      return false;
    }

    if (passiveSceneContext == null ||
        passiveSceneContext['analysisStatus'] != 'ANALYZED') {
      return false;
    }
    final geometry = _map(passiveSceneContext['geometryChallenge']);
    if (geometry['sceneClass'] != 'REALITY' ||
        geometry['realityEvidence'] != true ||
        geometry['planarEvidence'] == true) {
      return false;
    }
    final rawReasons = geometry['reasons'];
    final reasons = rawReasons is List
        ? rawReasons.map((value) => value.toString()).toSet()
        : const <String>{};
    return reasons.contains('MULTI_DEPTH_PARALLAX_DETECTED') &&
        reasons.contains('NON_PLANAR_CAMERA_MOTION_RESPONSE');
  }

  static bool _isLowInformationSemanticOnlyVideo(
    Map<String, dynamic>? optical,
  ) {
    if (optical == null ||
        optical['scanMode'] != 'EVERY_15_SECONDS_FAST_SAMPLE' ||
        !_hasNoStrongOpticalDisplayTrace(optical)) {
      return false;
    }
    final signals = _map(optical['signals']);
    final score =
        (optical['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final rgbPhase =
        (signals['rgbPhaseConsistencyScore'] as num?)?.toDouble() ?? 1.0;
    return score <= 30 &&
        signals['flatSceneUniformity'] == true &&
        signals['lowMicroVariation'] == true &&
        rgbPhase < 0.20;
  }

  static bool _hasPhysicalRepeatingTexture(Map<String, dynamic>? raw) {
    if (raw == null) return false;
    final signals = _map(raw['signals']);
    final repetitive =
        (signals['repetitiveTextureScore'] as num?)?.toDouble() ?? 0.0;
    final rgbPhase =
        (signals['rgbPhaseConsistencyScore'] as num?)?.toDouble() ?? 1.0;
    final defect =
        (signals['latticeDefectScore'] as num?)?.toDouble() ?? 0.0;
    final macro =
        (signals['macroPatternScore'] as num?)?.toDouble() ?? 0.0;

    return signals['physicalRepeatingTextureLikely'] == true &&
        repetitive >= 0.55 &&
        rgbPhase < 0.30 &&
        (defect >= 0.30 || macro >= 0.65);
  }

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
    this.isReality = false,
    this.probability = 0.0,
    this.fullFrameRisk = 0,
    this.contentAreaRisk = 0,
    this.v3RealityVeto = false,
  });

  final bool available;
  final bool isScreen;
  final bool isReality;
  final double probability;
  final int fullFrameRisk;
  final int contentAreaRisk;
  final bool v3RealityVeto;
}

class _VideoEvidence {
  const _VideoEvidence({
    this.initialFrameCount = 0,
    this.framesAtLeast60 = 0,
    this.framesAtLeast80 = 0,
    this.framesAtLeast90 = 0,
    this.screenClassFrames = 0,
    this.maxFullFrameRisk = 0,
  });

  final int initialFrameCount;
  final int framesAtLeast60;
  final int framesAtLeast80;
  final int framesAtLeast90;
  final int screenClassFrames;
  final int maxFullFrameRisk;
}
