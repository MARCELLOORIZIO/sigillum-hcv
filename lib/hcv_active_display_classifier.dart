import 'dart:math';

class HCVActiveDisplayClassification {
  const HCVActiveDisplayClassification({
    required this.decision,
    required this.risk,
    required this.score,
    required this.displayProbability,
    required this.illuminationResponseScore,
    required this.emissiveIndependenceScore,
    required this.electronicCueScore,
    required this.reasons,
  });

  final String decision;
  final String risk;
  final int score;
  final double displayProbability;
  final double illuminationResponseScore;
  final double emissiveIndependenceScore;
  final double electronicCueScore;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
        'decision': decision,
        'risk': risk,
        'score': score,
        'displayProbability': _round(displayProbability),
        'illuminationResponseScore': _round(illuminationResponseScore),
        'emissiveIndependenceScore': _round(emissiveIndependenceScore),
        'electronicCueScore': _round(electronicCueScore),
        'reasons': reasons,
      };

  static double _round(double value) =>
      double.parse(value.clamp(0.0, 1.0).toStringAsFixed(4));
}

class HCVActiveDisplayClassifier {
  const HCVActiveDisplayClassifier._();

  static HCVActiveDisplayClassification classify({
    required int framesAnalyzed,
    required bool exposureLocked,
    required bool torchChallengeCompleted,
    required double baselineMeanLuma,
    required double torchMeanLuma,
    required double recoveryMeanLuma,
    required double responsiveTileFraction,
    required double localFlicker,
    required double refreshBand,
    required double fineStripe,
    required double fineGrid,
    required double moire,
  }) {
    final reasons = <String>[];
    final baselineReference =
        ((baselineMeanLuma + recoveryMeanLuma) / 2).clamp(0.0, 1.0);
    final positiveTorchLift =
        max(0.0, torchMeanLuma - baselineReference).clamp(0.0, 1.0);
    final torchLiftRatio =
        (positiveTorchLift / max(0.08, baselineReference)).clamp(0.0, 1.0);
    final recoveryError =
        (recoveryMeanLuma - baselineMeanLuma).abs().clamp(0.0, 1.0);

    final challengeValid = framesAnalyzed >= 24 &&
        exposureLocked &&
        torchChallengeCompleted &&
        recoveryError <= 0.16;

    // Reflected scenes normally brighten over a meaningful part of the frame
    // when exposure is locked and the phone torch is added. A self-emissive
    // display is substantially less dependent on that illumination.
    final illuminationResponseScore = challengeValid
        ? ((torchLiftRatio / 0.22) * 0.65 +
                (responsiveTileFraction / 0.70) * 0.35)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;
    final emissiveIndependenceScore = challengeValid
        ? (1.0 - illuminationResponseScore).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final flickerCue = (localFlicker / 0.55).clamp(0.0, 1.0);
    final refreshCue = (refreshBand / 0.16).clamp(0.0, 1.0);
    final stripeCue = (fineStripe / 0.36).clamp(0.0, 1.0);
    final gridCue = (fineGrid / 0.82).clamp(0.0, 1.0);
    final moireCue = (moire / 0.42).clamp(0.0, 1.0);
    final electronicCueScore =
        (flickerCue * 0.26 +
                refreshCue * 0.24 +
                stripeCue * 0.16 +
                gridCue * 0.18 +
                moireCue * 0.16)
            .clamp(0.0, 1.0)
            .toDouble();

    final reflectedRealityEvidence =
        challengeValid && illuminationResponseScore >= 0.62;
    final emissiveDisplayEvidence = challengeValid &&
        emissiveIndependenceScore >= 0.58 &&
        electronicCueScore >= 0.34;

    if (!challengeValid) {
      reasons.add('ACTIVE_ILLUMINATION_CHALLENGE_NOT_VALID');
    }
    if (reflectedRealityEvidence) {
      reasons.add('REFLECTED_SCENE_RESPONDS_TO_TORCH');
    }
    if (emissiveDisplayEvidence) {
      reasons.add('EMISSIVE_SCENE_RESISTS_TORCH');
      reasons.add('ELECTRONIC_DISPLAY_CUES_PRESENT');
    }

    // This is intentionally conservative. Until the independent geometric
    // challenge is added, active illumination can support a display warning
    // but cannot by itself create STRONG_DISPLAY_RISK.
    if (emissiveDisplayEvidence) {
      final probability =
          (emissiveIndependenceScore * 0.62 + electronicCueScore * 0.38)
              .clamp(0.0, 1.0)
              .toDouble();
      return HCVActiveDisplayClassification(
        decision: 'NON_CONCLUSIVE',
        risk: 'MEDIUM',
        score: 45,
        displayProbability: probability,
        illuminationResponseScore: illuminationResponseScore,
        emissiveIndependenceScore: emissiveIndependenceScore,
        electronicCueScore: electronicCueScore,
        reasons: reasons,
      );
    }

    if (reflectedRealityEvidence) {
      final probability =
          ((1.0 - illuminationResponseScore) * 0.75 +
                  electronicCueScore * 0.25)
              .clamp(0.0, 1.0)
              .toDouble();
      return HCVActiveDisplayClassification(
        decision: 'NO_DISPLAY_EVIDENCE',
        risk: 'LOW',
        score: 20,
        displayProbability: probability,
        illuminationResponseScore: illuminationResponseScore,
        emissiveIndependenceScore: emissiveIndependenceScore,
        electronicCueScore: electronicCueScore,
        reasons: reasons,
      );
    }

    reasons.add('ACTIVE_CHALLENGE_INDETERMINATE');
    return HCVActiveDisplayClassification(
      decision: 'NON_CONCLUSIVE',
      risk: 'MEDIUM',
      score: 45,
      displayProbability:
          max(0.35, electronicCueScore * 0.55).clamp(0.0, 1.0).toDouble(),
      illuminationResponseScore: illuminationResponseScore,
      emissiveIndependenceScore: emissiveIndependenceScore,
      electronicCueScore: electronicCueScore,
      reasons: reasons,
    );
  }
}
