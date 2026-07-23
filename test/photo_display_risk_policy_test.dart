import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

void main() {
  test('photo decision uses only pre-capture live evidence', () {
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
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
        'screenReplayRiskScore': 98,
        'signals': const {
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
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
    expect(result.evidenceSources, isEmpty);
  });
}
