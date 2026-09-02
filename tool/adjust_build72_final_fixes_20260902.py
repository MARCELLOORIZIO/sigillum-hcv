from pathlib import Path

path = Path('lib/hcv_display_risk_fusion.dart')
text = path.read_text()
old = """    final semanticMultiFrameRealityWithoutDisplayCorroboration =
        !liveCaptureOnly &&
            mlSemanticRealityPersistence &&
            !liveTemporal &&
            !activeTemporalPhysicalProof &&
            !planarTemporalPhysicalProof &&
            !activePlanarTemporal &&
            liveSignals['confirmedDisplayTrace'] != true &&
            liveSignals['periodicLightTrace'] != true &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate &&
            !mlStrong;
"""
new = """    final activeOnlyCanBeOverriddenBySemanticReality =
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
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one semantic REALITY block, found {count}')
path.write_text(text.replace(old, new, 1))
print('build72 semantic REALITY guard refined')
