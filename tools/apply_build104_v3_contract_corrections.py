from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# 1) Complete V3 mixed-scene policy: repeated screen presence is not enough.
#    If ML repeatedly sees a screen but the evidence is not full-frame and V3
#    does not physically validate a full-frame display, the acquisition is a
#    real mixed scene. This branch intentionally runs before inherited STRONG
#    ML results can survive.
# ---------------------------------------------------------------------------
fusion_path = Path('lib/hcv_display_risk_fusion.dart')
fusion = fusion_path.read_text()

fusion = replace_once(
    fusion,
    """    final temporalFrames = _temporalFrameCount(temporalMl);\n    final highFullFrameScreenFrames =\n        _temporalHighFullFrameScreenFrameCount(temporalMl);\n    final mixedScene = _isV3MixedRealScene(temporalFrequencyProbe);\n""",
    """    final temporalFrames = _temporalFrameCount(temporalMl);\n    final highAnyScreenFrames =\n        _temporalHighAnyScreenFrameCount(temporalMl);\n    final highFullFrameScreenFrames =\n        _temporalHighFullFrameScreenFrameCount(temporalMl);\n    final mixedScene = _isV3MixedRealScene(temporalFrequencyProbe);\n    final v3Analyzed =\n        temporalFrequencyProbe?['type'] ==\n                'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3' &&\n            temporalFrequencyProbe?['analysisStatus'] == 'ANALYZED';\n""",
    'dual V3 temporal counts',
)

fusion = replace_once(
    fusion,
    """    final physicalDisplay =\n        _isCompleteStrictPositiveHfr(temporalFrequencyProbe);\n    final persistentVisualDisplay =\n        temporalFrames >= 2 && highFullFrameScreenFrames >= 2;\n\n    if (physicalDisplay || persistentVisualDisplay) {\n""",
    """    final physicalDisplay =\n        _isCompleteStrictPositiveHfr(temporalFrequencyProbe);\n\n    final screenPresentButNotFullFrame =\n        v3Analyzed &&\n        !physicalDisplay &&\n        temporalFrames >= 2 &&\n        highAnyScreenFrames >= 2 &&\n        highFullFrameScreenFrames == 0;\n    if (screenPresentButNotFullFrame) {\n      final reasons = base.reasons\n          .where(\n            (reason) =>\n                reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&\n                reason != 'LIVE_PROBE_MISSING',\n          )\n          .toList()\n        ..add('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE')\n        ..add('DISPLAY_PRESENCE_IS_NOT_DISPLAY_CAPTURE')\n        ..add('DUAL_EVIDENCE_V3_ACTIVE');\n      return HCVDisplayRiskResult(\n        risk: 'LOW',\n        score: min(base.score, 20),\n        decision: 'NO_DISPLAY_EVIDENCE',\n        analysisStatus: 'COMPLETE',\n        evidenceSources: base.evidenceSources\n            .where((source) => !source.contains('SCREEN'))\n            .toList(),\n        strongSources: const <String>[],\n        reasons: reasons,\n      );\n    }\n\n    final persistentVisualDisplay =\n        temporalFrames >= 2 && highFullFrameScreenFrames >= 2;\n\n    if (physicalDisplay || persistentVisualDisplay) {\n""",
    'screen present not full frame veto',
)

fusion = replace_once(
    fusion,
    """  static int _temporalHighFullFrameScreenFrameCount(\n    Map<String, dynamic>? ml,\n  ) {\n""",
    """  static int _temporalHighAnyScreenFrameCount(Map<String, dynamic>? ml) {\n    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return 0;\n    final rawFrames = ml['videoFrameAnalyses'];\n    if (rawFrames is! List) return 0;\n    var count = 0;\n    for (final rawFrame in rawFrames) {\n      if (rawFrame is! Map) continue;\n      final probability =\n          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;\n      if (probability >= 0.90) count++;\n    }\n    return count;\n  }\n\n  static int _temporalHighFullFrameScreenFrameCount(\n    Map<String, dynamic>? ml,\n  ) {\n""",
    'any-screen helper',
)

fusion_path.write_text(fusion)


# ---------------------------------------------------------------------------
# 2) Update V2-era contract assertions that intentionally changed in V3.
# ---------------------------------------------------------------------------
role_old = 'DECISIONAL_ONLY_FOR_STRICT_HFR_COHERENT_DISPLAY_PERIODICITY'
role_new = 'DECISIONAL_DISPLAY_REALITY_V3_FULL_FRAME_OR_MIXED_SCENE'

for filename in [
    'test/frequency_probe_session_safety_contract_test.dart',
    'test/temporal_frequency_probe_contract_test.dart',
]:
    path = Path(filename)
    text = path.read_text()
    if role_old not in text:
        raise SystemExit(f'{filename}: old decision role not found')
    text = text.replace(role_old, role_new)
    path.write_text(text)

# BUILD103 test remains useful as a compatibility corpus, but its expected
# reason tags now point to the V3 decision vocabulary.
dual_path = Path('test/dual_display_reality_evidence_v1_test.dart')
dual = dual_path.read_text()
dual_reasons = {
    'DUAL_EVIDENCE_STRICT_COHERENT_DISPLAY_PHYSICS':
        'HFR_V3_ALL_NINE_CELLS_ONE_DISPLAY_FAMILY',
    'DUAL_EVIDENCE_TWO_HIGH_SCREEN_TEMPORAL_SAMPLES':
        'TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES',
    'DUAL_EVIDENCE_STRICT_PHYSICAL_REALITY_SIGNATURE':
        'HFR_V3_FULL_FRAME_REALITY_SIGNATURE',
}
for old, new in dual_reasons.items():
    if old not in dual:
        raise SystemExit(f'dual test: missing old reason {old}')
    dual = dual.replace(old, new)
dual_path.write_text(dual)

weak_path = Path('test/weak_semantic_no_physical_resolution_test.dart')
weak = weak_path.read_text()
old_reason = 'DUAL_EVIDENCE_STRICT_COHERENT_DISPLAY_PHYSICS'
new_reason = 'HFR_V3_ALL_NINE_CELLS_ONE_DISPLAY_FAMILY'
if old_reason not in weak:
    raise SystemExit('weak semantic test: old positive HFR reason not found')
weak = weak.replace(old_reason, new_reason)
weak_path.write_text(weak)


# ---------------------------------------------------------------------------
# 3) Regression test: inherited strong semantic SCREEN cannot override a V3
#    real-scene determination when screen presence is not full-frame.
# ---------------------------------------------------------------------------
v3_path = Path('test/hfr_v3_fullframe_mixed_scene_test.dart')
v3 = v3_path.read_text()
anchor = """  test('screen presence without full-frame support cannot promote a real room', () {\n    final base = unresolvedV3();\n"""
if anchor not in v3:
    raise SystemExit('V3 test insertion anchor not found')
new_test = """  test('inherited strong screen ML is vetoed when screen is not full-frame', () {\n    final strongBase = const HCVDisplayRiskResult(\n      risk: 'HIGH',\n      score: 98,\n      decision: 'STRONG_DISPLAY_RISK',\n      analysisStatus: 'COMPLETE',\n      evidenceSources: <String>['ML_SCREEN'],\n      strongSources: <String>['ML_SCREEN'],\n      reasons: <String>['ML_SCREEN_STRONG'],\n    );\n    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(\n      base: strongBase,\n      passiveOptical: opticalCleanV3(),\n      ml: temporalV3(\n        <double>[0.98, 0.97, 0.96],\n        fullFrame: 62,\n        content: 93,\n      ),\n      temporalFrequencyProbe: v3Probe(\n        fullFrameDisplay: false,\n        fullFrameReality: false,\n        mixed: false,\n      ),\n    );\n    expect(result.decision, 'NO_DISPLAY_EVIDENCE');\n    expect(\n      result.reasons,\n      contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'),\n    );\n  });\n\n"""
v3 = v3.replace(anchor, new_test + anchor, 1)
v3_path.write_text(v3)

print('BUILD104 V3 contract corrections applied')
