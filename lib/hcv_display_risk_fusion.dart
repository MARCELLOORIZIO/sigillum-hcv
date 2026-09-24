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
  static const _liveTypes = {
    'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'SIGILLUM_LIVE_SCREEN_PROBE_V2',
  };

  static HCVDisplayRiskResult combine(
    List<Map<String, dynamic>?> analyses, {
    bool liveCaptureOnly = false,
  }) {
    final available = analyses.whereType<Map<String, dynamic>>().toList();
    final live = _firstLive(available);
    final ml = _firstOfType(available, 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1');
    final passive = available
        .where((analysis) =>
            !_liveTypes.contains(analysis['type']) &&
            analysis['type'] != 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1')
        .toList();

    final reasons = <String>[];
    final evidenceSources = <String>{};
    final strongSources = <String>{};
    final validScores = available
        .where((analysis) => analysis['analysisStatus'] != 'NOT_ANALYZED')
        .map((analysis) => (analysis['screenReplayRiskScore'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    final rawScore =
        (validScores.isEmpty ? 0 : validScores.reduce(max)).clamp(0, 100).toInt();

    final liveAnalyzed = live != null &&
        live['analysisStatus'] != 'NOT_ANALYZED' &&
        live['screenReplayRiskScore'] != null;
    final liveDecision = live?['displayRiskDecision']?.toString() ?? '';
    final liveScore = (live?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final liveQuality = _number(live, 'analysisQuality', fallback: 1);
    final liveSignals = _signals(live);

    final liveStrong = liveAnalyzed &&
        liveQuality >= 0.52 &&
        liveDecision == 'STRONG_DISPLAY_RISK' &&
        liveScore >= 70 &&
        liveSignals['confirmedDisplayTrace'] == true;
    final liveModerate = liveAnalyzed &&
        liveQuality >= 0.48 &&
        (liveDecision == 'NON_CONCLUSIVE' ||
            liveStrong ||
            (liveScore >= 45 &&
                (liveSignals['corroboratedModerateTrace'] == true ||
                    liveSignals['confirmedDisplayTrace'] == true)));
    final liveWeakSupport = liveAnalyzed &&
        liveQuality >= 0.48 &&
        (liveScore >= 20 ||
            liveSignals['temporalEvidence'] == true ||
            liveSignals['stripeEvidence'] == true ||
            liveSignals['spatialEvidence'] == true ||
            liveSignals['uncorroboratedDisplayPattern'] == true);

    if (liveModerate) evidenceSources.add('LIVE_PREVIEW');
    if (liveStrong) {
      strongSources.add('LIVE_PREVIEW');
      reasons.add('LIVE_DISPLAY_TRACE_CONFIRMED');
    } else if (liveModerate) {
      reasons.add('LIVE_DISPLAY_TRACE_NON_CONCLUSIVE');
    } else if (liveWeakSupport) {
      reasons.add('LIVE_DISPLAY_TRACE_WEAK_SUPPORT');
    } else if (live != null && !liveAnalyzed) {
      reasons.add(
        'LIVE_PROBE_NOT_ANALYZED_${live['reason']?.toString() ?? 'UNKNOWN'}',
      );
    }

    var passiveStrong = false;
    var passiveModerate = false;
    for (final analysis in passive) {
      if (analysis['analysisStatus'] == 'NOT_ANALYZED') continue;
      final score = (analysis['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
      final signals = _signals(analysis);
      final structural = _passiveStructuralEvidence(
        analysis['type']?.toString() ?? '',
        signals,
      );
      if (score >= 70 && structural) passiveStrong = true;
      if ((score >= 45 && structural) || (score >= 85 && structural)) {
        passiveModerate = true;
      }
    }
    if (passiveModerate) evidenceSources.add('STATIC_OPTICAL');
    if (passiveStrong) {
      strongSources.add('STATIC_OPTICAL');
      reasons.add('STATIC_STRUCTURE_CONFIRMED');
    } else if (passiveModerate) {
      reasons.add('STATIC_STRUCTURE_NON_CONCLUSIVE');
    }

    final mlAnalyzed = ml != null &&
        ml['analysisStatus'] != 'NOT_ANALYZED' &&
        ml['screenReplayRiskScore'] != null;
    final mlScore = (ml?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final mlClass = ml?['predictedClass']?.toString() ?? '';
    final mlConfidence = (ml?['predictedClassConfidence'] as num?)?.toDouble();
    final mlSaysScreen = mlAnalyzed && mlClass.startsWith('SCREEN_');
    final mlStrong = mlSaysScreen &&
        mlScore >= 92 &&
        (mlConfidence == null || mlConfidence >= 0.78);
    final mlModerate = mlSaysScreen &&
        mlScore >= 82 &&
        (mlConfidence == null || mlConfidence >= 0.65);
    if (mlModerate) evidenceSources.add('ML_SCREEN_CLASS');
    if (mlStrong) {
      strongSources.add('ML_SCREEN_CLASS');
      reasons.add('ML_SCREEN_HIGH_CONFIDENCE');
    } else if (mlModerate) {
      reasons.add('ML_SCREEN_MODERATE_CONFIDENCE');
    }

    final analyzedCount = available
        .where((analysis) =>
            analysis['analysisStatus'] != 'NOT_ANALYZED' &&
            analysis['screenReplayRiskScore'] != null)
        .length;
    final postCaptureEvidenceCount =
        (passiveModerate ? 1 : 0) + (mlModerate ? 1 : 0);
    final independentEvidenceCount = evidenceSources.length;

    final strongDecision = liveCaptureOnly
        ? liveStrong && postCaptureEvidenceCount >= 1
        : strongSources.isNotEmpty && independentEvidenceCount >= 2;

    final moderateDecision = liveCaptureOnly
        ? liveModerate ||
            postCaptureEvidenceCount >= 2 ||
            (liveWeakSupport && postCaptureEvidenceCount >= 1)
        : independentEvidenceCount >= 1;

    late final String decision;
    late final int score;
    late final String risk;
    late final String analysisStatus;

    if (analyzedCount == 0 ||
        (liveCaptureOnly && !liveAnalyzed && postCaptureEvidenceCount < 2)) {
      decision = 'NOT_ANALYZED';
      score = 0;
      risk = 'UNKNOWN';
      analysisStatus = 'NOT_ANALYZED';
      if (live == null) reasons.add('LIVE_PROBE_MISSING');
      if (!liveCaptureOnly && ml == null) reasons.add('ML_ANALYSIS_MISSING');
    } else if (strongDecision) {
      decision = 'STRONG_DISPLAY_RISK';
      score = max(rawScore, 70).clamp(70, 100).toInt();
      risk = 'HIGH';
      analysisStatus =
          analyzedCount == available.length ? 'COMPLETE' : 'PARTIAL';
    } else if (moderateDecision) {
      decision = 'NON_CONCLUSIVE';
      score = max(45, min(rawScore, 69));
      risk = 'MEDIUM';
      analysisStatus =
          analyzedCount == available.length ? 'COMPLETE' : 'PARTIAL';
      if (liveCaptureOnly && postCaptureEvidenceCount >= 2 && !liveModerate) {
        reasons.add('POST_CAPTURE_SOURCES_CORROBORATE_SCREEN');
      }
    } else {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 30);
      risk = 'LOW';
      analysisStatus =
          analyzedCount == available.length ? 'COMPLETE' : 'PARTIAL';
    }

    return HCVDisplayRiskResult(
      risk: risk,
      score: score,
      decision: decision,
      analysisStatus: analysisStatus,
      evidenceSources: evidenceSources.toList()..sort(),
      strongSources: strongSources.toList()..sort(),
      reasons: reasons,
    );
  }

  static bool _passiveStructuralEvidence(
    String type,
    Map<dynamic, dynamic> signals,
  ) {
    final genericStructural = signals['structuralDisplayTrace'] == true ||
        signals['strongDisplayTrace'] == true ||
        signals['confirmedDisplayTrace'] == true;
    if (type != 'SIGILLUM_SCREEN_REPLAY_IMAGE_ANALYSIS_V1') {
      return genericStructural;
    }

    final pixelSpecific = signals['uniformPixelGrid'] == true ||
        signals['pixelGridOrMoireHint'] == true;
    final framedBrightBands =
        signals['brightUniformDisplayBands'] == true &&
            signals['rectangularDisplayEdges'] == true;

    return pixelSpecific || framedBrightBands;
  }

  static Map<String, dynamic>? _firstLive(
    List<Map<String, dynamic>> analyses,
  ) {
    for (final analysis in analyses) {
      if (analysis['type'] == 'SIGILLUM_LIVE_SCREEN_PROBE_V2') return analysis;
    }
    for (final analysis in analyses) {
      if (analysis['type'] == 'SIGILLUM_LIVE_SCREEN_PROBE_V1') return analysis;
    }
    return null;
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
}
