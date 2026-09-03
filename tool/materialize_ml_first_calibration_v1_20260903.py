from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one replacement target, found {count}")
    p.write_text(text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# 1) ML-first pure decision helpers.
# ---------------------------------------------------------------------------
replace_once(
    "lib/hcv_display_risk_fusion.dart",
    "class HCVDisplayRiskFusion {\n",
    """class HCVDisplayRiskFusion {
  static HCVDisplayRiskResult? mlFirstPhotoDecision(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return null;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble();
    if (screenProbability == null) return null;
    final mlScore = (ml['screenReplayRiskScore'] as num?)?.toInt() ??
        (screenProbability * 100).round();

    if (predictedClass.startsWith('SCREEN_') && screenProbability >= 0.90) {
      final score = mlScore.clamp(90, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_SCREEN_CLASS'],
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: const ['ML_FIRST_PHOTO_SCREEN_FAMILY_HIGH_PROBABILITY'],
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

  static HCVDisplayRiskResult? mlFirstVideoDecision(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return null;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble();
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
      return (frame['predictedClass']?.toString() ?? '')
          .startsWith('SCREEN_');
    }).length;
    final screenMajority = screenFrames * 2 > framesAnalyzed;
    final noScreenMajority = screenFrames * 2 <= framesAnalyzed;
    final mlScore = (ml['screenReplayRiskScore'] as num?)?.toInt() ??
        (screenProbability * 100).round();

    if (screenProbability >= 0.75 && screenMajority) {
      final score = mlScore.clamp(75, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_SCREEN_CLASS'],
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: const ['ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY'],
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

""",
)

# ---------------------------------------------------------------------------
# 2) Camera wrapper: strong ML is primary; strong ML REALITY falls back only
#    when truly hard independent display evidence exists. Gray/no-ML uses the
#    existing fusion unchanged.
# ---------------------------------------------------------------------------
replace_once(
    "lib/camera_page.dart",
    """Map<String, dynamic>? _liveProbeFromAnalyses(
  List<Map<String, dynamic>?> analyses,
) {
  for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
    if (analysis['type'] == 'SIGILLUM_LIVE_SCREEN_PROBE_V1') {
      return analysis;
    }
  }
  return null;
}

""",
    """Map<String, dynamic>? _liveProbeFromAnalyses(
  List<Map<String, dynamic>?> analyses,
) {
  for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
    if (analysis['type'] == 'SIGILLUM_LIVE_SCREEN_PROBE_V1') {
      return analysis;
    }
  }
  return null;
}

Map<String, dynamic>? _mlAnalysisFromAnalyses(
  List<Map<String, dynamic>?> analyses,
) {
  for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
    if (analysis['type'] == 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1') {
      return analysis;
    }
  }
  return null;
}

bool _hasHardDisplayCorroboration(
  List<Map<String, dynamic>?> analyses,
) {
  for (final analysis in analyses.whereType<Map<String, dynamic>>()) {
    final rawSignals = analysis['signals'];
    if (rawSignals is! Map) continue;
    if (rawSignals['confirmedDisplayTrace'] == true ||
        rawSignals['periodicLightTrace'] == true ||
        rawSignals['opticalCorroboratedTrace'] == true) {
      return true;
    }
  }
  return false;
}

""",
)

replace_once(
    "lib/camera_page.dart",
    """HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final preCapture = HCVDisplayRiskFusion.combine(
""",
    """HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final mlFirst = HCVDisplayRiskFusion.mlFirstPhotoDecision(
    _mlAnalysisFromAnalyses(analyses),
  );
  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return mlFirst;
  }

  final preCapture = HCVDisplayRiskFusion.combine(
""",
)

replace_once(
    "lib/camera_page.dart",
    """HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final normalResult = HCVDisplayRiskFusion.combine(analyses);
""",
    """HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final mlFirst = HCVDisplayRiskFusion.mlFirstVideoDecision(
    _mlAnalysisFromAnalyses(analyses),
  );
  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return mlFirst;
  }

  final normalResult = HCVDisplayRiskFusion.combine(analyses);
""",
)

print('ML-first calibration v1 runtime patch materialized')
