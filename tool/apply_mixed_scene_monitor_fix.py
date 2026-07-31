from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


# Keep the established geometry policy unchanged. Strong, reliable parallax
# must still be able to resolve reality-like electronic artefacts as reality.
scene_path = Path('lib/hcv_scene_decision_fusion.dart')
scene = scene_path.read_text()
if 'GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS' not in scene:
    raise RuntimeError(
        'The established scene decision policy is not present. '
        'Refusing to rewrite geometry thresholds or verdict rules.'
    )
if 'MIXED_DEPTH_SCENE_DOES_NOT_CANCEL_DISPLAY_EVIDENCE' in scene:
    raise RuntimeError('Unstable mixed-scene geometry override is still present')


# The actual defect was signal conflation: sceneDecision.realityEvidence also
# includes geometric depth, but the risk fusion interprets
# reflectedRealityEvidence as a physical diffuse-light response capable of
# suppressing optical/ML display evidence. Publish those signals separately.
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
    final indeterminate = sceneDecision.indeterminate;
""",
    'separate flash reflection from geometric reality',
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
""",
    'publish distinct reality evidence fields',
)
core_path.write_text(core)


# Replace the large modal alert created by the safe-capture patch with a
# compact, width-safe banner at the top. It stays away from the zoom strip and
# also fits narrow iPhone screens.
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
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 72, 14, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          italian
                              ? 'Verifica completata. Ricomponi l’inquadratura.'
                              : 'Verification complete. Restore your composition.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          italian ? 'PROSEGUI' : 'CONTINUE',
                          style: const TextStyle(
                            fontSize: 10,
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
  test('established strong-parallax reality policy remains unchanged', () {
    const illumination = HCVActiveDisplayClassification(
      decision: 'NON_CONCLUSIVE',
      risk: 'MEDIUM',
      score: 45,
      displayProbability: 0.63,
      illuminationResponseScore: 0.44,
      emissiveIndependenceScore: 0.56,
      electronicCueScore: 0.60,
      reasons: <String>[
        'EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH',
        'ELECTRONIC_DISPLAY_CUES_PRESENT',
      ],
    );
    const geometry = HCVSceneGeometryClassification(
      sceneClass: 'REALITY',
      realityEvidence: true,
      planarEvidence: false,
      motionMagnitude: 0.45,
      flowReliability: 0.75,
      directionCoherence: 0.62,
      depthDispersion: 0.45,
      planarCoherence: 0.26,
      matchedRegions: 9,
      reasons: <String>['MULTI_DEPTH_PARALLAX_DETECTED'],
    );

    final result = HCVSceneDecisionFusion.fuse(
      illumination: illumination,
      geometry: geometry,
    );

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.sceneClass, 'REALITY');
    expect(result.displayEvidence, isFalse);
    expect(result.realityEvidence, isTrue);
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
          'sceneRealityEvidence': true,
          'geometricRealityEvidence': true,
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

  test('true diffuse reflection still prevents a false strong display verdict', () {
    final result = HCVDisplayRiskFusion.combine(<Map<String, dynamic>?>[
      <String, dynamic>{
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'framesAnalyzed': 45,
        'screenReplayRiskScore': 20,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'signals': <String, dynamic>{
          'reflectedRealityEvidence': true,
          'sceneRealityEvidence': true,
          'geometricRealityEvidence': true,
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

    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('capture confirmation is compact width-safe and above the zoom strip', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final start = camera.indexOf('_showCaptureReadyMessage');
    final end = camera.indexOf('_toggleCoordinateStamp', start);
    final confirmation = camera.substring(start, end);

    expect(confirmation, contains('Alignment.topCenter'));
    expect(confirmation, contains("'PROSEGUI'"));
    expect(confirmation, contains('BoxConstraints(maxWidth: 330)'));
    expect(confirmation, contains('minimumSize: const Size(0, 30)'));
    expect(confirmation, isNot(contains('AlertDialog')));
  });

  test('flash reflection and geometric depth are distinct signed signals', () {
    final core = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    expect(
      core,
      contains("final reflectedRealityEvidence = active.reasons.contains("),
    );
    expect(core, contains("'sceneRealityEvidence': sceneRealityEvidence"));
    expect(core, contains("'geometricRealityEvidence': geometry.realityEvidence"));
    expect(core, isNot(contains("final reflectedRealityEvidence = sceneDecision.realityEvidence")));
  });
}
""")
