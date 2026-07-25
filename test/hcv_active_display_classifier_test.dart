import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';

void main() {
  group('HCVActiveDisplayClassifier V3', () {
    test('emissive monitor with localized glare remains display evidence', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.48,
        torchMeanLuma: 0.50,
        recoveryMeanLuma: 0.47,
        responsiveTileFraction: 0.19,
        flashLiftRatio: 0.05,
        flashResponseEntropy: 0.31,
        flashHotspotConcentration: 0.71,
        localFlicker: 0.12,
        refreshBand: 0.16,
        fineStripe: 0.04,
        fineGrid: 0.58,
        moire: 0.54,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(
        result.reasons,
        contains('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH'),
      );
      expect(result.reasons, contains('ELECTRONIC_DISPLAY_CUES_PRESENT'));
      expect(
        result.reasons,
        contains('TORCH_RESPONSE_CONCENTRATED_AS_GLARE'),
      );
    });

    test('physical scene with broad diffuse flash response becomes reality', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.30,
        torchMeanLuma: 0.42,
        recoveryMeanLuma: 0.31,
        responsiveTileFraction: 0.75,
        flashLiftRatio: 0.38,
        flashResponseEntropy: 0.84,
        flashHotspotConcentration: 0.23,
        localFlicker: 0.08,
        refreshBand: 0.06,
        fineStripe: 0.02,
        fineGrid: 0.18,
        moire: 0.16,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
      expect(
        result.reasons,
        contains('DIFFUSE_REFLECTED_SCENE_RESPONSE'),
      );
      expect(
        result.reasons,
        contains('LOW_ELECTRONIC_DISPLAY_STRUCTURE'),
      );
    });

    test('stable off phases can validate challenge if API lock is unavailable', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: false,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.30,
        torchMeanLuma: 0.42,
        recoveryMeanLuma: 0.305,
        responsiveTileFraction: 0.75,
        flashLiftRatio: 0.38,
        flashResponseEntropy: 0.84,
        flashHotspotConcentration: 0.23,
        localFlicker: 0.08,
        refreshBand: 0.06,
        fineStripe: 0.02,
        fineGrid: 0.18,
        moire: 0.16,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        isNot(contains('ACTIVE_ILLUMINATION_CHALLENGE_NOT_VALID')),
      );
    });

    test('unstable off phases invalidate flash measurement', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.30,
        torchMeanLuma: 0.44,
        recoveryMeanLuma: 0.50,
        responsiveTileFraction: 0.75,
        flashLiftRatio: 0.40,
        flashResponseEntropy: 0.84,
        flashHotspotConcentration: 0.23,
        localFlicker: 0.08,
        refreshBand: 0.06,
        fineStripe: 0.02,
        fineGrid: 0.18,
        moire: 0.16,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('ACTIVE_ILLUMINATION_CHALLENGE_NOT_VALID'),
      );
      expect(result.reasons, contains('OFF_PHASES_NOT_REPEATABLE'));
    });

    test('bright distant scene with no measurable flash remains indeterminate', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.78,
        torchMeanLuma: 0.79,
        recoveryMeanLuma: 0.78,
        responsiveTileFraction: 0.08,
        flashLiftRatio: 0.01,
        flashResponseEntropy: 0.20,
        flashHotspotConcentration: 0.68,
        localFlicker: 0.08,
        refreshBand: 0.04,
        fineStripe: 0.01,
        fineGrid: 0.18,
        moire: 0.09,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.reasons, contains('ACTIVE_CHALLENGE_INDETERMINATE'));
    });
  });
}
