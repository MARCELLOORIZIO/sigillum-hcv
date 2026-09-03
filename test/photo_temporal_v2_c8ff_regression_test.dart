import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> _temporalV2Live({
  required String decision,
  required int score,
  required String risk,
}) => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 6,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 4,
      'screenReplayRisk': risk,
      'screenReplayRiskScore': score,
      'displayRiskDecision': decision,
      'sceneClass': 'UNKNOWN',
      'reason': 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_NO_PARALLAX',
      'signals': const {
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'planarSceneEvidence': false,
        'activeChallengeIndeterminate': false,
      },
      'photoDecisionMethod': 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT',
      'videoEquivalentAvailable': true,
      'videoEquivalentDisplayRisk': {
        'risk': risk,
        'score': score,
        'decision': decision,
        'analysisStatus': 'COMPLETE',
        'evidenceSources': decision == 'STRONG_DISPLAY_RISK'
            ? const ['ML_SCREEN_CLASS']
            : const <String>[],
        'strongSources': decision == 'STRONG_DISPLAY_RISK'
            ? const ['ML_SCREEN_CLASS']
            : const <String>[],
        'reasons': decision == 'STRONG_DISPLAY_RISK'
            ? const ['ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY']
            : const ['ML_FIRST_VIDEO_NO_SCREEN_MAJORITY_LOW_PROBABILITY'],
      },
    };

Map<String, dynamic> _c8ffLikeStillReality() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'REALITY_OUTDOOR',
      'predictedClassConfidence': 0.9141,
      'screenProbability': 0.0747,
      'screenReplayRiskScore': 7,
      'framesAnalyzed': 1,
      'signals': const {
        'fullFrameRiskScore': 7,
        'contentAreaRiskScore': 7,
      },
    };

void main() {
  test(
    'C8FF: strong immediately pre-shot temporal DISPLAY survives still REALITY false negative',
    () {
      final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
        _temporalV2Live(
          decision: 'STRONG_DISPLAY_RISK',
          score: 96,
          risk: 'HIGH',
        ),
        _c8ffLikeStillReality(),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.score, greaterThanOrEqualTo(70));
    },
  );

  test(
    'Temporal V2 weak evidence does not force DISPLAY against a strong still REALITY result',
    () {
      final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
        _temporalV2Live(
          decision: 'NO_DISPLAY_EVIDENCE',
          score: 12,
          risk: 'LOW',
        ),
        _c8ffLikeStillReality(),
      ]);

      expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    },
  );
}
