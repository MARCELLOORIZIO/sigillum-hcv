import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

void main() {
  test('photo decision accepts two independent post-capture sources only as non-conclusive', () {
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
        'analysisStatus': 'ANALYZED',
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

    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.score, 69);
    expect(
      result.evidenceSources,
      containsAll(<String>['STATIC_OPTICAL', 'ML_SCREEN_CLASS']),
    );
    expect(result.strongSources, hasLength(2));
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });
}
