import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';

void main() {
  group('archive 20 physical scene discrimination', () {
    test('reality photo broad flash response overrides texture false positive', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.40,
        torchMeanLuma: 0.423,
        recoveryMeanLuma: 0.40,
        responsiveTileFraction: 0.5625,
        flashLiftRatio: 0.0567,
        flashResponseEntropy: 0.8761,
        flashHotspotConcentration: 0.2375,
        localFlicker: 0.1021,
        refreshBand: 0.1441,
        fineStripe: 0.0511,
        fineGrid: 0.4927,
        moire: 0.5239,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(result.score, 20);
      expect(
        result.reasons,
        contains('BROAD_DIFFUSE_PHYSICAL_RESPONSE'),
      );
      expect(
        result.reasons,
        contains('OPTICAL_TEXTURE_OVERRIDDEN_BY_BROAD_FLASH_RESPONSE'),
      );
      expect(
        result.reasons,
        isNot(contains('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH')),
      );
    });

    test('monitor photo with no diffuse lift remains unresolved', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.70,
        torchMeanLuma: 0.70,
        recoveryMeanLuma: 0.70,
        responsiveTileFraction: 0.0,
        flashLiftRatio: 0.0,
        flashResponseEntropy: 0.1844,
        flashHotspotConcentration: 1.0,
        localFlicker: 0.1335,
        refreshBand: 0.2176,
        fineStripe: 0.0081,
        fineGrid: 0.2756,
        moire: 0.1605,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
      expect(
        result.reasons,
        isNot(contains('BROAD_DIFFUSE_PHYSICAL_RESPONSE')),
      );
      expect(
        result.reasons,
        isNot(contains('DIFFUSE_REFLECTED_SCENE_RESPONSE')),
      );
    });

    test('monitor video concentrated response remains display evidence', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.70,
        torchMeanLuma: 0.70,
        recoveryMeanLuma: 0.70,
        responsiveTileFraction: 0.0625,
        flashLiftRatio: 0.0,
        flashResponseEntropy: 0.0,
        flashHotspotConcentration: 1.0,
        localFlicker: 0.5688,
        refreshBand: 0.161,
        fineStripe: 0.0085,
        fineGrid: 0.2766,
        moire: 0.1535,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH'),
      );
      expect(
        result.reasons,
        contains('TORCH_RESPONSE_CONCENTRATED_AS_GLARE'),
      );
    });
  });
}
