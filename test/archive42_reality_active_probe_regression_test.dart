import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';

void main() {
  group('Archive 42 real-scene active illumination regressions', () {
    test('real photo moire does not become emissive display evidence', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.4058,
        torchMeanLuma: 0.3962,
        recoveryMeanLuma: 0.3745,
        responsiveTileFraction: 0.375,
        flashLiftRatio: 0.0155,
        flashResponseEntropy: 0.6401,
        flashHotspotConcentration: 0.4787,
        localFlicker: 0.3819,
        refreshBand: 0.1197,
        fineStripe: 0.0814,
        fineGrid: 0.2335,
        moire: 0.7064,
      );

      expect(
        result.reasons,
        isNot(contains('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH')),
      );
      expect(
        result.reasons,
        contains('ACTIVE_ELECTRONIC_CUES_UNCORROBORATED'),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
    });

    test('real planar video moire does not become emissive display evidence', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.4150,
        torchMeanLuma: 0.4109,
        recoveryMeanLuma: 0.4026,
        responsiveTileFraction: 0.125,
        flashLiftRatio: 0.0052,
        flashResponseEntropy: 0.5954,
        flashHotspotConcentration: 0.6468,
        localFlicker: 0.3408,
        refreshBand: 0.0927,
        fineStripe: 0.0555,
        fineGrid: 0.0619,
        moire: 0.5379,
      );

      expect(
        result.reasons,
        isNot(contains('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH')),
      );
      expect(
        result.reasons,
        contains('ACTIVE_ELECTRONIC_CUES_UNCORROBORATED'),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
    });

    test('known monitor flash profile keeps emissive display evidence', () {
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

      expect(
        result.reasons,
        contains('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH'),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
    });
  });
}
