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

    final liveTemporal = live != null &&
        liveScore != null &&
        liveScore >= 70 &&
        (liveSignals['confirmedDisplayTrace'] == true ||
            liveSignals['periodicLightTrace'] == true) &&
        live['displayRiskDecision'] == 'STRONG_DISPLAY_RISK';

    final liveEmissiveTemporal = live != null &&
        liveScore != null &&
        framesAnalyzed >= 24 &&
        localFlicker >= 0.55 &&
        refreshBand >= 0.12 &&
        (fineGrid >= 0.80 || moire >= 0.45);

    final liveCorroboratedModerate = live != null &&
        liveScore != null &&
        framesAnalyzed >= 24 &&
        localFlicker >= 0.30 &&
        refreshBand >= 0.15 &&
        (fineGrid >= 0.75 || moire >= 0.40);

    // iOS archive 15: the camera's exposure/zoom transition attenuates the
    // refresh score, while a real monitor still retains four independent
    // characteristics together. This remains moderate evidence only.
    final liveScreenTextureModerate = live != null &&
        liveScore != null &&
        framesAnalyzed >= 24 &&
        localFlicker >= 0.38 &&
        refreshBand >= 0.09 &&
        fineStripe >= 0.36 &&
        (fineGrid >= 0.60 || moire >= 0.34);

    final liveModerate = live != null &&
        liveScore != null &&
        (liveTemporal ||
            liveEmissiveTemporal ||
            liveCorroboratedModerate ||
            liveScreenTextureModerate);

    if (liveModerate) evidenceSources.add('LIVE_PREVIEW');
    if (liveTemporal) {
      strongSources.add('LIVE_TEMPORAL');
      reasons.add('LIVE_TEMPORAL_CONFIRMED');
    } else if (liveEmissiveTemporal) {
      reasons.add('LIVE_EMISSIVE_TEMPORAL_PATTERN');
    } else if (liveCorroboratedModerate) {
      reasons.add('LIVE_CORROBORATED_TEMPORAL_PATTERN');
    } else if (liveScreenTextureModerate) {
      reasons.add('LIVE_SCREEN_TEXTURE_TEMPORAL_PATTERN');
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
      if ((score >= 45 && structural) || score >= 70) passiveModerate = true;
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
    final mlModerate = mlSaysScreen &&
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

    late final String decision;
    late final int score;
    if (hasIndependentCorroboration) {
      decision = 'STRONG_DISPLAY_RISK';
      score = max(rawScore, 70).clamp(70, 100).toInt();
    } else if (hasAnyEvidence) {
      decision = 'NON_CONCLUSIVE';
      score = max(45, min(rawScore, 69));
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
