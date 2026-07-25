import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';

void main() {
  group('HCVActiveDisplayClassifier', () {
    test('emissive monitor response becomes non-conclusive display evidence', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.48,
        torchMeanLuma: 0.50,
        recoveryMeanLuma: 0.47,
        responsiveTileFraction: 0.16,
        localFlicker: 0.50,
        refreshBand: 0.11,
        fineStripe: 0.24,
        fineGrid: 0.76,
        moire: 0.30,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('EMISSIVE_SCENE_RESISTS_TORCH'));
      expect(result.reasons, contains('ELECTRONIC_DISPLAY_CUES_PRESENT'));
    });

    test('reflected physical scene that brightens becomes no display evidence', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.30,
        torchMeanLuma: 0.44,
        recoveryMeanLuma: 0.31,
        responsiveTileFraction: 0.72,
        localFlicker: 0.18,
        refreshBand: 0.07,
        fineStripe: 0.20,
        fineGrid: 0.48,
        moire: 0.18,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
      expect(
        result.reasons,
        contains('REFLECTED_SCENE_RESPONDS_TO_TORCH'),
      );
    });

    test('invalid challenge never becomes no display evidence', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 12,
        exposureLocked: false,
        torchChallengeCompleted: false,
        baselineMeanLuma: 0.40,
        torchMeanLuma: 0.40,
        recoveryMeanLuma: 0.40,
        responsiveTileFraction: 0.0,
        localFlicker: 0.10,
        refreshBand: 0.05,
        fineStripe: 0.10,
        fineGrid: 0.20,
        moire: 0.10,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('ACTIVE_ILLUMINATION_CHALLENGE_NOT_VALID'),
      );
    });

    test('bright distant scene with weak torch response stays indeterminate', () {
      final result = HCVActiveDisplayClassifier.classify(
        framesAnalyzed: 45,
        exposureLocked: true,
        torchChallengeCompleted: true,
        baselineMeanLuma: 0.78,
        torchMeanLuma: 0.79,
        recoveryMeanLuma: 0.78,
        responsiveTileFraction: 0.08,
        localFlicker: 0.08,
        refreshBand: 0.04,
        fineStripe: 0.12,
        fineGrid: 0.22,
        moire: 0.09,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.reasons, contains('ACTIVE_CHALLENGE_INDETERMINATE'));
    });
  });
}
