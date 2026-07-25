import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';

void main() {
  group('Archive 19 physical response profiles', () {
    test('monitor structure plus concentrated flash reflection remains display evidence', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.52,
        torchMeanLuma: 0.55,
        recoveryMeanLuma: 0.52,
        responsiveTileFraction: 0.25,
        flashLiftRatio: 0.055,
        flashResponseEntropy: 0.38,
        flashHotspotConcentration: 0.66,
        localFlicker: 0.0817,
        refreshBand: 0.1661,
        fineStripe: 0.0358,
        fineGrid: 0.5374,
        moire: 0.5442,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH'),
      );
    });

    test('low-electronic scene plus broad flash response becomes reality', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.34,
        torchMeanLuma: 0.44,
        recoveryMeanLuma: 0.34,
        responsiveTileFraction: 0.69,
        flashLiftRatio: 0.29,
        flashResponseEntropy: 0.80,
        flashHotspotConcentration: 0.27,
        localFlicker: 0.1077,
        refreshBand: 0.1646,
        fineStripe: 0.0099,
        fineGrid: 0.1772,
        moire: 0.2153,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('DIFFUSE_REFLECTED_SCENE_RESPONSE'),
      );
    });
  });
}
