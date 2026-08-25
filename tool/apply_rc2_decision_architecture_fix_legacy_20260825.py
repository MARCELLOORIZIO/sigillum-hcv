from pathlib import Path
import re


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    if new in source:
        print(f'{label}: already applied')
        return
    if source.count(old) != 1:
        raise RuntimeError(f'{label}: unexpected source state (old={source.count(old)}, new={source.count(new)})')
    file.write_text(source.replace(old, new, 1), encoding='utf-8')
    print(f'{label}: applied')


def replace_region(path: str, start_marker: str, end_marker: str, region: str, required: list[str], label: str) -> None:
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    start_count = source.count(start_marker)
    end_count = source.count(end_marker)
    if start_count != 1 or end_count != 1:
        raise RuntimeError(f'{label}: semantic markers not unique (start={start_count}, end={end_count})')
    start = source.index(start_marker)
    line_start = source.rfind('\n', 0, start) + 1
    end = source.index(end_marker, start)
    current = source[line_start:end]
    if all(token in current for token in required):
        print(f'{label}: already applied')
        return
    file.write_text(source[:line_start] + region + source[end:], encoding='utf-8')
    print(f'{label}: applied')


# 1) Capture gate: movement alone is not parallax. Allow capture only when the
# geometry classifier would resolve the probe as REALITY or PLANAR; UNKNOWN
# stays blocked and the red movement instruction remains visible.
camera = Path('lib/camera_page.dart')
camera_source = camera.read_text(encoding='utf-8')
pattern = re.compile(
    r"  bool _hasRequiredParallax\(Map<String, dynamic> probe\) \{.*?^  \}\n\n",
    re.MULTILINE | re.DOTALL,
)
new_helper = """  bool _hasRequiredParallax(Map<String, dynamic> probe) {
    final geometry = probe['geometryChallenge'];
    if (geometry is! Map) return false;

    final matchedRegions = (geometry['matchedRegions'] as num?)?.toInt() ?? 0;
    final motionMagnitude =
        (geometry['motionMagnitude'] as num?)?.toDouble() ?? 0.0;
    final flowReliability =
        (geometry['flowReliability'] as num?)?.toDouble() ?? 0.0;
    final directionCoherence =
        (geometry['directionCoherence'] as num?)?.toDouble() ?? 0.0;
    final depthDispersion =
        (geometry['depthDispersion'] as num?)?.toDouble() ?? 0.0;
    final planarCoherence =
        (geometry['planarCoherence'] as num?)?.toDouble() ?? 0.0;

    final observable = matchedRegions >= 5 &&
        motionMagnitude >= 0.16 &&
        flowReliability >= 0.46;
    if (!observable) return false;

    final realityGeometry = depthDispersion >= 0.28 &&
        directionCoherence >= 0.38 &&
        planarCoherence <= 0.68;
    final planarGeometry = depthDispersion <= 0.20 &&
        directionCoherence >= 0.72 &&
        planarCoherence >= 0.70;

    return realityGeometry || planarGeometry;
  }

"""
if 'final realityGeometry = depthDispersion >= 0.28' not in camera_source:
    camera_source, count = pattern.subn(new_helper, camera_source, count=1)
    if count != 1:
        raise RuntimeError('camera geometry-observable gate anchor missing')
    camera.write_text(camera_source, encoding='utf-8')
    print('camera geometry-observable gate: applied')
else:
    print('camera geometry-observable gate: already applied')


# 2) Scene fusion must trust the geometry classifier as the single authority.
# Do not reclassify REALITY with a second, slightly different threshold set.
replace_once(
    'lib/hcv_scene_decision_fusion.dart',
    "    final strongGeometryReality = geometry.realityEvidence &&\n        geometry.flowReliability >= 0.58 &&\n        geometry.depthDispersion >= 0.34;\n",
    "    final strongGeometryReality = geometry.realityEvidence;\n",
    'single geometry reality authority',
)


# 3) Passive optical evidence: a raw score or generic strongDisplayTrace alone
# must never count as an independent structural display family.
replace_once(
    'lib/hcv_display_risk_fusion.dart',
    "      final structural = signals['structuralDisplayTrace'] == true ||\n          signals['strongDisplayTrace'] == true ||\n          signals['confirmedDisplayTrace'] == true;\n",
    "      final structural = signals['structuralDisplayTrace'] == true ||\n          signals['confirmedDisplayTrace'] == true;\n",
    'strict passive structural evidence',
)
replace_once(
    'lib/hcv_display_risk_fusion.dart',
    "      if (!reflectedRealityEvidence &&\n          ((score >= 45 && structural) || score >= 70)) {\n        passiveModerate = true;\n      }\n",
    "      if (!reflectedRealityEvidence && score >= 45 && structural) {\n        passiveModerate = true;\n      }\n",
    'remove passive score-only evidence',
)


# 4) Final fusion by independent families. HIGH requires two independent strong
# display families. Strong ML REALITY is counter-evidence, never sole proof.
fusion_region = """    final mlScore = (ml?['screenReplayRiskScore'] as num?)?.toInt();
    final mlClass = ml?['predictedClass']?.toString() ?? '';
    final mlConfidence = (ml?['predictedClassConfidence'] as num?)?.toDouble();
    final mlSaysScreen = mlScore != null && mlClass.startsWith('SCREEN_');
    final mlSaysReality = mlScore != null && mlClass.startsWith('REALITY_');
    final mlStrong = mlSaysScreen &&
        mlScore >= 92 &&
        (mlConfidence == null || mlConfidence >= 0.78);
    final mlModerate = mlStrong ||
        (!reflectedRealityEvidence &&
            mlSaysScreen &&
            mlScore >= 88 &&
            (mlConfidence == null || mlConfidence >= 0.70));
    final mlRealityStrong = mlSaysReality &&
        (mlConfidence ?? 0.0) >= 0.90 &&
        mlScore <= 2;

    if (mlModerate) evidenceSources.add('ML_SCREEN_CLASS');
    if (mlStrong) {
      strongSources.add('ML_SCREEN_CLASS');
      reasons.add('ML_SCREEN_HIGH_CONFIDENCE');
      if (reflectedRealityEvidence) {
        reasons.add('ML_SCREEN_AND_REFLECTED_REALITY_CONFLICT');
      }
    } else if (mlModerate) {
      reasons.add('ML_SCREEN_MODERATE_CONFIDENCE');
    }
    if (mlRealityStrong) {
      reasons.add('ML_REALITY_HIGH_CONFIDENCE');
    }

    final liveGeometryRaw = live?['geometryChallenge'];
    final liveGeometry = liveGeometryRaw is Map
        ? liveGeometryRaw
        : const <String, dynamic>{};
    final geometrySceneClass =
        liveGeometry['sceneClass']?.toString() ?? 'UNKNOWN';
    final geometryReality =
        reflectedRealityEvidence || geometrySceneClass == 'REALITY';
    final geometryPlanar = geometrySceneClass == 'PLANAR';

    final strongDisplayFamilies = <String>{};
    if (liveTemporal) strongDisplayFamilies.add('LIVE_TEMPORAL');
    if (activeDisplayEvidence) {
      strongDisplayFamilies.add('ACTIVE_ILLUMINATION');
    }
    if (passiveStrong) strongDisplayFamilies.add('STATIC_OPTICAL');
    if (mlStrong) strongDisplayFamilies.add('ML_SCREEN_CLASS');

    final hasIndependentCorroboration = strongDisplayFamilies.length >= 2;
    final hasAnyEvidence = evidenceSources.isNotEmpty;
    final liveNotAnalyzed = live == null ||
        liveScore == null ||
        live?['analysisStatus'] == 'NOT_ANALYZED';

    late final String decision;
    late final int score;
    if (hasIndependentCorroboration) {
      decision = 'STRONG_DISPLAY_RISK';
      score = max(rawScore, 70).clamp(70, 100).toInt();
    } else if (mlStrong && geometryReality) {
      decision = 'NON_CONCLUSIVE';
      score = 45;
      reasons.add('ML_GEOMETRY_CONFLICT');
    } else if (mlRealityStrong) {
      if (geometryReality) {
        decision = 'NO_DISPLAY_EVIDENCE';
        score = min(rawScore, 20);
        reasons.add('ML_REALITY_AND_GEOMETRY_AGREE');
      } else if (geometryPlanar || hasAnyEvidence) {
        decision = 'NON_CONCLUSIVE';
        score = 45;
        reasons.add('ML_REALITY_REQUIRES_INDEPENDENT_CORROBORATION');
      } else if (liveNotAnalyzed || activeChallengeIndeterminate) {
        decision = 'NON_CONCLUSIVE';
        score = 45;
        reasons.add('DISPLAY_CLASSIFICATION_NOT_RESOLVED');
      } else {
        decision = 'NO_DISPLAY_EVIDENCE';
        score = min(rawScore, 20);
        reasons.add('ML_REALITY_UNOPPOSED');
      }
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

"""
replace_region(
    'lib/hcv_display_risk_fusion.dart',
    'final mlScore =',
    'final missingReasons =',
    fusion_region,
    [
        "final mlSaysReality =",
        "final mlRealityStrong =",
        "final strongDisplayFamilies = <String>{};",
        "strongDisplayFamilies.length >= 2",
        "reasons.add('ML_GEOMETRY_CONFLICT')",
        "reasons.add('ML_REALITY_AND_GEOMETRY_AGREE')",
    ],
    'independent-family display fusion',
)


# 5) Correct platform metadata in newly produced certificates.
replace_once(
    'lib/hcv_engine.dart',
    '    "device": "android",\n',
    '    "device": Platform.isIOS\n        ? "ios"\n        : Platform.isAndroid\n            ? "android"\n            : Platform.operatingSystem,\n',
    'runtime certificate device metadata',
)


# 6) Update the legacy scene-fusion regression to the single-authority rule.
scene_test = Path('test/hcv_scene_decision_fusion_test.dart')
scene_source = scene_test.read_text(encoding='utf-8')
old_test = """    test('weak parallax conflicting with display cues stays non-conclusive', () {
      final result = HCVSceneDecisionFusion.fuse(
        illumination: _displayLikeIllumination(),
        geometry: _geometry(
          sceneClass: 'REALITY',
          reality: true,
          motion: 0.25,
          reliability: 0.50,
          direction: 0.55,
          dispersion: 0.30,
          planar: 0.50,
        ),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.sceneClass, 'UNKNOWN');
      expect(result.reasons,
          contains('ILLUMINATION_AND_GEOMETRY_EVIDENCE_CONFLICT'));
    });
"""
new_test = """    test('geometry classifier is the single REALITY authority', () {
      final result = HCVSceneDecisionFusion.fuse(
        illumination: _displayLikeIllumination(),
        geometry: _geometry(
          sceneClass: 'REALITY',
          reality: true,
          motion: 0.25,
          reliability: 0.50,
          direction: 0.55,
          dispersion: 0.30,
          planar: 0.50,
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.sceneClass, 'REALITY');
      expect(result.realityEvidence, isTrue);
    });
"""
if new_test not in scene_source:
    if scene_source.count(old_test) != 1:
        raise RuntimeError('scene fusion legacy threshold test anchor missing')
    scene_test.write_text(scene_source.replace(old_test, new_test, 1), encoding='utf-8')
    print('scene fusion single-authority regression: applied')
else:
    print('scene fusion single-authority regression: already applied')


# Exact-source assertions.
for path, tokens in {
    'lib/camera_page.dart': [
        'final realityGeometry = depthDispersion >= 0.28',
        'final planarGeometry = depthDispersion <= 0.20',
        'return realityGeometry || planarGeometry;',
    ],
    'lib/hcv_scene_decision_fusion.dart': [
        'final strongGeometryReality = geometry.realityEvidence;',
    ],
    'lib/hcv_display_risk_fusion.dart': [
        "final mlRealityStrong =",
        "final strongDisplayFamilies = <String>{};",
        "strongDisplayFamilies.length >= 2",
        "reasons.add('ML_GEOMETRY_CONFLICT')",
        "reasons.add('ML_REALITY_AND_GEOMETRY_AGREE')",
    ],
    'lib/hcv_engine.dart': [
        '"device": Platform.isIOS',
        '? "ios"',
        ': Platform.operatingSystem',
    ],
}.items():
    source = Path(path).read_text(encoding='utf-8')
    for token in tokens:
        if token not in source:
            raise RuntimeError(f'RC2 decision architecture token missing in {path}: {token}')

print('RC2 decision architecture fix PASS')
