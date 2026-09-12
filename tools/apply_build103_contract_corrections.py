from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'missing expected text in {path}: {old[:160]!r}')
    if text.count(old) != 1:
        raise SystemExit(f'expected exactly one match in {path}, got {text.count(old)}')
    p.write_text(text.replace(old, new, 1))


# Preserve already-promoted strong results exactly. In production the strict
# HFR promotion runs before the dual-evidence resolver, so this avoids
# rewriting an already-final strong result or its evidence provenance.
replace_once(
    'lib/hcv_display_risk_fusion.dart',
    """  }) {\n    final dualEvidence = _resolveDualEvidenceV1(\n""",
    """  }) {\n    if (base.decision == 'STRONG_DISPLAY_RISK') return base;\n\n    final dualEvidence = _resolveDualEvidenceV1(\n""",
)

# The active architecture intentionally promotes a previously unresolved base
# when strict coherent HFR evidence is supplied directly to this resolver.
weak = Path('test/weak_semantic_no_physical_resolution_test.dart')
text = weak.read_text()
old = """  test('positive coherent HFR can never be downgraded', () {\n    final base = unresolved();\n    final hfr = negativeHfr()..['coherentDisplayPeriodicity'] = true;\n    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(\n      base: base,\n      passiveOptical: cleanOptical(),\n      ml: ml(\n        frames: 2,\n        predictedClass: 'REALITY_OUTDOOR',\n        p: 0.01,\n        confidence: 0.90,\n        score: 1,\n        average: 1.0,\n        maxFrame: 1,\n      ),\n      temporalFrequencyProbe: hfr,\n    );\n    expect(identical(result, base), isTrue);\n  });\n"""
new = """  test('positive coherent HFR actively resolves unresolved base as display', () {\n    final base = unresolved();\n    final hfr = negativeHfr()..['coherentDisplayPeriodicity'] = true;\n    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(\n      base: base,\n      passiveOptical: cleanOptical(),\n      ml: ml(\n        frames: 2,\n        predictedClass: 'REALITY_OUTDOOR',\n        p: 0.01,\n        confidence: 0.90,\n        score: 1,\n        average: 1.0,\n        maxFrame: 1,\n      ),\n      temporalFrequencyProbe: hfr,\n    );\n    expect(result.decision, 'STRONG_DISPLAY_RISK');\n    expect(\n      result.reasons,\n      contains('DUAL_EVIDENCE_STRICT_COHERENT_DISPLAY_PHYSICS'),\n    );\n  });\n"""
if old not in text or text.count(old) != 1:
    raise SystemExit('unable to locate positive HFR regression test')
weak.write_text(text.replace(old, new, 1))

# Update the two pre-existing source-contract tests to the intentionally
# shortened Photo Temporal contract. Generic video sampling remains unchanged.
replace_once(
    'test/video_native_capture_writer_stability_contract_test.dart',
    "contains('Duration(milliseconds: 2400)')",
    "contains('Duration(milliseconds: 1500)')",
)
replace_once(
    'test/video_native_capture_writer_stability_contract_test.dart',
    "contains('static const int photoMlFrameLimit = 4')",
    "contains('static const int photoMlFrameLimit = 3')",
)

replace_once(
    'test/photo_temporal_four_frame_sampling_contract_test.dart',
    "test('photo Temporal V2 captures 2.4s and requests four 0.6s ML samples'",
    "test('photo Temporal V2 captures 1.5s and requests three 0.6s ML samples'",
)
replace_once(
    'test/photo_temporal_four_frame_sampling_contract_test.dart',
    "'static const Duration defaultDuration = Duration(milliseconds: 2400)'",
    "'static const Duration defaultDuration = Duration(milliseconds: 1500)'",
)
replace_once(
    'test/photo_temporal_four_frame_sampling_contract_test.dart',
    "contains('static const int photoMlFrameLimit = 4')",
    "contains('static const int photoMlFrameLimit = 3')",
)

print('BUILD103 contract corrections applied')
