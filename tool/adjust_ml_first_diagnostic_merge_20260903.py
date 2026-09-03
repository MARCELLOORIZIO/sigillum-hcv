from pathlib import Path

# Validation revision 2: keep legacy reasons as diagnostics under ML-first.

def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one target, found {count}")
    p.write_text(text.replace(old, new, 1))


camera = 'lib/camera_page.dart'

# Preserve the existing fusion output as diagnostics even when ML-first owns the
# decision. This keeps evidence/reasons auditable and makes the old fusion the
# gray-zone fallback rather than a veto layer.
replace_once(
    camera,
    """bool _hasHardDisplayCorroboration(
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
    """bool _hasHardDisplayCorroboration(
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

HCVDisplayRiskResult _mergeMlPrimaryWithDiagnostics(
  HCVDisplayRiskResult primary,
  HCVDisplayRiskResult diagnostics,
) {
  final evidenceSources = <String>{
    ...primary.evidenceSources,
    ...diagnostics.evidenceSources,
  }.toList()
    ..sort();
  final strongSources = <String>{
    ...primary.strongSources,
    ...diagnostics.strongSources,
  }.toList()
    ..sort();
  final reasons = <String>{
    ...primary.reasons,
    ...diagnostics.reasons,
  }.toList();

  return HCVDisplayRiskResult(
    risk: primary.risk,
    score: primary.score,
    decision: primary.decision,
    analysisStatus: primary.analysisStatus,
    evidenceSources: evidenceSources,
    strongSources: strongSources,
    reasons: reasons,
  );
}

""",
)

replace_once(
    camera,
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
    """HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final mlFirst = HCVDisplayRiskFusion.mlFirstPhotoDecision(
    _mlAnalysisFromAnalyses(analyses),
  );
  final legacy = _combinePhotoDisplayRiskLegacy(analyses);
  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
  }
  return legacy;
}

HCVDisplayRiskResult _combinePhotoDisplayRiskLegacy(
  List<Map<String, dynamic>?> analyses,
) {
  final preCapture = HCVDisplayRiskFusion.combine(
""",
)

replace_once(
    camera,
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
    """HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final mlFirst = HCVDisplayRiskFusion.mlFirstVideoDecision(
    _mlAnalysisFromAnalyses(analyses),
  );
  final legacy = _combineVideoDisplayRiskLegacy(analyses);
  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
  }
  return legacy;
}

HCVDisplayRiskResult _combineVideoDisplayRiskLegacy(
  List<Map<String, dynamic>?> analyses,
) {
  final normalResult = HCVDisplayRiskFusion.combine(analyses);
""",
)

print('ML-first diagnostic merge adjusted')
