from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one marker, found {count}')
    p.write_text(text.replace(old, new, 1))


fusion = 'lib/hcv_display_risk_fusion.dart'
camera = 'lib/camera_page.dart'

replace_once(
    fusion,
    """  static bool _isCredibleRealityMl(\n""",
    """  static bool hasPersistentSemanticScreenAcrossVideoFrames(\n    Map<String, dynamic>? ml,\n  ) {\n    if (ml == null) return false;\n    final predictedClass = ml['predictedClass']?.toString() ?? '';\n    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;\n    final strongScreenFrameCount =\n        (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;\n    final mediumScreenFrameCount =\n        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;\n    final averageFrameScore =\n        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;\n    final maxFrameScore =\n        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;\n    final screenProbability =\n        (ml['screenProbability'] as num?)?.toDouble() ?? 0.0;\n    final confidence =\n        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;\n    final rawFrames = ml['videoFrameAnalyses'];\n    if (framesAnalyzed < 4 ||\n        rawFrames is! List ||\n        rawFrames.length != framesAnalyzed) {\n      return false;\n    }\n    final allFramesScreen = rawFrames.every(\n      (frame) =>\n          frame is Map &&\n          (frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_'),\n    );\n\n    return predictedClass.startsWith('SCREEN_') &&\n        allFramesScreen &&\n        strongScreenFrameCount >= 2 &&\n        mediumScreenFrameCount >= 3 &&\n        averageFrameScore >= 88.0 &&\n        maxFrameScore >= 94 &&\n        screenProbability >= 0.93 &&\n        confidence >= 0.85;\n  }\n\n  static bool hasPersistentSemanticRealityAcrossVideoFrames(\n    Map<String, dynamic>? ml,\n  ) {\n    if (ml == null) return false;\n    final predictedClass = ml['predictedClass']?.toString() ?? '';\n    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;\n    final strongScreenFrameCount =\n        (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;\n    final mediumScreenFrameCount =\n        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;\n    final averageFrameScore =\n        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;\n    final maxFrameScore =\n        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;\n    final screenProbability =\n        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;\n    final rawFrames = ml['videoFrameAnalyses'];\n    if (framesAnalyzed < 4 ||\n        rawFrames is! List ||\n        rawFrames.length != framesAnalyzed) {\n      return false;\n    }\n    final allFramesReality = rawFrames.every(\n      (frame) =>\n          frame is Map &&\n          (frame['predictedClass']?.toString() ?? '').startsWith('REALITY_'),\n    );\n\n    return predictedClass.startsWith('REALITY_') &&\n        allFramesReality &&\n        strongScreenFrameCount == 0 &&\n        mediumScreenFrameCount == 0 &&\n        averageFrameScore <= 20.0 &&\n        maxFrameScore <= 30 &&\n        screenProbability <= 0.30;\n  }\n\n  static bool _isCredibleRealityMl(\n""",
)

replace_once(
    fusion,
    """    final mlMultiFrameScreenConsistency = hasMultiFrameScreenConsistency(ml);\n    final mlDualRegionPhotoEvidence = hasSpatialScreenCorroboration(ml);\n    final mlPersistentCorroboratedEvidence = mlPersistentVideoEvidence ||\n        mlMultiFrameScreenConsistency ||\n        mlDualRegionPhotoEvidence;\n""",
    """    final mlMultiFrameScreenConsistency = hasMultiFrameScreenConsistency(ml);\n    final mlSemanticScreenPersistence =\n        hasPersistentSemanticScreenAcrossVideoFrames(ml);\n    final mlSemanticRealityPersistence =\n        hasPersistentSemanticRealityAcrossVideoFrames(ml);\n    final mlDualRegionPhotoEvidence = hasSpatialScreenCorroboration(ml);\n    final mlPersistentCorroboratedEvidence = mlPersistentVideoEvidence ||\n        mlMultiFrameScreenConsistency ||\n        mlSemanticScreenPersistence ||\n        mlDualRegionPhotoEvidence;\n""",
)

replace_once(
    fusion,
    """    final mlUnresolvedGeometryOverride = !reflectedRealityEvidence &&\n        geometrySceneClass == 'UNKNOWN' &&\n        (mlPersistentVideoEvidence || mlMultiFrameScreenConsistency);\n    final mlPlanarGeometryOverride = !reflectedRealityEvidence &&\n        geometrySceneClass == 'PLANAR' &&\n        (mlPersistentVideoEvidence || mlMultiFrameScreenConsistency);\n""",
    """    final mlUnresolvedGeometryOverride = !reflectedRealityEvidence &&\n        geometrySceneClass == 'UNKNOWN' &&\n        (mlPersistentVideoEvidence ||\n            mlMultiFrameScreenConsistency ||\n            mlSemanticScreenPersistence);\n    final mlPlanarGeometryOverride = !reflectedRealityEvidence &&\n        geometrySceneClass == 'PLANAR' &&\n        (mlPersistentVideoEvidence ||\n            mlMultiFrameScreenConsistency ||\n            mlSemanticScreenPersistence);\n""",
)

replace_once(
    fusion,
    """    final geometryRealityWithIndependentNonDisplay =\n        geometrySceneClass == 'REALITY' &&\n            weakScreenAcrossVideoFrames &&\n            !passiveStructuralEvidence &&\n            !passiveStrong &&\n            !passiveModerate;\n""",
    """    final semanticMultiFrameRealityWithoutDisplayCorroboration =\n        !liveCaptureOnly &&\n            mlSemanticRealityPersistence &&\n            !rawActiveDisplayEvidence &&\n            !activeDisplayEvidence &&\n            liveSignals['confirmedDisplayTrace'] != true &&\n            liveSignals['periodicLightTrace'] != true &&\n            !passiveStructuralEvidence &&\n            !passiveStrong &&\n            !passiveModerate &&\n            !mlStrong;\n    final geometryRealityWithIndependentNonDisplay =\n        geometrySceneClass == 'REALITY' &&\n            weakScreenAcrossVideoFrames &&\n            !passiveStructuralEvidence &&\n            !passiveStrong &&\n            !passiveModerate;\n""",
)

replace_once(
    fusion,
    """      if (mlMultiFrameScreenConsistency) {\n        reasons.add('ML_SCREEN_MULTI_FRAME_CONSISTENCY_CONFIRMED');\n      }\n      if (mlDualRegionPhotoEvidence) {\n""",
    """      if (mlMultiFrameScreenConsistency) {\n        reasons.add('ML_SCREEN_MULTI_FRAME_CONSISTENCY_CONFIRMED');\n      }\n      if (mlSemanticScreenPersistence) {\n        reasons.add('ML_SCREEN_ALL_FRAME_SEMANTIC_PERSISTENCE_CONFIRMED');\n      }\n      if (mlDualRegionPhotoEvidence) {\n""",
)

replace_once(
    fusion,
    """    } else if (geometryRealityWithIndependentNonDisplay) {\n""",
    """    } else if (semanticMultiFrameRealityWithoutDisplayCorroboration) {\n      decision = 'NO_DISPLAY_EVIDENCE';\n      score = min(rawScore, 20);\n      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');\n      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');\n      reasons.remove('ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED');\n      reasons.add(\n        'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',\n      );\n    } else if (geometryRealityWithIndependentNonDisplay) {\n""",
)

replace_once(
    camera,
    """          normalResult.reasons.contains(\n            'MULTI_FRAME_REALITY_RESOLVES_UNCORROBORATED_TEMPORAL_SIGNAL',\n          ));\n""",
    """          normalResult.reasons.contains(\n            'MULTI_FRAME_REALITY_RESOLVES_UNCORROBORATED_TEMPORAL_SIGNAL',\n          ) ||\n          normalResult.reasons.contains(\n            'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',\n          ));\n""",
)

print('materialized build71 video semantic persistence patch')
