import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

void main() {
  test('post-capture evidence alone cannot decide a photo', () {
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
        'signals': const {'structuralDisplayTrace': true},
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
  });

  test('temporal live evidence can be corroborated by the captured photo', () {
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
      {
        'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'screenReplayRiskScore': 20,
        'framesAnalyzed': 45,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'globalFlickerScore': 0.31,
        'localTemporalFlickerScore': 0.52,
        'refreshBandScore': 0.186,
        'signals': const <String, dynamic>{
          'pairedFlickerTrace': true,
          'displayBandTrace': true,
          'horizontalRefreshBands': true,
          'reflectedRealityEvidence': false,
        },
      },
      {
        'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
        'screenReplayRiskScore': 70,
        'signals': const {'structuralDisplayTrace': true},
      },
    ]);

    expect(result.decision, 'NON_CONCLUSIVE');
  });
}
