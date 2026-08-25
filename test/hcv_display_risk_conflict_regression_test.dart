import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  test(
    'strong ML screen evidence survives reflected-reality conflict',
    () {
      final result = HCVDisplayRiskFusion.combine([
        {
          'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
          'analysisStatus': 'ANALYZED',
          'framesAnalyzed': 30,
          'screenReplayRiskScore': 20,
          'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
          'signals': {
            'reflectedRealityEvidence': true,
          },
        },
        {
          'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
          'analysisStatus': 'ANALYZED',
          'screenReplayRiskScore': 98,
          'predictedClass': 'SCREEN_MONITOR',
          'predictedClassConfidence': 0.9851,
        },
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
      expect(result.score, 69);
      expect(result.evidenceSources, contains('ML_SCREEN_CLASS'));
      expect(result.strongSources, contains('ML_SCREEN_CLASS'));
      expect(
        result.reasons,
        contains('ML_SCREEN_AND_REFLECTED_REALITY_CONFLICT'),
      );
    },
  );
}
