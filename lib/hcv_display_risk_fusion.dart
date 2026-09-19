import 'dart:math';

class HCVDisplayRiskResult {
  const HCVDisplayRiskResult({
    required this.risk,
    required this.score,
    required this.decision,
    required this.analysisStatus,
    required this.evidenceSources,
    required this.strongSources,
    required this.reasons,
  });

  final String risk;
  final int score;
  final String decision;
  final String analysisStatus;
  final List<String> evidenceSources;
  final List<String> strongSources;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
        'risk': risk,
        'score': score,
        'decision': decision,
        'analysisStatus': analysisStatus,
        'evidenceSources': evidenceSources,
        'strongSources': strongSources,
        'reasons': reasons,
      };
}

class HCVDisplayRiskFusion {
  /// Resolves only the narrow failure mode where the current fusion is already
  /// NON_CONCLUSIVE, no display evidence source survived, a complete strict
  /// HFR V2 probe was negative, the passive optical analyzer found no physical
  /// display trace, and ML evidence is either weak screen-like semantics or an
  /// extremely strong single-frame REALITY result.
  ///
  /// This is intentionally not a general "negative HFR means reality" rule.
  /// Missing/partial HFR, any hard optical trace, any surviving evidence source,
  /// or medium/strong persistent ML screen evidence leaves the decision intact.
  static HCVDisplayRiskResult resolveWeakSemanticOnlyWithNegativeHfr({
    required HCVDisplayRiskResult base,
    required Map<String, dynamic>? passiveOptical,
    required Map<String, dynamic>? ml,
    required Map<String, dynamic>? temporalFrequencyProbe,
    Map<String, dynamic>? photoTemporalMl,
    Map<String, dynamic>? photoTemporalOptical,
  }) {
    final dualEvidence = _resolveDualEvidenceV3(
      base: base,
      passiveOptical: passiveOptical,
      ml: ml,
      temporalFrequencyProbe: temporalFrequencyProbe,
      photoTemporalMl: photoTemporalMl,
      photoTemporalOptical: photoTemporalOptical,
    );
    if (dualEvidence != null) return dualEvidence;

    // PHOTO has two optical sources: the actual still and the 1.5 s technical
    // clip. Negative/corroboration checks that require a multi-frame optical
    // trace must use the technical clip; the single still remains independent
    // positive evidence elsewhere in the fusion.
    final negativeOptical = photoTemporalOptical ?? passiveOptical;

    if (base.decision == 'STRONG_DISPLAY_RISK') return base;

    if (base.decision != 'NON_CONCLUSIVE' ||
        base.evidenceSources.isNotEmpty ||
        base.strongSources.isNotEmpty ||
        !base.reasons.contains('DISPLAY_CLASSIFICATION_NOT_RESOLVED')) {
      return base;
    }
    if (!_isCompleteStrictNegativeHfr(temporalFrequencyProbe)) {
      return base;
    }

    // BUILD115: V3/V3.2 can leave reflective planar reality and a display
    // visibly embedded in a real scene at NON_CONCLUSIVE when HFR is fully
    // negative but ML remains moderately screen-like. Resolve only the bounded
    // semantic-only envelope measured in the BUILD65/68 physical corpus.
    // Isolated low-score local refresh is not physical display proof; any
    // corroborated optical trace, persistent full-frame ML, positive HFR, or
    // pre-existing STRONG verdict remains an explicit veto. V2 compatibility
    // keeps the historical stricter resolver below unchanged.
    final v3SemanticOnlyResolution =
        _isV3OrLater(temporalFrequencyProbe?['type']) &&
            _hasNoCorroboratedPhysicalDisplayTraceForSemanticResolution(
              negativeOptical,
            ) &&
            _isBoundedV3SemanticOnlyUnresolved(
              ml: ml,
              temporalMl: photoTemporalMl ?? ml,
              isPhoto: photoTemporalMl != null,
            );
    if (v3SemanticOnlyResolution) {
      final reasons = base.reasons
          .where(
            (reason) =>
                reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
                reason != 'LIVE_PROBE_MISSING',
          )
          .toList()
        ..add('STRICT_NEGATIVE_HFR_NO_CORROBORATED_PHYSICAL_DISPLAY_TRACE')
        ..add('V3_BOUNDED_SEMANTIC_ONLY_DISPLAY_APPEARANCE')
        ..add('DISPLAY_APPEARANCE_WITHOUT_FULL_FRAME_PHYSICAL_PROOF');
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

    if (!_hasNoPhysicalDisplayTrace(negativeOptical)) {
      return base;
    }

    final isPhotoTemporalCase = photoTemporalMl != null;
    if (isPhotoTemporalCase) {
      if (!_isWeakPhotoStillSemantic(ml) ||
          !_isWeakMultiFrameScreenSemantic(photoTemporalMl, minFrames: 3)) {
        return base;
      }
    } else {
      final weakMultiFrame = _isWeakMultiFrameScreenSemantic(ml);
      final extremeSingleFrameReality = _isExtremeSingleFrameReality(ml);
      if (!weakMultiFrame && !extremeSingleFrameReality) {
        return base;
      }
    }

    final reasons = base.reasons
        .where(
          (reason) =>
              reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
              reason != 'LIVE_PROBE_MISSING',
        )
        .toList();
    reasons.add('STRICT_NEGATIVE_HFR_NO_PHYSICAL_DISPLAY_TRACE');
    reasons.add(
      isPhotoTemporalCase
          ? 'WEAK_PHOTO_AND_TEMPORAL_SCREEN_SEMANTICS_UNCORROBORATED'
          : _isExtremeSingleFrameReality(ml)
              ? 'EXTREME_SINGLE_FRAME_REALITY_WITH_PHYSICAL_NEGATIVE_CORROBORATION'
              : 'WEAK_MULTI_FRAME_SCREEN_SEMANTICS_UNCORROBORATED',
    );

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

  static HCVDisplayRiskResult? _resolveDualEvidenceV3({
    required HCVDisplayRiskResult base,
    required Map<String, dynamic>? passiveOptical,
    required Map<String, dynamic>? ml,
    required Map<String, dynamic>? temporalFrequencyProbe,
    Map<String, dynamic>? photoTemporalMl,
    Map<String, dynamic>? photoTemporalOptical,
  }) {
    final temporalMl = photoTemporalMl ?? ml;
    final temporalOptical = photoTemporalOptical ?? passiveOptical;
    final temporalFrames = _temporalFrameCount(temporalMl);
    final highAnyScreenFrames = _temporalHighAnyScreenFrameCount(temporalMl);
    final highFullFrameScreenFrames = _temporalHighFullFrameScreenFrameCount(
      temporalMl,
    );
    final recoveredFullFrameScreenFrames =
        _temporalRecoveredFullFrameScreenFrameCountV109(temporalMl);
    final v3Analyzed = _isV3OrLater(temporalFrequencyProbe?['type']) &&
        temporalFrequencyProbe?['analysisStatus'] == 'ANALYZED';
    final positivePhysicalReality = _v3Evidence(
          temporalFrequencyProbe,
        )?['positivePhysicalRealityEvidence'] ==
        true;

    // BUILD117 architecture: HFR mixed/partial coverage is descriptive display
    // physics only. It is not positive scene-context evidence and therefore
    // cannot erase stronger display evidence or force REALITY.

    final physicalDisplay = _isCompleteStrictPositiveHfr(
      temporalFrequencyProbe,
    );

    // BUILD117 PHOTO: the optical analysis of the actual still is independent
    // evidence and must not be replaced by the technical mini-video optical.
    // Reuse the existing ML-first photo gate; no new ML threshold is added.
    final stillOpticalSignals = _signals(passiveOptical);
    final stillOpticalStrong = photoTemporalMl != null &&
        passiveOptical?['screenReplayRisk'] == 'HIGH' &&
        (stillOpticalSignals['strongDisplayTrace'] == true ||
            stillOpticalSignals['structuralDisplayTrace'] == true);
    final stillMlDecision =
        photoTemporalMl == null ? null : mlFirstPhotoDecision(ml);

    // BUILD121: a PHOTO technical clip can be semantically screen-like while
    // the actual still immediately captured afterwards is confidently REALITY.
    // When HFR is not a strict positive and the multi-frame optical trace has
    // no corroborated display physics, that same-family ML disagreement is a
    // genuine conflict, not STRONG display proof. Resolve only to NC, never to
    // REALITY; independent physical evidence can still restore STRONG.
    final photoTemporalStillSemanticConflict = photoTemporalMl != null &&
        base.decision == 'STRONG_DISPLAY_RISK' &&
        stillMlDecision?.decision == 'NO_DISPLAY_EVIDENCE' &&
        !physicalDisplay &&
        !stillOpticalStrong &&
        _hasNoCorroboratedPhysicalDisplayTraceForSemanticResolution(
          temporalOptical,
        );
    if (photoTemporalStillSemanticConflict) {
      return HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: 45,
        decision: 'NON_CONCLUSIVE',
        analysisStatus: 'COMPLETE',
        evidenceSources: base.evidenceSources,
        strongSources: base.strongSources,
        reasons: <String>[
          ...base.reasons,
          'PHOTO_TEMPORAL_STRONG_STILL_REALITY_CONFLICT',
          'NO_INDEPENDENT_PHYSICAL_DISPLAY_CORROBORATION',
        ],
      );
    }

    if (!positivePhysicalReality &&
        !physicalDisplay &&
        stillOpticalStrong &&
        stillMlDecision?.decision == 'STRONG_DISPLAY_RISK') {
      final evidenceSources = <String>{
        ...base.evidenceSources,
        ...stillMlDecision!.evidenceSources,
        'PHOTO_STILL_OPTICAL_CORROBORATION',
      };
      final strongSources = <String>{
        ...base.strongSources,
        ...stillMlDecision.strongSources,
        'PHOTO_STILL_OPTICAL_CORROBORATION',
      };
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: max(
          max(base.score, stillMlDecision.score),
          (passiveOptical?['screenReplayRiskScore'] as num?)?.toInt() ?? 0,
        ),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources.toList(),
        strongSources: strongSources.toList(),
        reasons: <String>[
          ...base.reasons.where(
            (reason) => reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED',
          ),
          ...stillMlDecision.reasons,
          'PHOTO_STILL_OPTICAL_DISPLAY_TRACE_CONFIRMED',
          'PHOTO_STILL_ML_OPTICAL_CORROBORATION',
        ],
      );
    }
    final mlStrongScreenFrames =
        (temporalMl?['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mlAverageScreenRisk =
        (temporalMl?['averageScreenReplayRiskScore'] as num?)?.toDouble() ??
            0.0;
    final narrowThreeFrameFullFrameRecoveryV109 = v3Analyzed &&
        !positivePhysicalReality &&
        !physicalDisplay &&
        temporalFrames == 3 &&
        highAnyScreenFrames == 3 &&
        highFullFrameScreenFrames == 0 &&
        recoveredFullFrameScreenFrames >= 2 &&
        _hasExactlyThreeHighProbabilityScreenSemanticFramesV109(temporalMl) &&
        mlStrongScreenFrames == 3 &&
        mlAverageScreenRisk >= 90.0 &&
        base.decision == 'STRONG_DISPLAY_RISK' &&
        base.reasons.contains(
          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
        ) &&
        base.reasons.contains('ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION');
    final videoPhotoSpatialFullFrameCorroboration = v3Analyzed &&
        !positivePhysicalReality &&
        !physicalDisplay &&
        temporalFrames >= 3 &&
        _hasStableVideoPhotoSpatialFullFrameCorroboration(temporalMl) &&
        base.decision == 'STRONG_DISPLAY_RISK' &&
        base.reasons.contains(
          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
        ) &&
        base.reasons.contains('ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION');

    final stillSignals = _signals(ml);
    final stillPredictedClass = ml?['predictedClass']?.toString() ?? '';
    final stillScreenProbability =
        (ml?['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final stillScreenRisk =
        (ml?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final stillFullFrameRisk =
        (stillSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final stillContentAreaRisk =
        (stillSignals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
    final photoStillTemporalScreenCorroboration = photoTemporalMl != null &&
        v3Analyzed &&
        !positivePhysicalReality &&
        !physicalDisplay &&
        temporalFrames >= 3 &&
        highAnyScreenFrames == temporalFrames &&
        mlStrongScreenFrames >= 3 &&
        mlAverageScreenRisk >= 90.0 &&
        stillPredictedClass.startsWith('SCREEN_') &&
        stillScreenProbability >= 0.92 &&
        stillScreenRisk >= 92 &&
        stillFullFrameRisk >= 92 &&
        stillContentAreaRisk >= 85 &&
        base.decision == 'STRONG_DISPLAY_RISK';

    // BUILD112: recover the physically observed A6 photo false negative without
    // weakening any global ML/HFR threshold. This path is PHOTO-only and needs
    // three independent families to agree: near-full-frame still ML, a stable
    // three-frame SCREEN_* temporal sequence, and a strong passive optical
    // refresh trace from the technical mini-video. Mixed/physical-reality HFR
    // evidence remains an explicit veto.
    final opticalSignals = _signals(temporalOptical);
    final opticalRisk = temporalOptical?['screenReplayRisk']?.toString() ?? '';
    final opticalScore =
        (temporalOptical?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final temporalFrameAnalyses = temporalMl?['videoFrameAnalyses'];
    var temporalScreenClassFrames = 0;
    var temporalRisk80Frames = 0;
    var temporalFullFrame80Frames = 0;
    if (temporalFrameAnalyses is List) {
      for (final rawFrame in temporalFrameAnalyses) {
        if (rawFrame is! Map) continue;
        final frame = Map<String, dynamic>.from(rawFrame);
        final frameSignals = _signals(frame);
        if ((frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_')) {
          temporalScreenClassFrames++;
        }
        if (((frame['screenReplayRiskScore'] as num?)?.toInt() ?? 0) >= 80) {
          temporalRisk80Frames++;
        }
        if (((frameSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0) >=
            80) {
          temporalFullFrame80Frames++;
        }
      }
    }
    final photoModerateScreenOpticalCorroboration = photoTemporalMl != null &&
        v3Analyzed &&
        !positivePhysicalReality &&
        !physicalDisplay &&
        base.decision == 'NON_CONCLUSIVE' &&
        temporalOptical?['captureSource'] == 'PHOTO_TECHNICAL_MINI_VIDEO_V2' &&
        opticalRisk == 'HIGH' &&
        opticalScore >= 80 &&
        opticalSignals['strongDisplayTrace'] == true &&
        opticalSignals['temporalScreenPulse'] == true &&
        opticalSignals['localRefreshFlicker'] == true &&
        stillPredictedClass.startsWith('SCREEN_') &&
        stillScreenProbability >= 0.88 &&
        stillScreenRisk >= 88 &&
        stillFullFrameRisk >= 88 &&
        stillContentAreaRisk >= 90 &&
        temporalFrames >= 3 &&
        mlAverageScreenRisk >= 80.0 &&
        temporalScreenClassFrames == temporalFrames &&
        temporalRisk80Frames == temporalFrames &&
        temporalFullFrame80Frames == temporalFrames;

    if (photoModerateScreenOpticalCorroboration) {
      final evidenceSources = <String>{
        ...base.evidenceSources,
        'PHOTO_MODERATE_SCREEN_OPTICAL_CORROBORATION',
      };
      final strongSources = <String>{
        ...base.strongSources,
        'PHOTO_MODERATE_SCREEN_OPTICAL_CORROBORATION',
      };
      final reasons = base.reasons
          .where(
            (reason) =>
                reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
                reason != 'LIVE_PROBE_MISSING',
          )
          .toList()
        ..add('PHOTO_NEAR_FULL_FRAME_SCREEN_ML_SEQUENCE')
        ..add('PHOTO_OPTICAL_REFRESH_TRACE_CORROBORATES_SCREEN')
        ..add('DUAL_EVIDENCE_V3_ACTIVE');
      final corroboratedScore = max(
        base.score,
        max(opticalScore, max(stillScreenRisk, mlAverageScreenRisk.round())),
      );
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: corroboratedScore,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources.toList(),
        strongSources: strongSources.toList(),
        reasons: reasons,
      );
    }

    // BUILD117: ML fullFrame/contentArea scores describe screen-likeness, not
    // physical screen occupancy. They must not be converted into REALITY.

    final strictPersistentVisualDisplay =
        temporalFrames >= 2 && highFullFrameScreenFrames >= 2;
    final persistentVisualDisplay = strictPersistentVisualDisplay ||
        narrowThreeFrameFullFrameRecoveryV109 ||
        videoPhotoSpatialFullFrameCorroboration ||
        photoStillTemporalScreenCorroboration;

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
        if (strictPersistentVisualDisplay) {
          reasons.add('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES');
        }
        if (narrowThreeFrameFullFrameRecoveryV109) {
          reasons.add('THREE_HIGH_PROBABILITY_SCREEN_SEMANTIC_FRAMES');
          reasons.add('TWO_FULL_FRAME_SCREEN_SAMPLES_WITH_CONTENT_SUPPORT_75');
          reasons.add('ML_THREE_FRAME_FULL_FRAME_SCREEN_RECOVERY_V109');
        }
        if (videoPhotoSpatialFullFrameCorroboration) {
          evidenceSources.add('VIDEO_PHOTO_SPATIAL_CORROBORATION');
          strongSources.add('VIDEO_PHOTO_SPATIAL_CORROBORATION');
          reasons.add('VIDEO_PHOTO_SPATIAL_STABLE_SCREEN_SEQUENCE');
          reasons.add('VIDEO_PHOTO_SPATIAL_FULL_FRAME_CORROBORATION');
        }
        if (photoStillTemporalScreenCorroboration) {
          evidenceSources.add('PHOTO_STILL_TEMPORAL_SCREEN_CORROBORATION');
          strongSources.add('PHOTO_STILL_TEMPORAL_SCREEN_CORROBORATION');
          reasons
              .add('PHOTO_STILL_STRONG_SCREEN_WITH_TEMPORAL_SCREEN_SEQUENCE');
        }
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

    final physicalReality = _isStrictPhysicalRealityHfr(temporalFrequencyProbe);
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

  static bool _isCompleteStrictPositiveHfr(Map<String, dynamic>? probe) {
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
    if (_isV3OrLater(probe['type'])) {
      final v3 = _v3Evidence(probe);
      final strictSpatialFamily =
          (v3?['spatialFamilyCellCount'] as num?)?.toInt() == 9;
      final harmonicSpatialFamily = v3?['harmonicDisplayRecovery'] == true &&
          (v3?['harmonicAwareSpatialFamilyCellCount'] as num?)?.toInt() == 9;
      return v3?['fullFrameDisplay'] == true &&
          v3?['mixedSceneDetected'] != true &&
          v3?['allNineCellsSameDisplayFamily'] == true &&
          (strictSpatialFamily || harmonicSpatialFamily) &&
          (v3?['rowTimeFamilyCellCount'] as num?)?.toInt() == 9;
    }
    return true;
  }

  static bool _isV3OrLater(Object? type) =>
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3' ||
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1' ||
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2';

  static bool _isSupportedHfrType(Object? type) =>
      type == 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2' || _isV3OrLater(type);

  static Map<String, dynamic>? _v3Evidence(Map<String, dynamic>? probe) {
    final raw = probe?['displayRealityEvidenceV3'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static bool _isStrictPhysicalRealityHfr(Map<String, dynamic>? probe) {
    if (!_isCompleteStrictNegativeHfr(probe)) return false;
    if (_isV3OrLater(probe?['type'])) {
      final v3 = _v3Evidence(probe);
      if (v3 == null || v3['mixedSceneDetected'] == true) return false;
      // BUILD107: only a future validated POSITIVE reality sensor may enter
      // this branch. Quiet HFR/no periodicity is explicitly insufficient.
      return v3['positivePhysicalRealityEvidence'] == true &&
          v3['fullFrameReality'] == true;
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
    final periodicCells = (evidence['periodicCellCount'] as num?)?.toInt();
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

  static int _temporalFrameCount(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List) return 0;
    return rawFrames.whereType<Map>().length;
  }

  static int _temporalHighAnyScreenFrameCount(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List) return 0;
    var count = 0;
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map) continue;
      final probability =
          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      if (probability >= 0.90) count++;
    }
    return count;
  }

  static int _temporalHighFullFrameScreenFrameCount(Map<String, dynamic>? ml) {
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
      final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      final contentArea =
          (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
      if (probability >= 0.90 && fullFrame >= 90 && contentArea >= 85) {
        count++;
      }
    }
    return count;
  }

  static bool _hasExactlyThreeHighProbabilityScreenSemanticFramesV109(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (framesAnalyzed != 3 || rawFrames is! List || rawFrames.length != 3) {
      return false;
    }
    return rawFrames.every((rawFrame) {
      if (rawFrame is! Map) return false;
      final predictedClass = rawFrame['predictedClass']?.toString() ?? '';
      final probability =
          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      return predictedClass.startsWith('SCREEN_') && probability >= 0.90;
    });
  }

  static int _temporalRecoveredFullFrameScreenFrameCountV109(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List) return 0;
    var count = 0;
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map) continue;
      final predictedClass = rawFrame['predictedClass']?.toString() ?? '';
      final probability =
          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      final rawSignals = rawFrame['signals'];
      if (rawSignals is! Map) continue;
      final signals = Map<String, dynamic>.from(rawSignals);
      final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      final contentArea =
          (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
      if (predictedClass.startsWith('SCREEN_') &&
          probability >= 0.90 &&
          fullFrame >= 90 &&
          contentArea >= 75) {
        count++;
      }
    }
    return count;
  }

  static bool _hasStableVideoPhotoSpatialFullFrameCorroboration(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final raw = ml['videoPhotoSpatialEvidence'];
    if (raw is! Map) return false;
    final evidence = Map<String, dynamic>.from(raw);
    return evidence['type'] == 'SIGILLUM_VIDEO_PHOTO_SPATIAL_EVIDENCE_V1' &&
        evidence['analysisStatus'] == 'ANALYZED' &&
        evidence['stableScreenSequence'] == true &&
        evidence['stableFullFrameScreenCorroboration'] == true &&
        evidence['sceneTransitionDetected'] != true;
  }

  static bool _isCompleteHfrCapture(Map<String, dynamic>? probe) {
    if (probe == null ||
        !_isSupportedHfrType(probe['type']) ||
        probe['analysisStatus'] != 'ANALYZED' ||
        probe['shortExposureVerified'] != true ||
        probe['exposureLockedForEntireNativeCapture'] != true) {
      return false;
    }
    final frames = (probe['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final targetFrames = (probe['targetFrameCount'] as num?)?.toInt();
    final configuredFps =
        (probe['configuredFrameRate'] as num?)?.toDouble();
    final actualFps =
        (probe['actualFrameRateFromTimestamps'] as num?)?.toDouble() ?? 0.0;
    final requiredFrames = targetFrames != null && targetFrames > 0
        ? targetFrames
        : 60;
    final requiredFps = configuredFps != null && configuredFps > 0
        ? configuredFps * 0.98
        : 117.5;
    return frames >= requiredFrames && actualFps >= requiredFps;
  }

  static bool _isCompleteStrictNegativeHfr(Map<String, dynamic>? probe) {
    if (!_isCompleteHfrCapture(probe) ||
        probe?['coherentDisplayPeriodicity'] != false) {
      return false;
    }
    if (_isV3OrLater(probe?['type'])) {
      final v3 = _v3Evidence(probe);
      if (v3 == null ||
          v3['fullFrameDisplay'] == true ||
          v3['mixedSceneDetected'] == true ||
          ((v3['displayLikeCellCount'] as num?)?.toInt() ?? 0) != 0) {
        return false;
      }
    }
    return true;
  }

  static bool _hasNoPhysicalDisplayTrace(Map<String, dynamic>? optical) {
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

  static bool _hasNoCorroboratedPhysicalDisplayTraceForSemanticResolution(
    Map<String, dynamic>? optical,
  ) {
    if (optical == null || optical['analysisStatus'] == 'NOT_ANALYZED') {
      return false;
    }
    final frames = (optical['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final score = (optical['screenReplayRiskScore'] as num?)?.toInt();
    if (frames < 12 || score == null || score > 20) return false;

    final signals = _signals(optical);
    // An isolated low-score localRefreshFlicker has occurred on real reflective
    // scenes in physical captures. It is therefore not a veto by itself. Every
    // corroborated temporal/spatial display signature remains a hard veto.
    const corroboratedSignalKeys = <String>[
      'displayFlicker',
      'pixelGridOrMoireHint',
      'uniformPixelGrid',
      'horizontalRefreshBands',
      'pairedLocalRefresh',
      'temporalScreenPulse',
      'structuralDisplayTrace',
      'strongDisplayTrace',
      'confirmedDisplayTrace',
      'periodicLightTrace',
      'opticalCorroboratedTrace',
    ];
    return corroboratedSignalKeys.every((key) => signals[key] != true);
  }

  static bool _isBoundedV3SemanticOnlyUnresolved({
    required Map<String, dynamic>? ml,
    required Map<String, dynamic>? temporalMl,
    required bool isPhoto,
  }) {
    if (temporalMl == null || temporalMl['analysisStatus'] == 'NOT_ANALYZED') {
      return false;
    }
    final frames = (temporalMl['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (temporalMl['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (temporalMl['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (temporalMl['averageScreenReplayRiskScore'] as num?)?.toDouble() ??
            100.0;
    final maxFrame =
        (temporalMl['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (temporalMl['screenProbability'] as num?)?.toDouble() ?? 1.0;

    if (frames < (isPhoto ? 3 : 2) ||
        strong > 1 ||
        medium > 1 ||
        average > 85.0 ||
        maxFrame > 96 ||
        screenProbability > 0.96 ||
        _temporalHighFullFrameScreenFrameCount(temporalMl) >= 2 ||
        _hasRawFullFrameVideoRecoveryBuild122(temporalMl) ||
        _hasStableVideoPhotoSpatialFullFrameCorroboration(temporalMl)) {
      return false;
    }

    if (!isPhoto) return true;
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;

    // A still that independently satisfies the strict full-frame spatial ML
    // gate is not semantic-only and must not be downgraded by this resolver.
    return !hasSpatialScreenCorroboration(ml);
  }

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

  static bool _isWeakPhotoStillSemantic(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final signals = _signals(ml);
    final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 100;
    final contentArea =
        (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 100;

    // At this stage HFR and passive optical evidence have already been proven
    // strictly negative. Do not let the semantic class label or its confidence
    // become a second pseudo-physical gate: both shifted materially between
    // BUILD100 and BUILD101 on the same real-world artwork/textile classes.
    // Retain a conservative still ceiling and reject any strong regional score.
    return score <= 70 && fullFrame < 90 && contentArea < 85;
  }

  static bool _isWeakMultiFrameScreenSemantic(
    Map<String, dynamic>? ml, {
    int minFrames = 2,
  }) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    if (frames < minFrames) return false;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrame =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;

    // Confidence is top-class confidence, not independent display evidence.
    // Persistence and bounded screen-family probability are the useful semantic
    // constraints once strict physical evidence is negative.
    return medium == 0 &&
        strong == 0 &&
        average <= 65.0 &&
        maxFrame <= 80 &&
        screenProbability <= 0.80;
  }

  static bool _isExtremeSingleFrameReality(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    return frames == 1 &&
        predictedClass.startsWith('REALITY_') &&
        screenProbability <= 0.02 &&
        score <= 2 &&
        confidence >= 0.30;
  }

  static HCVDisplayRiskResult? mlFirstPhotoDecision(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return null;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final screenProbability = (ml['screenProbability'] as num?)?.toDouble();
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    if (screenProbability == null) return null;
    final mlScore = (ml['screenReplayRiskScore'] as num?)?.toInt() ??
        (screenProbability * 100).round();

    // Current classifiers provide independent full-frame and content-area
    // risk scores. A glossy print, framed artwork or other flat reflective
    // surface can receive a high SCREEN semantic probability while those two
    // regions do not agree strongly enough. When both diagnostics are present,
    // require that corroboration before ML alone can produce a strong verdict.
    // Older signed analyses that predate these fields retain the frozen 0.80
    // compatibility rule and are not reinterpreted retroactively.
    final mlSignals = _signals(ml);
    final hasMlFirstPhotoSpatialDiagnostics =
        mlSignals.containsKey('fullFrameRiskScore') &&
            mlSignals.containsKey('contentAreaRiskScore');
    final fullFrameRisk =
        (mlSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final contentAreaRisk =
        (mlSignals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
    final currentPhotoSpatialCorroboration =
        !hasMlFirstPhotoSpatialDiagnostics ||
            (fullFrameRisk >= 90 &&
                contentAreaRisk >= 85 &&
                (confidence == 0.0 || confidence >= 0.75));

    if (predictedClass.startsWith('SCREEN_') &&
        screenProbability >= 0.80 &&
        currentPhotoSpatialCorroboration) {
      final score = mlScore.clamp(80, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_SCREEN_CLASS'],
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: hasMlFirstPhotoSpatialDiagnostics
            ? const [
                'ML_FIRST_PHOTO_SCREEN_FAMILY_HIGH_PROBABILITY',
                'ML_FIRST_PHOTO_SPATIAL_CORROBORATION',
              ]
            : const ['ML_FIRST_PHOTO_SCREEN_FAMILY_HIGH_PROBABILITY'],
      );
    }

    if (predictedClass.startsWith('REALITY_') && screenProbability <= 0.20) {
      final score = mlScore.clamp(0, 20).toInt();
      return HCVDisplayRiskResult(
        risk: 'LOW',
        score: score,
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_REALITY_CLASS'],
        strongSources: const [],
        reasons: const ['ML_FIRST_PHOTO_REALITY_FAMILY_LOW_SCREEN_PROBABILITY'],
      );
    }

    return null;
  }

  static HCVDisplayRiskResult? mlFirstVideoDecision(Map<String, dynamic>? ml) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return null;

    if (_hasRawFullFrameVideoRecoveryBuild122(ml)) {
      final rawFrames = ml['videoFrameAnalyses'] as List;
      var maxRawScore = 0;
      for (final rawFrame in rawFrames) {
        if (rawFrame is! Map) continue;
        final rawSignals = rawFrame['signals'];
        if (rawSignals is! Map) continue;
        final score =
            (rawSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
        if (score > maxRawScore) maxRawScore = score;
      }
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: max(90, maxRawScore).clamp(90, 100).toInt(),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['ML_RAW_FULL_FRAME_SEQUENCE'],
        strongSources: const <String>['ML_RAW_FULL_FRAME_SEQUENCE'],
        reasons: const <String>[
          'BUILD122_RAW_FULL_FRAME_VIDEO_RECOVERY',
          'RAW_FULL_FRAME_SCREEN_EVIDENCE_PERSISTS_ACROSS_FRAMES',
          'OVERLAY_CROP_CANNOT_ERASE_RAW_SCREEN_EVIDENCE',
        ],
      );
    }
    final screenProbability = (ml['screenProbability'] as num?)?.toDouble();
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (screenProbability == null ||
        framesAnalyzed < 2 ||
        rawFrames is! List ||
        rawFrames.length != framesAnalyzed) {
      return null;
    }

    final screenFrames = rawFrames.where((frame) {
      if (frame is! Map) return false;
      return (frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_');
    }).length;
    final screenMajority = screenFrames * 2 > framesAnalyzed;
    final noScreenMajority = screenFrames * 2 <= framesAnalyzed;
    final mlScore = (ml['screenReplayRiskScore'] as num?)?.toInt() ??
        (screenProbability * 100).round();

    // Preserve the legacy probability+semantic-majority rule for older ML
    // payloads. Current payloads expose aggregate/frame diagnostics as well;
    // when that complete diagnostic set is available, require it to agree with
    // the semantic majority. This separates the observed reflective artwork
    // (high semantic probability but low aggregate/frame support) from the
    // historical and current true-monitor controls.
    final mlSignals = _signals(ml);
    final hasMlFirstVideoDiagnostics =
        ml.containsKey('mediumScreenFrameCount') &&
            ml.containsKey('averageScreenReplayRiskScore') &&
            ml.containsKey('maxFrameScreenReplayRiskScore') &&
            mlSignals.containsKey('fullFrameRiskScore') &&
            mlSignals.containsKey('contentAreaRiskScore');
    final mediumScreenFrames =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final currentVideoDiagnosticCorroboration = !hasMlFirstVideoDiagnostics ||
        (mlScore >= 75 &&
            mediumScreenFrames * 2 >= framesAnalyzed &&
            averageFrameScore >= 80.0 &&
            maxFrameScore >= 90);

    if (screenMajority &&
        screenProbability >= 0.75 &&
        currentVideoDiagnosticCorroboration) {
      final score = mlScore.clamp(75, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_SCREEN_CLASS'],
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: hasMlFirstVideoDiagnostics
            ? const [
                'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
                'ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION',
              ]
            : const ['ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY'],
      );
    }

    if (screenProbability <= 0.70 && noScreenMajority) {
      final score = mlScore.clamp(0, 20).toInt();
      return HCVDisplayRiskResult(
        risk: 'LOW',
        score: score,
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_REALITY_CLASS'],
        strongSources: const [],
        reasons: const ['ML_FIRST_VIDEO_NO_SCREEN_MAJORITY_LOW_PROBABILITY'],
      );
    }

    return null;
  }

  static bool _hasRawFullFrameVideoRecoveryBuild122(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;
    final rawFrames = ml['videoFrameAnalyses'];
    if (rawFrames is! List || rawFrames.length < 2) return false;
    final spatial = ml['videoPhotoSpatialEvidence'];
    if (spatial is Map && spatial['sceneTransitionDetected'] == true) {
      return false;
    }

    var raw80 = 0;
    var raw90 = 0;
    var semanticScreen = 0;
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map) continue;
      final rawSignals = rawFrame['signals'];
      if (rawSignals is! Map) continue;
      final fullScore =
          (rawSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      final rawProbability =
          (rawSignals['rawFullFrameScreenProbability'] as num?)?.toDouble() ??
              0.0;
      final rawClass =
          rawSignals['rawFullFramePredictedClass']?.toString() ?? '';
      final rawConfidence =
          (rawSignals['rawFullFramePredictedClassConfidence'] as num?)
                  ?.toDouble() ??
              0.0;
      if (fullScore >= 80) raw80++;
      if (fullScore >= 90) raw90++;
      if (rawClass.startsWith('SCREEN_') &&
          rawProbability >= 0.84 &&
          rawConfidence >= 0.80) {
        semanticScreen++;
      }
    }
    return raw80 >= 2 && raw90 >= 1 && semanticScreen >= 1;
  }

  static bool hasSpatialScreenCorroboration(Map<String, dynamic>? ml) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    final signals = _signals(ml);
    final fullFrameRisk = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final contentAreaRisk =
        (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;

    return predictedClass.startsWith('SCREEN_') &&
        framesAnalyzed == 1 &&
        fullFrameRisk >= 94 &&
        contentAreaRisk >= 89 &&
        screenProbability >= 0.93 &&
        confidence >= 0.89;
  }

  static bool hasMultiFrameScreenConsistency(Map<String, dynamic>? ml) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final mediumScreenFrameCount =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    final signals = _signals(ml);
    final fullFrameRisk = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final contentAreaRisk =
        (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
    final strongestFrameScore = max(score, maxFrameScore);

    return predictedClass.startsWith('SCREEN_') &&
        framesAnalyzed >= 2 &&
        mediumScreenFrameCount >= 2 &&
        mediumScreenFrameCount * 4 >= framesAnalyzed * 3 &&
        averageFrameScore >= 88.0 &&
        strongestFrameScore >= 94 &&
        screenProbability >= 0.90 &&
        confidence >= 0.75 &&
        fullFrameRisk >= 90 &&
        contentAreaRisk >= 90;
  }

  static bool hasPersistentSemanticScreenAcrossVideoFrames(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strongScreenFrameCount =
        (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mediumScreenFrameCount =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (framesAnalyzed < 4 ||
        rawFrames is! List ||
        rawFrames.length != framesAnalyzed) {
      return false;
    }
    final allFramesScreen = rawFrames.every(
      (frame) =>
          frame is Map &&
          (frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_'),
    );

    return predictedClass.startsWith('SCREEN_') &&
        allFramesScreen &&
        strongScreenFrameCount >= 2 &&
        mediumScreenFrameCount >= 3 &&
        averageFrameScore >= 88.0 &&
        maxFrameScore >= 94 &&
        screenProbability >= 0.93 &&
        confidence >= 0.85;
  }

  static bool hasSemanticScreenPersistenceV2(
    Map<String, dynamic>? ml, {
    required String geometrySceneClass,
    required bool reflectedRealityEvidence,
  }) {
    if (ml == null || reflectedRealityEvidence) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strongScreenFrameCount =
        (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mediumScreenFrameCount =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (framesAnalyzed < 4 ||
        rawFrames is! List ||
        rawFrames.length != framesAnalyzed) {
      return false;
    }

    final screenFrameCount = rawFrames
        .where(
          (frame) =>
              frame is Map &&
              (frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_'),
        )
        .length;
    final atLeastEightyPercentScreen =
        screenFrameCount * 5 >= framesAnalyzed * 4;
    final atLeastHalfMedium = mediumScreenFrameCount * 2 >= framesAnalyzed;

    final commonPersistenceGate = predictedClass.startsWith('SCREEN_') &&
        atLeastEightyPercentScreen &&
        strongScreenFrameCount >= 2 &&
        atLeastHalfMedium &&
        maxFrameScore >= 94 &&
        screenProbability >= 0.93;
    if (!commonPersistenceGate) return false;

    if (geometrySceneClass == 'REALITY') {
      final unanimousScreen =
          screenFrameCount == framesAnalyzed && averageFrameScore >= 85.0;
      final nearUnanimousWithStrongAnchor = atLeastEightyPercentScreen &&
          averageFrameScore >= 70.0 &&
          maxFrameScore >= 96 &&
          screenProbability >= 0.97 &&
          confidence >= 0.95 &&
          strongScreenFrameCount >= 3;
      return unanimousScreen || nearUnanimousWithStrongAnchor;
    }

    return averageFrameScore >= 85.0;
  }

  static bool hasRealisticContentScreenPersistence(
    Map<String, dynamic>? ml, {
    required bool reflectedRealityEvidence,
  }) {
    if (ml == null || reflectedRealityEvidence) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final maxFrame =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (frames < 4 || rawFrames is! List || rawFrames.length != frames) {
      return false;
    }
    final screenFrames = rawFrames
        .where(
          (frame) =>
              frame is Map &&
              (frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_'),
        )
        .length;
    return predictedClass.startsWith('SCREEN_') &&
        screenFrames * 4 >= frames * 3 &&
        strong >= 2 &&
        medium >= 2 &&
        average >= 60.0 &&
        maxFrame >= 96 &&
        screenProbability >= 0.97;
  }

  static bool hasPlanarSemanticRealityWithoutHardDisplayEvidence(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrame =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (frames < 4 || rawFrames is! List || rawFrames.length != frames) {
      return false;
    }
    final realityFrames = rawFrames
        .where(
          (frame) =>
              frame is Map &&
              (frame['predictedClass']?.toString() ?? '').startsWith(
                'REALITY_',
              ),
        )
        .length;
    return predictedClass.startsWith('SCREEN_') &&
        realityFrames * 2 >= frames &&
        strong == 0 &&
        medium == 0 &&
        average <= 35.0 &&
        maxFrame <= 75 &&
        screenProbability <= 0.75;
  }

  static bool hasPersistentSemanticRealityAcrossVideoFrames(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strongScreenFrameCount =
        (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mediumScreenFrameCount =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (framesAnalyzed < 4 ||
        rawFrames is! List ||
        rawFrames.length != framesAnalyzed) {
      return false;
    }
    final allFramesReality = rawFrames.every(
      (frame) =>
          frame is Map &&
          (frame['predictedClass']?.toString() ?? '').startsWith('REALITY_'),
    );

    return predictedClass.startsWith('REALITY_') &&
        allFramesReality &&
        strongScreenFrameCount == 0 &&
        mediumScreenFrameCount == 0 &&
        averageFrameScore <= 20.0 &&
        maxFrameScore <= 30 &&
        screenProbability <= 0.30;
  }

  static bool hasShortGeometricSemanticRealityAcrossVideoFrames(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strongScreenFrameCount =
        (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mediumScreenFrameCount =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (framesAnalyzed < 2 ||
        framesAnalyzed > 3 ||
        rawFrames is! List ||
        rawFrames.length != framesAnalyzed) {
      return false;
    }
    final allFramesReality = rawFrames.every(
      (frame) =>
          frame is Map &&
          (frame['predictedClass']?.toString() ?? '').startsWith('REALITY_'),
    );

    return predictedClass.startsWith('REALITY_') &&
        allFramesReality &&
        strongScreenFrameCount == 0 &&
        mediumScreenFrameCount == 0 &&
        averageFrameScore <= 20.0 &&
        maxFrameScore <= 30 &&
        screenProbability <= 0.30;
  }

  static bool _isCredibleRealityMl(
    Map<String, dynamic>? ml, {
    required int maxScore,
    required double maxScreenProbability,
    required double minConfidence,
  }) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final confidence =
        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    return predictedClass.startsWith('REALITY_') &&
        score <= maxScore &&
        screenProbability <= maxScreenProbability &&
        confidence >= minConfidence;
  }

  static bool _hasPhotoTemporalScreenFamilyAgreement(Map<String, dynamic>? ml) {
    if (ml == null) return false;
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (frames < 2 || rawFrames is! List || rawFrames.length != frames) {
      return false;
    }
    final allScreen = rawFrames.every(
      (frame) =>
          frame is Map &&
          (frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_'),
    );
    return allScreen &&
        strong >= 2 &&
        medium >= 2 &&
        average >= 95.0 &&
        screenProbability >= 0.97;
  }

  static bool _hasPhotoStillScreenFamilyAgreement(Map<String, dynamic>? ml) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final signals = _signals(ml);
    final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final contentArea = (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
    return predictedClass.startsWith('SCREEN_') &&
        frames == 1 &&
        score >= 95 &&
        screenProbability >= 0.95 &&
        fullFrame >= 95 &&
        contentArea >= 90;
  }

  static bool _hasPhotoTemporalRealityAgreement(Map<String, dynamic>? ml) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final average =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrame =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (frames < 2 || rawFrames is! List || rawFrames.length != frames) {
      return false;
    }
    final allReality = rawFrames.every(
      (frame) =>
          frame is Map &&
          (frame['predictedClass']?.toString() ?? '').startsWith('REALITY_'),
    );
    return predictedClass.startsWith('REALITY_') &&
        allReality &&
        strong == 0 &&
        medium == 0 &&
        average <= 12.0 &&
        maxFrame <= 15 &&
        screenProbability <= 0.12;
  }

  static Map<String, dynamic>? _embeddedPhotoTemporalMl(
    Map<String, dynamic>? live,
  ) {
    final probe = live?['photoTemporalVideoProbe'];
    if (probe is! Map) return null;
    final ml = probe['mlScreenReplayAnalysis'];
    if (ml is! Map) return null;
    return Map<String, dynamic>.from(ml);
  }

  static HCVDisplayRiskResult combine(
    List<Map<String, dynamic>?> analyses, {
    bool liveCaptureOnly = false,
  }) {
    final allAvailable = analyses.whereType<Map<String, dynamic>>().toList();
    final postCaptureMl = _firstOfType(
      allAvailable,
      'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    );
    final spatialPostCaptureMl =
        liveCaptureOnly && hasSpatialScreenCorroboration(postCaptureMl)
            ? postCaptureMl
            : null;
    final available = liveCaptureOnly
        ? allAvailable
            .where(
              (analysis) => analysis['type'] == 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
            )
            .toList()
        : allAvailable;
    final live = _firstOfType(available, 'SIGILLUM_LIVE_SCREEN_PROBE_V1');
    final photoTemporalMl =
        liveCaptureOnly ? _embeddedPhotoTemporalMl(live) : null;
    final photoStrongScreenFamilyAgreement = liveCaptureOnly &&
        _hasPhotoTemporalScreenFamilyAgreement(photoTemporalMl) &&
        _hasPhotoStillScreenFamilyAgreement(postCaptureMl);
    final photoLegacyDualRealityAgreement = liveCaptureOnly &&
        _isCredibleRealityMl(
          postCaptureMl,
          maxScore: 2,
          maxScreenProbability: 0.02,
          minConfidence: 0.40,
        ) &&
        _isCredibleRealityMl(
          photoTemporalMl,
          maxScore: 2,
          maxScreenProbability: 0.02,
          minConfidence: 0.60,
        );
    final photoDualRealityAgreement = photoLegacyDualRealityAgreement ||
        (liveCaptureOnly &&
            _isCredibleRealityMl(
              postCaptureMl,
              maxScore: 12,
              maxScreenProbability: 0.12,
              minConfidence: 0.30,
            ) &&
            _hasPhotoTemporalRealityAgreement(photoTemporalMl));
    if (liveCaptureOnly) {
      final videoEquivalent = _embeddedVideoEquivalentResult(live);
      if (videoEquivalent != null &&
          spatialPostCaptureMl == null &&
          !photoDualRealityAgreement &&
          !photoStrongScreenFamilyAgreement) {
        return videoEquivalent;
      }
    }
    final ml =
        _firstOfType(available, 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1') ??
            spatialPostCaptureMl;
    // A post-capture ML REALITY result may corroborate geometric reality in
    // the photo pre-capture policy. A post-capture SCREEN result participates
    // only when full-frame and content-area evidence independently satisfy the
    // strict spatial corroboration gate above.
    final realityMl = liveCaptureOnly ? postCaptureMl : ml;
    final passive = available
        .where(
          (analysis) =>
              analysis['type'] != 'SIGILLUM_LIVE_SCREEN_PROBE_V1' &&
              analysis['type'] != 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
        )
        .toList();

    final scores = available
        .map((analysis) => (analysis['screenReplayRiskScore'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    final rawScore =
        (scores.isEmpty ? 0 : scores.reduce(max)).clamp(0, 100).toInt();

    final evidenceSources = <String>{};
    final strongSources = <String>{};
    final reasons = <String>[];
    if (photoStrongScreenFamilyAgreement) {
      evidenceSources.add('ML_SCREEN_CLASS');
      strongSources.add('ML_SCREEN_CLASS');
      reasons.add('PHOTO_TEMPORAL_AND_STILL_SCREEN_FAMILY_CONFIRMED');
    }

    final liveScore = (live?['screenReplayRiskScore'] as num?)?.toInt();
    final liveSignals = _signals(live);
    final framesAnalyzed = ((live?['framesAnalyzed'] as num?)?.toInt() ?? 0);
    final localFlicker = _number(live, 'localTemporalFlickerScore');
    final refreshBand = _number(live, 'refreshBandScore');
    final fineStripe = _number(live, 'fineStripeScore', fallback: 1);
    final fineGrid = _number(live, 'fineGridScore');
    final moire = _number(live, 'moireFrequencyScore');
    final persistentPattern = _number(live, 'persistentPatternScore');
    final dynamicChallenge = _number(
      live,
      'dynamicChallengeScore',
      fallback: 1,
    );
    final globalFlicker = _number(live, 'globalFlickerScore');
    final rawActiveDisplayEvidence =
        liveSignals['rawActiveDisplayEvidence'] == true;
    final planarSceneEvidence = liveSignals['planarSceneEvidence'] == true;
    final pairedFlickerTrace = liveSignals['pairedFlickerTrace'] == true;
    final displayBandTrace = liveSignals['displayBandTrace'] == true;
    final horizontalRefreshBands =
        liveSignals['horizontalRefreshBands'] == true;

    final activeProbeVersion = (live?['activeProbeVersion'] as num?)?.toInt();
    final activeDisplayEvidence =
        liveSignals['activeIlluminationDisplayEvidence'] == true;
    final reflectedRealityEvidence =
        liveSignals['reflectedRealityEvidence'] == true;
    final activeChallengeIndeterminate =
        liveSignals['activeChallengeIndeterminate'] == true;
    final hardLiveDisplayTrace = liveSignals['confirmedDisplayTrace'] == true ||
        liveSignals['periodicLightTrace'] == true ||
        liveSignals['strongRefreshTrace'] == true ||
        liveSignals['displayBandTrace'] == true ||
        liveSignals['opticalStripeTrace'] == true ||
        liveSignals['opticalCorroboratedTrace'] == true;
    final activeProbeNonConclusive = activeProbeVersion != null &&
        activeProbeVersion >= 2 &&
        live?['displayRiskDecision'] == 'NON_CONCLUSIVE';

    final liveTemporal = live != null &&
        liveScore != null &&
        liveScore >= 70 &&
        (liveSignals['confirmedDisplayTrace'] == true ||
            liveSignals['periodicLightTrace'] == true) &&
        live['displayRiskDecision'] == 'STRONG_DISPLAY_RISK';

    final liveUnifiedDisplaySignature = !reflectedRealityEvidence &&
        live != null &&
        liveScore != null &&
        framesAnalyzed >= 24 &&
        localFlicker >= 0.22 &&
        refreshBand >= 0.088 &&
        fineStripe >= 0.18 &&
        fineStripe < 0.50 &&
        (fineGrid >= 0.60 || moire >= 0.30);

    final liveHighRefreshSignature = !reflectedRealityEvidence &&
        live != null &&
        liveScore != null &&
        framesAnalyzed >= 24 &&
        localFlicker >= 0.30 &&
        refreshBand >= 0.15 &&
        (fineGrid >= 0.75 || moire >= 0.40);

    final liveTemporalBandSignature = !reflectedRealityEvidence &&
        live != null &&
        liveScore != null &&
        framesAnalyzed >= 24 &&
        localFlicker >= 0.24 &&
        refreshBand >= 0.15 &&
        (globalFlicker >= 0.08 || pairedFlickerTrace) &&
        (displayBandTrace || horizontalRefreshBands);
    final activeTemporalPhysicalProof = rawActiveDisplayEvidence &&
        activeDisplayEvidence &&
        liveTemporalBandSignature;
    final planarTemporalPhysicalProof =
        planarSceneEvidence && liveTemporalBandSignature;

    final diagnosticEmissiveTemporal = localFlicker >= 0.55 &&
        refreshBand >= 0.12 &&
        (fineGrid >= 0.80 || moire >= 0.45);
    final diagnosticCorroboratedTemporal = localFlicker >= 0.30 &&
        refreshBand >= 0.15 &&
        (fineGrid >= 0.75 || moire >= 0.40);
    final diagnosticScreenTexture = localFlicker >= 0.38 &&
        refreshBand >= 0.09 &&
        fineStripe >= 0.36 &&
        (fineGrid >= 0.60 || moire >= 0.34);
    final diagnosticLowEmissionTexture = localFlicker >= 0.22 &&
        refreshBand >= 0.09 &&
        fineStripe >= 0.18 &&
        fineStripe <= 0.28 &&
        fineGrid >= 0.70 &&
        fineGrid <= 0.82 &&
        moire <= 0.30 &&
        persistentPattern >= 0.68 &&
        dynamicChallenge <= 0.24 &&
        liveSignals['uncorroboratedDisplayPattern'] == true;
    final diagnosticHighTemporalGrid = localFlicker >= 0.60 &&
        refreshBand >= 0.09 &&
        fineStripe >= 0.28 &&
        fineGrid >= 0.80 &&
        moire >= 0.34 &&
        persistentPattern >= 0.40 &&
        liveSignals['uncorroboratedDisplayPattern'] == true;
    final diagnosticPersistentTexture = fineStripe >= 0.36 &&
        fineGrid >= 0.95 &&
        moire >= 0.50 &&
        persistentPattern >= 0.95 &&
        dynamicChallenge <= 0.10;

    final activePlanarTemporal = !reflectedRealityEvidence &&
        rawActiveDisplayEvidence &&
        planarSceneEvidence &&
        localFlicker >= 0.32 &&
        refreshBand >= 0.13 &&
        persistentPattern >= 0.58;

    final liveModerate = live != null &&
        liveScore != null &&
        (liveTemporal ||
            activePlanarTemporal ||
            activeDisplayEvidence ||
            activeProbeNonConclusive ||
            liveUnifiedDisplaySignature ||
            liveHighRefreshSignature ||
            liveTemporalBandSignature);

    if (liveModerate) evidenceSources.add('LIVE_PREVIEW');
    if (liveTemporalBandSignature) {
      evidenceSources.add('LIVE_TEMPORAL_BANDS');
      reasons.add('LIVE_TEMPORAL_REFRESH_BAND_SIGNATURE');
    }
    if (planarSceneEvidence) evidenceSources.add('PLANAR_GEOMETRY');
    if (activeTemporalPhysicalProof || planarTemporalPhysicalProof) {
      strongSources.add('PHYSICAL_DISPLAY_COMBINATION');
      reasons.add(
        activeTemporalPhysicalProof
            ? 'ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED'
            : 'PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED',
      );
    }
    if (activeDisplayEvidence ||
        rawActiveDisplayEvidence ||
        activeProbeNonConclusive) {
      evidenceSources.add('ACTIVE_ILLUMINATION');
    }
    if (activePlanarTemporal) {
      evidenceSources.add('PLANAR_PARALLAX');
      strongSources.add('ACTIVE_PLANAR_TEMPORAL');
      reasons.add('ACTIVE_ELECTRONIC_PLANAR_TEMPORAL_CONFIRMED');
    }
    if (reflectedRealityEvidence) {
      reasons.add('ACTIVE_REFLECTED_REALITY_EVIDENCE');
    }
    if (activeChallengeIndeterminate) {
      reasons.add('ACTIVE_CHALLENGE_INDETERMINATE');
    }

    if (liveTemporal) {
      strongSources.add('LIVE_TEMPORAL');
      reasons.add('LIVE_TEMPORAL_CONFIRMED');
    } else if (liveModerate) {
      if (activeDisplayEvidence) {
        reasons.add('ACTIVE_EMISSIVE_DISPLAY_EVIDENCE');
      }
      if (activeProbeNonConclusive && !activeDisplayEvidence) {
        reasons.add('ACTIVE_PROBE_REQUIRES_GEOMETRIC_CORROBORATION');
      }
      if (liveUnifiedDisplaySignature) {
        reasons.add('LIVE_UNIFIED_DISPLAY_SIGNATURE');
      }
      if (diagnosticEmissiveTemporal) {
        reasons.add('LIVE_EMISSIVE_TEMPORAL_PATTERN');
      }
      if (diagnosticCorroboratedTemporal) {
        reasons.add('LIVE_CORROBORATED_TEMPORAL_PATTERN');
      }
      if (diagnosticScreenTexture) {
        reasons.add('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN');
      }
      if (diagnosticLowEmissionTexture) {
        reasons.add('LIVE_LOW_EMISSION_TEXTURE_PATTERN');
      }
      if (diagnosticHighTemporalGrid) {
        reasons.add('LIVE_HIGH_TEMPORAL_GRID_PATTERN');
      }
      if (diagnosticPersistentTexture) {
        reasons.add('LIVE_PERSISTENT_DISPLAY_TEXTURE');
      }
    }

    var passiveStrong = false;
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
    if (passiveModerate) evidenceSources.add('STATIC_OPTICAL');
    if (passiveStrong) {
      strongSources.add('STATIC_OPTICAL');
      reasons.add('STATIC_STRUCTURE_CONFIRMED');
    } else if (passiveModerate) {
      reasons.add('STATIC_SCORE_UNCORROBORATED');
    }

    final mlScore = (ml?['screenReplayRiskScore'] as num?)?.toInt();
    final mlClass = ml?['predictedClass']?.toString() ?? '';
    final mlConfidence = (ml?['predictedClassConfidence'] as num?)?.toDouble();
    final mlScreenProbability = (ml?['screenProbability'] as num?)?.toDouble();
    final mlMaxFrameScore =
        (ml?['maxFrameScreenReplayRiskScore'] as num?)?.toInt();
    final mlAverageFrameScore =
        (ml?['averageScreenReplayRiskScore'] as num?)?.toDouble();
    final mlStrongestFrameScore = max(mlScore ?? 0, mlMaxFrameScore ?? 0);
    final mlSaysScreen = mlScore != null && mlClass.startsWith('SCREEN_');
    final mlSaysReality = mlScore != null && mlClass.startsWith('REALITY_');
    final mlVeryStrongFrameEvidence = mlSaysScreen &&
        (mlScreenProbability ?? 0.0) >= 0.96 &&
        (mlConfidence ?? 0.0) >= 0.90 &&
        mlStrongestFrameScore >= 92 &&
        (mlAverageFrameScore == null || mlAverageFrameScore >= 90.0);
    final mlStrong = (mlSaysScreen &&
            mlScore >= 92 &&
            (mlConfidence == null || mlConfidence >= 0.78)) ||
        mlVeryStrongFrameEvidence;
    final mlModerate = mlStrong ||
        (!reflectedRealityEvidence &&
            mlSaysScreen &&
            mlScore >= 88 &&
            (mlConfidence == null || mlConfidence >= 0.70));
    final mlRealityStrong =
        mlSaysReality && (mlConfidence ?? 0.0) >= 0.90 && mlScore <= 2;
    final mlFramesAnalyzed = (ml?['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final mlStrongScreenFrameCount =
        (ml?['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mlMediumScreenFrameCount =
        (ml?['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mlSignals = _signals(ml);
    final mlFullFrameRisk =
        (mlSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final mlContentAreaRisk =
        (mlSignals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
    final mlPersistentVideoEvidence = mlSaysScreen &&
        mlFramesAnalyzed >= 3 &&
        mlStrongScreenFrameCount >= 3 &&
        mlStrongScreenFrameCount * 4 >= mlFramesAnalyzed * 3 &&
        (mlAverageFrameScore ?? 0.0) >= 90.0 &&
        (mlScreenProbability ?? 0.0) >= 0.93 &&
        (mlConfidence ?? 0.0) >= 0.85;
    final mlMultiFrameScreenConsistency = hasMultiFrameScreenConsistency(ml);
    final mlSemanticScreenPersistence =
        hasPersistentSemanticScreenAcrossVideoFrames(ml);
    final mlSemanticRealityPersistence =
        hasPersistentSemanticRealityAcrossVideoFrames(ml);
    final mlShortGeometricSemanticReality =
        hasShortGeometricSemanticRealityAcrossVideoFrames(ml);
    final mlDualRegionPhotoEvidence = hasSpatialScreenCorroboration(ml);
    final mlPersistentCorroboratedEvidence = mlPersistentVideoEvidence ||
        mlMultiFrameScreenConsistency ||
        mlSemanticScreenPersistence ||
        mlDualRegionPhotoEvidence;
    final mlOpticalCorroborated = mlStrong &&
        !reflectedRealityEvidence &&
        (liveUnifiedDisplaySignature ||
            liveHighRefreshSignature ||
            liveTemporalBandSignature);

    final realityMlScore =
        (realityMl?['screenReplayRiskScore'] as num?)?.toInt();
    final realityMlClass = realityMl?['predictedClass']?.toString() ?? '';
    final realityMlConfidence =
        (realityMl?['predictedClassConfidence'] as num?)?.toDouble();
    final mlRealityCredible = realityMlScore != null &&
        realityMlClass.startsWith('REALITY_') &&
        realityMlScore <= 35 &&
        (realityMlConfidence ?? 0.0) >= 0.60;

    if (mlModerate) evidenceSources.add('ML_SCREEN_CLASS');
    if (mlStrong) {
      strongSources.add('ML_SCREEN_CLASS');
      reasons.add('ML_SCREEN_HIGH_CONFIDENCE');
      if (mlVeryStrongFrameEvidence && (mlScore ?? 0) < 92) {
        reasons.add('ML_STRONG_FRAME_EVIDENCE_SURVIVES_AGGREGATE_DOWNWEIGHT');
      }
      if (reflectedRealityEvidence) {
        reasons.add('ML_SCREEN_AND_REFLECTED_REALITY_CONFLICT');
      }
    } else if (mlModerate) {
      reasons.add('ML_SCREEN_MODERATE_CONFIDENCE');
    }
    if (mlOpticalCorroborated) {
      strongSources.add('LIVE_OPTICAL_CORROBORATION');
      reasons.add('ML_SCREEN_AND_LIVE_OPTICAL_PATTERN_CONFIRMED');
    }
    if (mlRealityStrong) {
      reasons.add('ML_REALITY_HIGH_CONFIDENCE');
    }

    final liveGeometryRaw = live?['geometryChallenge'];
    final liveGeometry =
        liveGeometryRaw is Map ? liveGeometryRaw : const <String, dynamic>{};
    final geometrySceneClass =
        liveGeometry['sceneClass']?.toString() ?? 'UNKNOWN';
    final geometryReality =
        reflectedRealityEvidence || geometrySceneClass == 'REALITY';
    final geometryPlanar = geometrySceneClass == 'PLANAR';
    final mlSemanticScreenPersistenceV2 = hasSemanticScreenPersistenceV2(
      ml,
      geometrySceneClass: geometrySceneClass,
      reflectedRealityEvidence: reflectedRealityEvidence,
    );
    final mlRealisticContentScreenPersistence =
        hasRealisticContentScreenPersistence(
      ml,
      reflectedRealityEvidence: reflectedRealityEvidence,
    );
    final mlPlanarSemanticReality =
        hasPlanarSemanticRealityWithoutHardDisplayEvidence(ml);
    if (mlSemanticScreenPersistenceV2 || mlRealisticContentScreenPersistence) {
      evidenceSources.add('ML_SCREEN_CLASS');
      strongSources.add('ML_SCREEN_CLASS');
    }
    final mlGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'REALITY' &&
        (mlPersistentCorroboratedEvidence ||
            mlSemanticScreenPersistenceV2 ||
            mlRealisticContentScreenPersistence);
    final mlUnresolvedGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'UNKNOWN' &&
        (mlPersistentVideoEvidence ||
            mlMultiFrameScreenConsistency ||
            mlSemanticScreenPersistence ||
            mlSemanticScreenPersistenceV2 ||
            mlRealisticContentScreenPersistence);
    final mlPlanarGeometryOverride = !reflectedRealityEvidence &&
        geometrySceneClass == 'PLANAR' &&
        (mlPersistentVideoEvidence ||
            mlMultiFrameScreenConsistency ||
            mlSemanticScreenPersistence ||
            mlSemanticScreenPersistenceV2 ||
            mlRealisticContentScreenPersistence);
    final weakScreenAcrossVideoFrames = !liveCaptureOnly &&
        mlFramesAnalyzed >= 3 &&
        mlStrongScreenFrameCount == 0 &&
        mlMediumScreenFrameCount == 0 &&
        (mlAverageFrameScore ?? 100.0) <= 20.0 &&
        (mlScreenProbability ?? 1.0) <= 0.60 &&
        !mlStrong;
    final strongMultiFrameRealityWithoutGeometry = !liveCaptureOnly &&
        mlSaysReality &&
        mlFramesAnalyzed >= 3 &&
        mlStrongScreenFrameCount == 0 &&
        mlMediumScreenFrameCount == 0 &&
        (mlAverageFrameScore ?? 100.0) <= 12.0 &&
        (mlScreenProbability ?? 1.0) <= 0.10 &&
        (mlConfidence ?? 0.0) >= 0.70 &&
        geometrySceneClass != 'PLANAR' &&
        !planarSceneEvidence &&
        !rawActiveDisplayEvidence &&
        !activeDisplayEvidence &&
        !passiveStructuralEvidence &&
        !passiveStrong &&
        !passiveModerate &&
        !mlStrong;
    final activeOnlyCanBeOverriddenBySemanticReality =
        (!rawActiveDisplayEvidence && !activeDisplayEvidence) ||
            (geometrySceneClass != 'PLANAR' &&
                !planarSceneEvidence &&
                mlFramesAnalyzed >= 4 &&
                mlStrongScreenFrameCount == 0 &&
                mlMediumScreenFrameCount == 0 &&
                (mlAverageFrameScore ?? 100.0) <= 10.0 &&
                (mlScreenProbability ?? 1.0) <= 0.12);
    final semanticMultiFrameRealityWithoutDisplayCorroboration =
        !liveCaptureOnly &&
            mlSemanticRealityPersistence &&
            activeOnlyCanBeOverriddenBySemanticReality &&
            liveSignals['confirmedDisplayTrace'] != true &&
            liveSignals['periodicLightTrace'] != true &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate &&
            !mlStrong;
    final shortGeometricSemanticRealityAgreement = !liveCaptureOnly &&
        geometrySceneClass == 'REALITY' &&
        !reflectedRealityEvidence &&
        mlShortGeometricSemanticReality &&
        liveSignals['confirmedDisplayTrace'] != true &&
        liveSignals['periodicLightTrace'] != true &&
        !passiveStructuralEvidence &&
        !passiveStrong &&
        !passiveModerate &&
        !mlStrong;
    final geometryRealityWithIndependentNonDisplay =
        geometrySceneClass == 'REALITY' &&
            weakScreenAcrossVideoFrames &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate;
    final planarSemanticRealityWithoutHardDisplayEvidence = !liveCaptureOnly &&
        geometrySceneClass == 'PLANAR' &&
        mlPlanarSemanticReality &&
        !rawActiveDisplayEvidence &&
        !activeDisplayEvidence &&
        !hardLiveDisplayTrace &&
        !passiveStructuralEvidence &&
        !passiveStrong &&
        !passiveModerate &&
        !mlStrong;

    final strongDisplayFamilies = <String>{};
    if (liveTemporal) strongDisplayFamilies.add('LIVE_TEMPORAL');
    if (activeDisplayEvidence) {
      strongDisplayFamilies.add('ACTIVE_ILLUMINATION');
    }
    if (passiveStrong) strongDisplayFamilies.add('STATIC_OPTICAL');
    if (mlStrong) strongDisplayFamilies.add('ML_SCREEN_CLASS');
    if (activePlanarTemporal) {
      strongDisplayFamilies.add('ACTIVE_ILLUMINATION');
      strongDisplayFamilies.add('PLANAR_GEOMETRY');
      strongDisplayFamilies.add('LIVE_TEMPORAL');
    }

    final hasIndependentCorroboration = strongDisplayFamilies.length >= 2;
    final hasAnyEvidence = evidenceSources.isNotEmpty;
    final liveNotAnalyzed = live == null ||
        liveScore == null ||
        live?['analysisStatus'] == 'NOT_ANALYZED';

    final liveReason = live?['reason']?.toString() ?? '';
    final signedGeometricReality = live != null &&
        live['sceneClass'] == 'REALITY' &&
        live['displayRiskDecision'] == 'NO_DISPLAY_EVIDENCE' &&
        (liveReason.contains('MULTI_DEPTH_PARALLAX_DETECTED') ||
            liveReason.contains(
              'GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS',
            ));
    final confirmedDisplayEvidence = liveTemporal ||
        activeDisplayEvidence ||
        mlStrong ||
        mlSemanticScreenPersistenceV2 ||
        mlRealisticContentScreenPersistence ||
        photoStrongScreenFamilyAgreement;
    final independentRealityAgreement = geometryReality &&
        !geometryPlanar &&
        !planarSceneEvidence &&
        mlRealityCredible &&
        !activeDisplayEvidence &&
        !passiveStructuralEvidence &&
        !hasIndependentCorroboration &&
        !mlStrong;

    late final String decision;
    late final int score;
    if (photoStrongScreenFamilyAgreement && !reflectedRealityEvidence) {
      decision = 'STRONG_DISPLAY_RISK';
      final stillScore =
          (postCaptureMl?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      final temporalScore =
          (photoTemporalMl?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      score = max(
        max(rawScore, stillScore),
        temporalScore,
      ).clamp(85, 100).toInt();
    } else if (photoDualRealityAgreement &&
        !hardLiveDisplayTrace &&
        !passiveStructuralEvidence &&
        !passiveStrong &&
        !passiveModerate &&
        !mlStrong) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.remove('ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add(
        'PHOTO_DUAL_REALITY_ML_AGREEMENT_OVERRIDES_ACTIVE_ONLY_SIGNAL',
      );
    } else if (signedGeometricReality && !confirmedDisplayEvidence) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      evidenceSources.remove('STATIC_OPTICAL');
      strongSources.remove('STATIC_OPTICAL');
      reasons.remove('STATIC_STRUCTURE_CONFIRMED');
      reasons.remove('STATIC_SCORE_UNCORROBORATED');
      reasons.add(
        'SIGNED_GEOMETRIC_REALITY_OVERRIDES_UNCORROBORATED_DISPLAY_SIGNALS',
      );
    } else if (planarSemanticRealityWithoutHardDisplayEvidence) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add(
        'PLANAR_GEOMETRY_RESOLVED_BY_SEMANTIC_REALITY_WITHOUT_HARD_DISPLAY_EVIDENCE',
      );
    } else if (hasIndependentCorroboration) {
      decision = 'STRONG_DISPLAY_RISK';
      score = max(rawScore, 70).clamp(70, 100).toInt();
    } else if (mlOpticalCorroborated) {
      decision = 'STRONG_DISPLAY_RISK';
      score = max(
        max(rawScore, mlStrongestFrameScore),
        85,
      ).clamp(85, 100).toInt();
    } else if (mlGeometryOverride ||
        mlUnresolvedGeometryOverride ||
        mlPlanarGeometryOverride) {
      decision = 'STRONG_DISPLAY_RISK';
      score = max(
        max(rawScore, mlStrongestFrameScore),
        85,
      ).clamp(85, 100).toInt();
      if (mlPersistentVideoEvidence) {
        reasons.add('ML_SCREEN_MULTI_FRAME_PERSISTENCE_CONFIRMED');
      }
      if (mlMultiFrameScreenConsistency) {
        reasons.add('ML_SCREEN_MULTI_FRAME_CONSISTENCY_CONFIRMED');
      }
      if (mlSemanticScreenPersistence) {
        reasons.add('ML_SCREEN_ALL_FRAME_SEMANTIC_PERSISTENCE_CONFIRMED');
      }
      if (mlSemanticScreenPersistenceV2) {
        reasons.add('ML_SCREEN_SEMANTIC_PERSISTENCE_V2_CONFIRMED');
      }
      if (mlRealisticContentScreenPersistence) {
        reasons.add('ML_SCREEN_REALISTIC_CONTENT_PERSISTENCE_CONFIRMED');
      }
      if (mlDualRegionPhotoEvidence) {
        reasons.add('ML_SCREEN_DUAL_REGION_CONFIRMED');
      }
      reasons.add(
        mlGeometryOverride
            ? 'ML_GEOMETRY_CONFLICT_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'
            : mlUnresolvedGeometryOverride
                ? 'ML_UNRESOLVED_GEOMETRY_RESOLVED_BY_CORROBORATED_SCREEN_EVIDENCE'
                : 'ML_PLANAR_GEOMETRY_CORROBORATED_BY_MULTI_FRAME_SCREEN_EVIDENCE',
      );
    } else if (semanticMultiFrameRealityWithoutDisplayCorroboration) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.remove('ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add(
        'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
      );
    } else if (shortGeometricSemanticRealityAgreement) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.remove('ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add('SHORT_VIDEO_GEOMETRIC_AND_SEMANTIC_REALITY_AGREE');
    } else if (geometryRealityWithIndependentNonDisplay) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      reasons.add(
        'GEOMETRIC_REALITY_AND_WEAK_MULTI_FRAME_SCREEN_EVIDENCE_AGREE',
      );
    } else if (strongMultiFrameRealityWithoutGeometry) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      reasons.add(
        'MULTI_FRAME_REALITY_RESOLVES_UNCORROBORATED_TEMPORAL_SIGNAL',
      );
    } else if (photoDualRealityAgreement &&
        !passiveStructuralEvidence &&
        !hasIndependentCorroboration &&
        !mlStrong) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      reasons.add(
        'PHOTO_DUAL_REALITY_ML_AGREEMENT_OVERRIDES_ACTIVE_ONLY_SIGNAL',
      );
    } else if (mlStrong && geometryReality) {
      decision = 'NON_CONCLUSIVE';
      score = max(45, min(rawScore, 69));
      reasons.add('ML_GEOMETRY_CONFLICT');
    } else if (activeDisplayEvidence && geometryReality) {
      decision = 'NON_CONCLUSIVE';
      score = max(45, min(rawScore, 69));
      reasons.add('ACTIVE_DISPLAY_GEOMETRY_CONFLICT');
    } else if (independentRealityAgreement) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      reasons.add(
        'INDEPENDENT_REALITY_AGREEMENT_OVERRIDES_TEMPORAL_ONLY_SIGNAL',
      );
    } else if (mlRealityStrong) {
      if (geometryReality && !hasAnyEvidence && !activeDisplayEvidence) {
        decision = 'NO_DISPLAY_EVIDENCE';
        score = min(rawScore, 20);
        reasons.add('ML_REALITY_AND_GEOMETRY_AGREE');
      } else if (geometryPlanar || hasAnyEvidence || activeDisplayEvidence) {
        decision = 'NON_CONCLUSIVE';
        score = 45;
        reasons.add('ML_REALITY_REQUIRES_INDEPENDENT_CORROBORATION');
      } else if (liveNotAnalyzed || activeChallengeIndeterminate) {
        decision = 'NON_CONCLUSIVE';
        score = 45;
        reasons.add('DISPLAY_CLASSIFICATION_NOT_RESOLVED');
      } else {
        decision = 'NO_DISPLAY_EVIDENCE';
        score = min(rawScore, 20);
        reasons.add('ML_REALITY_UNOPPOSED');
      }
    } else if (hasAnyEvidence || activeDisplayEvidence) {
      decision = 'NON_CONCLUSIVE';
      score = max(45, min(rawScore, 69));
    } else if (liveNotAnalyzed || activeChallengeIndeterminate) {
      decision = 'NON_CONCLUSIVE';
      score = 45;
      reasons.add('DISPLAY_CLASSIFICATION_NOT_RESOLVED');
    } else {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 30);
    }

    final missingReasons = <String>[];
    _appendMissingReason(
      missingReasons,
      live,
      missingTypeReason: 'LIVE_PROBE_MISSING',
    );
    if (!liveCaptureOnly) {
      _appendMissingReason(
        missingReasons,
        ml,
        missingTypeReason: 'ML_ANALYSIS_MISSING',
      );
    }
    reasons.addAll(missingReasons);

    final analysisStatus = missingReasons.isEmpty ? 'COMPLETE' : 'PARTIAL';
    return HCVDisplayRiskResult(
      risk: score >= 70
          ? 'HIGH'
          : score >= 45
              ? 'MEDIUM'
              : 'LOW',
      score: score,
      decision: decision,
      analysisStatus: analysisStatus,
      evidenceSources: evidenceSources.toList()..sort(),
      strongSources: strongSources.toList()..sort(),
      reasons: reasons,
    );
  }

  static HCVDisplayRiskResult? _embeddedVideoEquivalentResult(
    Map<String, dynamic>? live,
  ) {
    if (live == null || live['videoEquivalentAvailable'] != true) {
      return null;
    }

    final raw = live['videoEquivalentDisplayRisk'];
    if (raw is! Map) return null;

    final decision = raw['decision']?.toString();
    final score = (raw['score'] as num?)?.toInt();
    const validDecisions = <String>{
      'NO_DISPLAY_EVIDENCE',
      'NON_CONCLUSIVE',
      'STRONG_DISPLAY_RISK',
    };
    if (decision == null ||
        score == null ||
        !validDecisions.contains(decision)) {
      return null;
    }

    final evidenceSources = _stringList(raw['evidenceSources']);
    final strongSources = _stringList(raw['strongSources']);
    final reasons = _stringList(raw['reasons']);
    if (!reasons.contains('PHOTO_VIDEO_EQUIVALENT_METHOD')) {
      reasons.add('PHOTO_VIDEO_EQUIVALENT_METHOD');
    }

    return HCVDisplayRiskResult(
      risk: raw['risk']?.toString() ??
          (score >= 70
              ? 'HIGH'
              : score >= 45
                  ? 'MEDIUM'
                  : 'LOW'),
      score: score.clamp(0, 100).toInt(),
      decision: decision,
      analysisStatus: raw['analysisStatus']?.toString() ?? 'PARTIAL',
      evidenceSources: evidenceSources,
      strongSources: strongSources,
      reasons: reasons,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! Iterable) return <String>[];
    return value.map((item) => item.toString()).toList();
  }

  static Map<String, dynamic>? _firstOfType(
    List<Map<String, dynamic>> analyses,
    String type,
  ) {
    for (final analysis in analyses) {
      if (analysis['type'] == type) return analysis;
    }
    return null;
  }

  static Map<dynamic, dynamic> _signals(Map<String, dynamic>? analysis) {
    final signals = analysis?['signals'];
    return signals is Map ? signals : const <String, dynamic>{};
  }

  static double _number(
    Map<String, dynamic>? analysis,
    String key, {
    double fallback = 0,
  }) {
    return (analysis?[key] as num?)?.toDouble() ?? fallback;
  }

  static void _appendMissingReason(
    List<String> output,
    Map<String, dynamic>? analysis, {
    required String missingTypeReason,
  }) {
    if (analysis == null) {
      output.add(missingTypeReason);
      return;
    }
    final score = analysis['screenReplayRiskScore'];
    final status = analysis['analysisStatus']?.toString();
    if (score != null && status != 'NOT_ANALYZED') return;

    final reason = analysis['reason']?.toString();
    output.add(
      reason == null || reason.isEmpty
          ? missingTypeReason
          : '${missingTypeReason}_$reason',
    );
  }
}
