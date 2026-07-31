from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()

helper = """HCVDisplayRiskResult combinePhotoDisplayRiskWithCapturedImageEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  final preCaptureResult =
      combinePhotoDisplayRiskFromPreCaptureEvidence(analyses);
  final capturedImageResult = HCVDisplayRiskFusion.combine(analyses);

  if (capturedImageResult.decision != 'STRONG_DISPLAY_RISK') {
    return preCaptureResult;
  }
  if (preCaptureResult.decision == 'STRONG_DISPLAY_RISK') {
    return preCaptureResult;
  }

  return HCVDisplayRiskResult(
    risk: capturedImageResult.risk,
    score: capturedImageResult.score,
    decision: capturedImageResult.decision,
    analysisStatus: capturedImageResult.analysisStatus,
    evidenceSources: capturedImageResult.evidenceSources,
    strongSources: capturedImageResult.strongSources,
    reasons: <String>[
      ...capturedImageResult.reasons,
      'PHOTO_CAPTURED_IMAGE_CONFIRMATION',
    ],
  );
}

"""

if 'combinePhotoDisplayRiskWithCapturedImageEvidence' not in camera:
    anchor = 'HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence('
    if camera.count(anchor) != 1:
        raise RuntimeError(
            'photo monitor helper: expected the safe capture patch to be applied first'
        )
    camera = camera.replace(anchor, helper + anchor, 1)

old_photo_decision = """      final displayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(
        screenReplayAnalyses,
      );"""
new_photo_decision = """      final displayRisk =
          combinePhotoDisplayRiskWithCapturedImageEvidence(
        screenReplayAnalyses,
      );"""
camera = replace_once(
    camera,
    old_photo_decision,
    new_photo_decision,
    'photo uses captured image confirmation',
)

camera_path.write_text(camera)

Path('test/photo_monitor_alignment_test.dart').write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

void main() {
  test('captured photo evidence can confirm a monitor missed by the live probe', () {
    final analyses = <Map<String, dynamic>?>[
      {
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'screenReplayRiskScore': 20,
        'framesAnalyzed': 45,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'signals': const <String, dynamic>{},
      },
      {
        'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
        'analysisStatus': 'ANALYZED',
        'screenReplayRiskScore': 98,
        'signals': const <String, dynamic>{
          'structuralDisplayTrace': true,
        },
      },
      {
        'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
        'analysisStatus': 'ANALYZED',
        'screenReplayRiskScore': 99,
        'predictedClass': 'SCREEN_MONITOR',
        'predictedClassConfidence': 0.99,
      },
    ];

    final preCaptureOnly =
        combinePhotoDisplayRiskFromPreCaptureEvidence(analyses);
    final aligned =
        combinePhotoDisplayRiskWithCapturedImageEvidence(analyses);

    expect(preCaptureOnly.decision, 'NO_DISPLAY_EVIDENCE');
    expect(aligned.decision, 'STRONG_DISPLAY_RISK');
    expect(aligned.reasons, contains('PHOTO_CAPTURED_IMAGE_CONFIRMATION'));
  });

  test('weak captured-image evidence does not override the live result', () {
    final analyses = <Map<String, dynamic>?>[
      {
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'screenReplayRiskScore': 20,
        'framesAnalyzed': 45,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'signals': const <String, dynamic>{},
      },
      {
        'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
        'analysisStatus': 'ANALYZED',
        'screenReplayRiskScore': 35,
        'signals': const <String, dynamic>{},
      },
    ];

    final aligned =
        combinePhotoDisplayRiskWithCapturedImageEvidence(analyses);

    expect(aligned.decision, 'NO_DISPLAY_EVIDENCE');
    expect(aligned.reasons, isNot(contains('PHOTO_CAPTURED_IMAGE_CONFIRMATION')));
  });
}
""")
