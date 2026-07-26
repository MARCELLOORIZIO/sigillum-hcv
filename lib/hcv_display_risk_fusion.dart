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
  static HCVDisplayRiskResult combine(
    List<Map<String, dynamic>?> analyses, {
    bool liveCaptureOnly = false,
  }) {
    final allAvailable = analyses.whereType<Map<String, dynamic>>().toList();
    final available = liveCaptureOnly
        ? allAvailable
            .where((analysis) =>
                analysis['type'] == 'SIGILLUM_LIVE_SCREEN_PROBE_V1')
            .toList()
        : allAvailable;
    final live = _firstOfType(available, 'SIGILLUM_LIVE_SCREEN_PROBE_V1');
    if (liveCaptureOnly) {
      final videoEquivalent = _embeddedVideoEquivalentResult(live);
      if (videoEquivalent != null) {
        return videoEquivalent;
      }
    }
    final ml = _firstOfType(available, 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1');
    final passive = available
        .where((analysis) =>
            analysis['type'] != 'SIGILLUM_LIVE_SCREEN_PROBE_V1' &&
            analysis['type'] != 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1')
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

    final liveScore = (live?['screenReplayRiskScore'] as num?)?.toInt();
    final liveSignals = _signals(live);
    final framesAnalyzed =
        ((live?['framesAnalyzed'] as num?)?.toInt() ?? 0);
    final localFlicker = _number(live, 'localTemporalFlickerScore');
    final refreshBand = _number(live, 'refreshBandScore');
    final fineStripe = _number(live, 'fineStripeScore', fallback: 1);
    final fineGrid = _number(live, 'fineGridScore');
    final moire = _number(live, 'moireFrequencyScore');
    final persistentPattern = _number(live, 'persistentPatternScore');
    final dynamicChallenge =
        _number(live, 'dynamicChallengeScore', fallback: 1);

    final activeProbeVersion = (live?['activeProbeVersion'] as num?)?.toInt();
    final activeDisplayEvidence =
        liveSignals['activeIlluminationDisplayEvidence'] == true;
    final reflectedRealityEvidence =
        liveSignals['reflectedRealityEvidence'] == true;
    final activeChallengeIndeterminate =
        liveSignals['activeChallengeIndeterminate'] == true;
    final activeProbeNonConclusive = activeProbeVersion != null &&
        activeProbeVersion >= 2 &&
        live?['displayRiskDecision'] == 'NON_CONCLUSIVE';

    final liveTemporal = live != null &&
        liveScore != null &&
        liveScore >= 70 &&
        (liveSignals['confirmedDisplayTrace'] == true ||
            liveSignals['periodicLightTrace'] == true) &&
        live['displayRiskDecision'] == 'STRONG_DISPLAY_RISK';

    // Legacy passive signatures remain available for old certificates and as
    // corroboration, but a valid reflected-reality response suppresses them.
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

    // Diagnostic labels only; they do not decide the verdict.
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

    final liveModerate = live != null &&
        liveScore != null &&
        (liveTemporal ||
            activeDisplayEvidence ||
            activeProbeNonConclusive ||
            liveUnifiedDisplaySignature ||
            liveHighRefreshSignature);

    if (liveModerate) evidenceSources.add('LIVE_PREVIEW');
    if (activeDisplayEvidence || activeProbeNonConclusive) {
      evidenceSources.add('ACTIVE_ILLUMINATION');
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
    for (final analysis in passive) {
      final score = (analysis['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      final signals = _signals(analysis);
      final structural = signals['structuralDisplayTrace'] == true ||
          signals['strongDisplayTrace'] == true ||
          signals['confirmedDisplayTrace'] == true;
      if (score >= 70 && structural) passiveStrong = true;
      if (!reflectedRealityEvidence &&
          ((score >= 45 && structural) || score >= 70)) {
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
    final mlSaysScreen = mlScore != null && mlClass.startsWith('SCREEN_');
    final mlStrong = mlSaysScreen &&
        mlScore >= 92 &&
        (mlConfidence == null || mlConfidence >= 0.78);
    final mlModerate = !reflectedRealityEvidence &&
        mlSaysScreen &&
        mlScore >= 88 &&
        (mlConfidence == null || mlConfidence >= 0.70);
    if (mlModerate) evidenceSources.add('ML_SCREEN_CLASS');
    if (mlStrong) {
      strongSources.add('ML_SCREEN_CLASS');
      reasons.add('ML_SCREEN_HIGH_CONFIDENCE');
    } else if (mlModerate) {
      reasons.add('ML_SCREEN_MODERATE_CONFIDENCE');
    }

    final hasIndependentCorroboration =
        strongSources.isNotEmpty && evidenceSources.length >= 2;
    final hasAnyEvidence = evidenceSources.isNotEmpty;
    final liveNotAnalyzed = live == null ||
        liveScore == null ||
        live?['analysisStatus'] == 'NOT_ANALYZED';

    late final String decision;
    late final int score;
    if (hasIndependentCorroboration) {
      decision = 'STRONG_DISPLAY_RISK';
      score = max(rawScore, 70).clamp(70, 100).toInt();
    } else if (hasAnyEvidence) {
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
