from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


# 1. A real three-dimensional background must not erase electronic display
# evidence from a monitor contained in the same frame.
scene_path = Path('lib/hcv_scene_decision_fusion.dart')
scene = scene_path.read_text()
scene = replace_once(
    scene,
    """    if (strongGeometryReality) {
      decision = 'NO_DISPLAY_EVIDENCE';
      risk = 'LOW';
      score = 20;
      probability = min(illumination.displayProbability, 0.25).toDouble();
      reasons.add('GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS');
    } else if (geometry.realityEvidence && rawDisplayEvidence) {
      decision = 'NON_CONCLUSIVE';
      risk = 'MEDIUM';
      score = 45;
      reasons.add('ILLUMINATION_AND_GEOMETRY_EVIDENCE_CONFLICT');
    } else if (geometry.planarEvidence && rawDisplayEvidence) {
      decision = 'NON_CONCLUSIVE';
      risk = 'MEDIUM';
      score = max(45, illumination.score).toInt();
      probability = max(illumination.displayProbability, 0.55).toDouble();
      reasons.add('PLANAR_GEOMETRY_CORROBORATES_DISPLAY_HYPOTHESIS');
    }

    final realityEvidence = flashRealityEvidence || strongGeometryReality;
    final displayEvidence = rawDisplayEvidence && !strongGeometryReality;
    final indeterminate = decision == 'NON_CONCLUSIVE' &&
        !displayEvidence &&
        !realityEvidence;
    final sceneClass = realityEvidence && !displayEvidence
        ? 'REALITY'
        : geometry.planarEvidence && displayEvidence
            ? 'DISPLAY_SUSPECTED'
            : 'UNKNOWN';
""",
    """    if (strongGeometryReality && rawDisplayEvidence) {
      // A monitor commonly appears together with a desk, wall or other real
      // depth layers. Geometry proves that the frame is mixed; it does not
      // disprove the electronic surface detected inside that frame.
      decision = 'NON_CONCLUSIVE';
      risk = 'MEDIUM';
      score = max(45, illumination.score).toInt();
      probability = max(illumination.displayProbability, 0.55).toDouble();
      reasons.add('MIXED_DEPTH_SCENE_DOES_NOT_CANCEL_DISPLAY_EVIDENCE');
    } else if (strongGeometryReality) {
      decision = 'NO_DISPLAY_EVIDENCE';
      risk = 'LOW';
      score = 20;
      probability = min(illumination.displayProbability, 0.25).toDouble();
      reasons.add('GEOMETRIC_REALITY_WITHOUT_DISPLAY_EVIDENCE');
    } else if (geometry.realityEvidence && rawDisplayEvidence) {
      decision = 'NON_CONCLUSIVE';
      risk = 'MEDIUM';
      score = max(45, illumination.score).toInt();
      probability = max(illumination.displayProbability, 0.50).toDouble();
      reasons.add('ILLUMINATION_AND_GEOMETRY_EVIDENCE_COEXIST');
    } else if (geometry.planarEvidence && rawDisplayEvidence) {
      decision = 'NON_CONCLUSIVE';
      risk = 'MEDIUM';
      score = max(45, illumination.score).toInt();
      probability = max(illumination.displayProbability, 0.55).toDouble();
      reasons.add('PLANAR_GEOMETRY_CORROBORATES_DISPLAY_HYPOTHESIS');
    }

    final displayEvidence = rawDisplayEvidence;
    final geometryRealityWithoutDisplay =
        strongGeometryReality && !rawDisplayEvidence;
    final realityEvidence =
        flashRealityEvidence || geometryRealityWithoutDisplay;
    final mixedSceneEvidence = rawDisplayEvidence && geometry.realityEvidence;
    final indeterminate = decision == 'NON_CONCLUSIVE' &&
        !displayEvidence &&
        !realityEvidence;
    final sceneClass = mixedSceneEvidence
        ? 'MIXED_SCENE_DISPLAY_SUSPECTED'
        : realityEvidence && !displayEvidence
            ? 'REALITY'
            : displayEvidence
                ? 'DISPLAY_SUSPECTED'
                : 'UNKNOWN';
""",
    'mixed scene decision',
)
scene_path.write_text(scene)


# 2. Keep flash-reflection evidence separate from geometric depth evidence.
# Only the former may suppress passive optical evidence in the risk fusion.
core_path = Path('lib/hcv_live_screen_probe_core.dart')
core = core_path.read_text()
core = replace_once(
    core,
    """    final activeDisplayEvidence = sceneDecision.displayEvidence;
    final reflectedRealityEvidence = sceneDecision.realityEvidence;
    final indeterminate = sceneDecision.indeterminate;
""",
    """    final activeDisplayEvidence = sceneDecision.displayEvidence;
    final sceneRealityEvidence = sceneDecision.realityEvidence;
    final reflectedRealityEvidence = active.reasons.contains(
      'DIFFUSE_REFLECTED_SCENE_RESPONSE',
    );
    final mixedSceneEvidence =
        sceneDecision.sceneClass == 'MIXED_SCENE_DISPLAY_SUSPECTED';
    final indeterminate = sceneDecision.indeterminate;
""",
    'separate flash and geometry reality evidence',
)
core = replace_once(
    core,
    """        'activeIlluminationDisplayEvidence': activeDisplayEvidence,
        'reflectedRealityEvidence': reflectedRealityEvidence,
        'geometricRealityEvidence': geometry.realityEvidence,
""",
    """        'activeIlluminationDisplayEvidence': activeDisplayEvidence,
        'reflectedRealityEvidence': reflectedRealityEvidence,
        'sceneRealityEvidence': sceneRealityEvidence,
        'geometricRealityEvidence': geometry.realityEvidence,
        'mixedSceneEvidence': mixedSceneEvidence,
""",
    'publish separate reality signals',
)
core = replace_once(
    core,
    """        'uncorroboratedDisplayPattern':
            !activeDisplayEvidence && !reflectedRealityEvidence,
""",
    """        'uncorroboratedDisplayPattern':
            !activeDisplayEvidence && !sceneRealityEvidence,
""",
    'diagnostic uncorroborated display pattern',
)
core_path.write_text(core)


# 3. Replace the large central alert with a compact top confirmation that
# cannot cover the zoom controls.
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()
start_marker = '  Future<void> _showCaptureReadyMessage() async {'
end_marker = '  Future<void> _toggleCoordinateStamp() async {'
start = camera.find(start_marker)
end = camera.find(end_marker, start)
if start < 0 or end < 0:
    raise RuntimeError('compact confirmation: safe capture patch not found')
compact_confirmation = """  Future<void> _showCaptureReadyMessage() async {
    if (!mounted) return;
    final italian = widget.languageCode.toLowerCase().startsWith('it');
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 330,
              margin: const EdgeInsets.only(top: 72, left: 14, right: 14),
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      italian
                          ? 'Verifica completata. Ricomponi l’inquadratura.'
                          : 'Verification complete. Restore your composition.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      italian ? 'PROSEGUI' : 'CONTINUE',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

"""
camera = camera[:start] + compact_confirmation + camera[end:]
camera_path.write_text(camera)


Path('test/mixed_scene_monitor_regression_test.dart').write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('real background does not erase electronic monitor evidence', () {
    const illumination = HCVActiveDisplayClassification(
      decision: 'NON_CONCLUSIVE',
      risk: 'MEDIUM',
      score: 45,
      displayProbability: 0.76,
      illuminationResponseScore: 0.24,
      emissiveIndependenceScore: 0.76,
      electronicCueScore: 0.81,
      reasons: <String>[
        'EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH',
        'ELECTRONIC_DISPLAY_CUES_PRESENT',
      ],
    );
    const geometry = HCVSceneGeometryClassification(
      sceneClass: 'REALITY',
      realityEvidence: true,
      planarEvidence: false,
      motionMagnitude: 0.52,
      flowReliability: 0.82,
      directionCoherence: 0.64,
      depthDispersion: 0.58,
      planarCoherence: 0.32,
      matchedRegions: 9,
      reasons: <String>['MULTI_DEPTH_PARALLAX_DETECTED'],
    );

    final result = HCVSceneDecisionFusion.fuse(
      illumination: illumination,
      geometry: geometry,
    );

    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.displayEvidence, isTrue);
    expect(result.sceneClass, 'MIXED_SCENE_DISPLAY_SUSPECTED');
    expect(
      result.reasons,
      contains('MIXED_DEPTH_SCENE_DOES_NOT_CANCEL_DISPLAY_EVIDENCE'),
    );
  });

  test('geometric depth does not suppress temporal optical and ML evidence', () {
    final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
      <String, dynamic>{
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'framesAnalyzed': 45,
        'screenReplayRiskScore': 20,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'signals': <String, dynamic>{
          'reflectedRealityEvidence': false,
          'geometricRealityEvidence': true,
          'sceneRealityEvidence': true,
          'activeIlluminationDisplayEvidence': false,
        },
      },
      <String, dynamic>{
        'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
        'analysisStatus': 'ANALYZED',
        'screenReplayRiskScore': 86,
        'signals': <String, dynamic>{
          'strongDisplayTrace': true,
          'structuralDisplayTrace': true,
        },
      },
      <String, dynamic>{
        'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
        'analysisStatus': 'ANALYZED',
        'screenReplayRiskScore': 96,
        'predictedClass': 'SCREEN_MONITOR',
        'predictedClassConfidence': 0.91,
      },
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.strongSources, contains('STATIC_OPTICAL'));
    expect(result.strongSources, contains('ML_SCREEN_CLASS'));
  });

  test('a genuine three-dimensional scene without display evidence stays real', () {
    const illumination = HCVActiveDisplayClassification(
      decision: 'NON_CONCLUSIVE',
      risk: 'MEDIUM',
      score: 45,
      displayProbability: 0.30,
      illuminationResponseScore: 0.30,
      emissiveIndependenceScore: 0.70,
      electronicCueScore: 0.20,
      reasons: <String>['ACTIVE_CHALLENGE_INDETERMINATE'],
    );
    const geometry = HCVSceneGeometryClassification(
      sceneClass: 'REALITY',
      realityEvidence: true,
      planarEvidence: false,
      motionMagnitude: 0.55,
      flowReliability: 0.80,
      directionCoherence: 0.60,
      depthDispersion: 0.56,
      planarCoherence: 0.30,
      matchedRegions: 8,
      reasons: <String>['MULTI_DEPTH_PARALLAX_DETECTED'],
    );

    final result = HCVSceneDecisionFusion.fuse(
      illumination: illumination,
      geometry: geometry,
    );

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.sceneClass, 'REALITY');
    expect(result.displayEvidence, isFalse);
  });

  test('capture confirmation is compact and placed above the zoom strip', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final start = camera.indexOf('_showCaptureReadyMessage');
    final end = camera.indexOf('_toggleCoordinateStamp', start);
    final confirmation = camera.substring(start, end);

    expect(confirmation, contains('Alignment.topCenter'));
    expect(confirmation, contains("'PROSEGUI'"));
    expect(confirmation, contains('minimumSize: const Size(0, 32)'));
    expect(confirmation, isNot(contains('AlertDialog')));
  });

  test('flash reflection and geometric depth are separate signals', () {
    final core = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    expect(
      core,
      contains("final reflectedRealityEvidence = active.reasons.contains("),
    );
    expect(core, contains("'sceneRealityEvidence': sceneRealityEvidence"));
    expect(core, contains("'mixedSceneEvidence': mixedSceneEvidence"));
  });
}
""")
