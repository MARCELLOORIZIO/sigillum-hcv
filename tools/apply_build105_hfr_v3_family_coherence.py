from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch anchor: {label}')
    if text.count(old) != 1:
        raise SystemExit(f'non-unique patch anchor: {label} count={text.count(old)}')
    return text.replace(old, new, 1)


probe_path = Path('lib/hcv_temporal_frequency_probe.dart')
probe = probe_path.read_text()

probe = replace_once(
    probe,
    """    final allNineCellsSameDisplayFamily =\n        displayLikeCellCount == 9 &&\n        spatialFamilyCellCount == 9 &&\n        rowTimeFamilyCellCount == 9;\n    final fullFrameDisplayV3 = qualifiesFullFrameDisplayV3(\n      legacyHfrCandidate: legacyHfrCandidate,\n      displayLikeCellCount: displayLikeCellCount,\n      spatialFamilyCellCount: spatialFamilyCellCount,\n      rowTimeFamilyCellCount: rowTimeFamilyCellCount,\n      medianRowTimeCoherence: medianRowTimeCoherence,\n    );\n    final mixedSceneDetected =\n        displayLikeCellCount > 0 && !allNineCellsSameDisplayFamily;\n""",
    """    // BUILD105: all nine cells must belong to one physical frequency\n    // family, but individual cells are allowed to be locally weaker because\n    // content, glare and perspective can depress periodicity/phase metrics.\n    // The unchanged strict legacy HFR gate still supplies the global physical\n    // proof, while 9/9 spatial + row-time family coherence proves full-frame\n    // coverage. This is deliberately not a relaxation of the HFR thresholds.\n    final allNineCellsSameDisplayFamily =\n        legacyHfrCandidate &&\n        spatialFamilyCellCount == 9 &&\n        rowTimeFamilyCellCount == 9 &&\n        medianRowTimeCoherence >= 0.20;\n    final fullFrameDisplayV3 = qualifiesFullFrameDisplayV3(\n      legacyHfrCandidate: legacyHfrCandidate,\n      spatialFamilyCellCount: spatialFamilyCellCount,\n      rowTimeFamilyCellCount: rowTimeFamilyCellCount,\n      medianRowTimeCoherence: medianRowTimeCoherence,\n    );\n    final mixedSceneDetected =\n        displayLikeCellCount > 0 && !fullFrameDisplayV3;\n""",
    'V3 family decision',
)

probe = replace_once(
    probe,
    """  static bool qualifiesFullFrameDisplayV3({\n    required bool legacyHfrCandidate,\n    required int displayLikeCellCount,\n    required int spatialFamilyCellCount,\n    required int rowTimeFamilyCellCount,\n    required double medianRowTimeCoherence,\n  }) {\n    return legacyHfrCandidate &&\n        displayLikeCellCount == 9 &&\n        spatialFamilyCellCount == 9 &&\n        rowTimeFamilyCellCount == 9 &&\n        medianRowTimeCoherence >= 0.20;\n  }\n""",
    """  static bool qualifiesFullFrameDisplayV3({\n    required bool legacyHfrCandidate,\n    required int spatialFamilyCellCount,\n    required int rowTimeFamilyCellCount,\n    required double medianRowTimeCoherence,\n  }) {\n    return legacyHfrCandidate &&\n        spatialFamilyCellCount == 9 &&\n        rowTimeFamilyCellCount == 9 &&\n        medianRowTimeCoherence >= 0.20;\n  }\n""",
    'qualifiesFullFrameDisplayV3',
)

probe = replace_once(
    probe,
    """        'classificationPolicy':\n            'ALL_9_CELLS_ONE_DISPLAY_FAMILY_ELSE_PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE',\n""",
    """        'classificationPolicy':\n            'STRICT_GLOBAL_HFR_PLUS_ALL_9_CELLS_ONE_FREQUENCY_FAMILY;_LOCAL_WEAK_CELLS_ALLOWED;PARTIAL_DISPLAY_IS_REAL_MIXED_SCENE',\n""",
    'classification policy',
)

probe = replace_once(
    probe,
    """      'note': 'V3 combines native 240/120 fps timing, 3x3 row-profile rolling-shutter band evolution, row-by-time temporal coherence and strict all-nine-cell spatial consistency. Partial display-like coverage is classified as a mixed real scene.',\n""",
    """      'note': 'V3 BUILD105 combines native 240/120 fps timing, strict global HFR evidence, 3x3 row-profile rolling-shutter band evolution and row-by-time coherence. Full-frame display requires all nine cells in one spatial and row-time frequency family, while locally weaker cells are tolerated. Partial display coverage remains a mixed real scene.',\n""",
    'V3 note',
)

probe_path.write_text(probe)

fusion_path = Path('lib/hcv_display_risk_fusion.dart')
fusion = fusion_path.read_text()

fusion = replace_once(
    fusion,
    """      return v3?['fullFrameDisplay'] == true &&\n          v3?['mixedSceneDetected'] != true &&\n          (v3?['displayLikeCellCount'] as num?)?.toInt() == 9 &&\n          (v3?['spatialFamilyCellCount'] as num?)?.toInt() == 9 &&\n          (v3?['rowTimeFamilyCellCount'] as num?)?.toInt() == 9;\n""",
    """      return v3?['fullFrameDisplay'] == true &&\n          v3?['mixedSceneDetected'] != true &&\n          v3?['allNineCellsSameDisplayFamily'] == true &&\n          (v3?['spatialFamilyCellCount'] as num?)?.toInt() == 9 &&\n          (v3?['rowTimeFamilyCellCount'] as num?)?.toInt() == 9;\n""",
    'fusion V3 strict positive gate',
)

fusion_path.write_text(fusion)


test_path = Path('test/hfr_v3_fullframe_mixed_scene_test.dart')
test = test_path.read_text()

test = replace_once(
    test,
    """Map<String, dynamic> v3Probe({\n  required bool fullFrameDisplay,\n  required bool fullFrameReality,\n  required bool mixed,\n  int displayCells = 0,\n  int spatialFamilyCells = 0,\n  int rowTimeFamilyCells = 0,\n}) =>\n""",
    """Map<String, dynamic> v3Probe({\n  required bool fullFrameDisplay,\n  required bool fullFrameReality,\n  required bool mixed,\n  int displayCells = 0,\n  int spatialFamilyCells = 0,\n  int rowTimeFamilyCells = 0,\n  bool? allNineSameFamily,\n}) =>\n""",
    'test probe signature',
)

test = replace_once(
    test,
    """        'mixedSceneDetected': mixed,\n        'displayLikeCellCount': displayCells,\n        'spatialFamilyCellCount': spatialFamilyCells,\n        'rowTimeFamilyCellCount': rowTimeFamilyCells,\n""",
    """        'mixedSceneDetected': mixed,\n        'allNineCellsSameDisplayFamily':\n            allNineSameFamily ??\n                (fullFrameDisplay &&\n                    spatialFamilyCells == 9 &&\n                    rowTimeFamilyCells == 9),\n        'displayLikeCellCount': displayCells,\n        'spatialFamilyCellCount': spatialFamilyCells,\n        'rowTimeFamilyCellCount': rowTimeFamilyCells,\n""",
    'test probe evidence',
)

test = replace_once(
    test,
    """  test('V3 full-frame display requires all nine cells in one family', () {\n    expect(\n      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(\n        legacyHfrCandidate: true,\n        displayLikeCellCount: 9,\n        spatialFamilyCellCount: 9,\n        rowTimeFamilyCellCount: 9,\n        medianRowTimeCoherence: 0.50,\n      ),\n      isTrue,\n    );\n    expect(\n      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(\n        legacyHfrCandidate: true,\n        displayLikeCellCount: 8,\n        spatialFamilyCellCount: 8,\n        rowTimeFamilyCellCount: 8,\n        medianRowTimeCoherence: 0.50,\n      ),\n      isFalse,\n    );\n  });\n""",
    """  test('V3 full-frame display requires all nine cells in one physical family', () {\n    expect(\n      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(\n        legacyHfrCandidate: true,\n        spatialFamilyCellCount: 9,\n        rowTimeFamilyCellCount: 9,\n        medianRowTimeCoherence: 0.50,\n      ),\n      isTrue,\n    );\n    expect(\n      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(\n        legacyHfrCandidate: true,\n        spatialFamilyCellCount: 9,\n        rowTimeFamilyCellCount: 8,\n        medianRowTimeCoherence: 0.50,\n      ),\n      isFalse,\n    );\n    expect(\n      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(\n        legacyHfrCandidate: false,\n        spatialFamilyCellCount: 9,\n        rowTimeFamilyCellCount: 9,\n        medianRowTimeCoherence: 0.80,\n      ),\n      isFalse,\n    );\n  });\n\n  test('BUILD104 full-frame display photo survives two locally weak cells', () {\n    expect(\n      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(\n        legacyHfrCandidate: true,\n        spatialFamilyCellCount: 9,\n        rowTimeFamilyCellCount: 9,\n        medianRowTimeCoherence: 0.786861,\n      ),\n      isTrue,\n    );\n  });\n\n  test('BUILD104 full-frame display video survives one locally weak cell', () {\n    expect(\n      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(\n        legacyHfrCandidate: true,\n        spatialFamilyCellCount: 9,\n        rowTimeFamilyCellCount: 9,\n        medianRowTimeCoherence: 0.800272,\n      ),\n      isTrue,\n    );\n  });\n\n  test('BUILD104 TV inside room does not become full-frame display', () {\n    expect(\n      HCVTemporalFrequencyProbe.qualifiesFullFrameDisplayV3(\n        legacyHfrCandidate: false,\n        spatialFamilyCellCount: 9,\n        rowTimeFamilyCellCount: 7,\n        medianRowTimeCoherence: 0.378844,\n      ),\n      isFalse,\n    );\n  });\n""",
    'full-frame tests',
)

insert_before = """  test('row-by-time matrix exposes coherent temporal rhythm', () {\n"""
new_test = """  test('fusion accepts BUILD104 recovered full-frame family with 7 local display cells', () {\n    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(\n      base: unresolvedV3(),\n      passiveOptical: opticalCleanV3(),\n      ml: temporalV3(<double>[0.10, 0.12, 0.11]),\n      temporalFrequencyProbe: v3Probe(\n        fullFrameDisplay: true,\n        fullFrameReality: false,\n        mixed: false,\n        displayCells: 7,\n        spatialFamilyCells: 9,\n        rowTimeFamilyCells: 9,\n        allNineSameFamily: true,\n      ),\n    );\n    expect(result.decision, 'STRONG_DISPLAY_RISK');\n    expect(\n      result.reasons,\n      contains('HFR_V3_ALL_NINE_CELLS_ONE_DISPLAY_FAMILY'),\n    );\n  });\n\n"""
if insert_before not in test:
    raise SystemExit('missing insert point for recovered family test')
test = test.replace(insert_before, new_test + insert_before, 1)

test_path.write_text(test)

print('BUILD105 HFR V3 family-coherence patch applied')
