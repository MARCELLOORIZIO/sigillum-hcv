import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

void main() {
  test(
    'uploaded monitor photo certificate is no longer reduced to no display',
    () {
      final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
        {
          'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
          'analysisStatus': 'ANALYZED',
          'framesAnalyzed': 45,
          'screenReplayRiskScore': 20,
          'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
          'globalFlickerScore': 0.3109,
          'localTemporalFlickerScore': 0.5189,
          'refreshBandScore': 0.186,
          'signals': const <String, dynamic>{
            'rawActiveDisplayEvidence': false,
            'activeIlluminationDisplayEvidence': false,
            'reflectedRealityEvidence': false,
            'geometricRealityEvidence': true,
            'planarSceneEvidence': false,
            'pairedFlickerTrace': true,
            'displayBandTrace': true,
            'horizontalRefreshBands': true,
          },
        },
        {
          'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
          'screenReplayRiskScore': 70,
          'signals': const <String, dynamic>{'structuralDisplayTrace': true},
        },
        {
          'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
          'analysisStatus': 'NOT_ANALYZED',
          'screenReplayRiskScore': null,
          'reason': 'ML_ANALYSIS_ERROR',
        },
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, inInclusiveRange(45, 69));
    },
  );

  test(
    'uploaded monitor video certificate becomes strong physical display risk',
    () {
      final result = combineVideoDisplayRiskFromCaptureEvidence([
        {
          'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
          'analysisStatus': 'ANALYZED',
          'framesAnalyzed': 45,
          'screenReplayRiskScore': 45,
          'displayRiskDecision': 'NON_CONCLUSIVE',
          'globalFlickerScore': 0.1011,
          'localTemporalFlickerScore': 0.2586,
          'refreshBandScore': 0.2,
          'videoEquivalentAvailable': false,
          'signals': const <String, dynamic>{
            'rawActiveDisplayEvidence': true,
            'activeIlluminationDisplayEvidence': true,
            'reflectedRealityEvidence': false,
            'geometricRealityEvidence': false,
            'planarSceneEvidence': false,
            'pairedFlickerTrace': true,
            'horizontalRefreshBands': true,
            'dynamicScreenChallengeTrace': true,
          },
        },
        {
          'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
          'screenReplayRiskScore': 20,
          'signals': const <String, dynamic>{},
        },
        {
          'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
          'analysisStatus': 'NOT_ANALYZED',
          'screenReplayRiskScore': null,
          'reason': 'ML_ANALYSIS_ERROR',
        },
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, inInclusiveRange(45, 69));
    },
  );
}
