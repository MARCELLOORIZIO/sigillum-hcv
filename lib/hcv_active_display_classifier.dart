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
    double flashLiftRatio = 0,
    double flashResponseEntropy = 0,
    double flashHotspotConcentration = 1,
  }) {
    final reasons = <String>[];
    final baselineReference =
        ((baselineMeanLuma + recoveryMeanLuma) / 2).clamp(0.0, 1.0);
    final recoveryError =
        (recoveryMeanLuma - baselineMeanLuma).abs().clamp(0.0, 1.0);
    final relativeRecoveryError =
        (recoveryError / max(0.08, baselineReference)).clamp(0.0, 1.0);
    final positiveTorchLift =
        max(0.0, torchMeanLuma - baselineReference).clamp(0.0, 1.0);
    final measuredLiftRatio = flashLiftRatio > 0
        ? flashLiftRatio.clamp(0.0, 1.0).toDouble()
        : (positiveTorchLift / max(0.08, baselineReference))
            .clamp(0.0, 1.0)
            .toDouble();

    // A strict API exposure lock is preferred. If the plugin cannot report a
    // lock, a highly repeatable OFF-before/OFF-after baseline still makes the
    // physical challenge usable.
    final recoveryStable = relativeRecoveryError <= 0.12;
    final challengeValid = framesAnalyzed >= 24 &&
        torchChallengeCompleted &&
        recoveryStable &&
        (exposureLocked || relativeRecoveryError <= 0.055);

    final coverage = responsiveTileFraction.clamp(0.0, 1.0).toDouble();
    final entropy = flashResponseEntropy.clamp(0.0, 1.0).toDouble();
    final hotspot = flashHotspotConcentration.clamp(0.0, 1.0).toDouble();
    final broadDiffuseShape =
        (coverage * 0.55 + entropy * 0.45).clamp(0.0, 1.0).toDouble();
    final liftStrength =
        (measuredLiftRatio / 0.20).clamp(0.0, 1.0).toDouble();
    final illuminationResponseScore = challengeValid
        ? (liftStrength * 0.52 + broadDiffuseShape * 0.48)
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

    final strictDiffuseReflection = challengeValid &&
        measuredLiftRatio >= 0.07 &&
        coverage >= 0.38 &&
        entropy >= 0.48 &&
        hotspot <= 0.58 &&
        illuminationResponseScore >= 0.42;

    // A real three-dimensional scene may produce a modest global lift when the
    // torch is distant, but its response is still spatially broad, distributed
    // and non-glare-like. This signature is deliberately stricter on shape
    // than on raw brightness so it does not accept a glossy display hotspot.
    final broadDiffusePhysicalResponse = challengeValid &&
        measuredLiftRatio >= 0.045 &&
        coverage >= 0.50 &&
        entropy >= 0.72 &&
        hotspot <= 0.42 &&
        illuminationResponseScore >= 0.40;

    final lowElectronicScene = electronicCueScore <= 0.46;
    final electronicCuesNotDominant = electronicCueScore < 0.68;
    final reflectedRealityEvidence =
        (strictDiffuseReflection && lowElectronicScene) ||
            (broadDiffusePhysicalResponse && electronicCuesNotDominant);

    // A display can reflect the torch from its glass. That reflection is
    // generally concentrated in a small area while the emitted image remains
    // stable elsewhere. Electronic structure is therefore required together
    // with weak/directed illumination response. A broad diffuse physical
    // response suppresses this hypothesis because it is incompatible with a
    // localized glass glare response.
    final electronicDisplayStructure = electronicCueScore >= 0.48;
    final directedGlare = hotspot >= 0.52 || coverage <= 0.34;
    final weakDiffuseResponse = illuminationResponseScore <= 0.58;
    final emissiveDisplayEvidence = challengeValid &&
        electronicDisplayStructure &&
        !broadDiffusePhysicalResponse &&
        (directedGlare || weakDiffuseResponse);

    if (!challengeValid) {
      reasons.add('ACTIVE_ILLUMINATION_CHALLENGE_NOT_VALID');
      if (!exposureLocked) reasons.add('EXPOSURE_LOCK_NOT_CONFIRMED');
      if (!recoveryStable) reasons.add('OFF_PHASES_NOT_REPEATABLE');
    }
    if (reflectedRealityEvidence) {
      reasons.add('DIFFUSE_REFLECTED_SCENE_RESPONSE');
      if (broadDiffusePhysicalResponse) {
        reasons.add('BROAD_DIFFUSE_PHYSICAL_RESPONSE');
      }
      if (lowElectronicScene) {
        reasons.add('LOW_ELECTRONIC_DISPLAY_STRUCTURE');
      } else {
        reasons.add('OPTICAL_TEXTURE_OVERRIDDEN_BY_BROAD_FLASH_RESPONSE');
      }
    }
    if (emissiveDisplayEvidence) {
      reasons.add('EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH');
      reasons.add('ELECTRONIC_DISPLAY_CUES_PRESENT');
      if (directedGlare) reasons.add('TORCH_RESPONSE_CONCENTRATED_AS_GLARE');
    }

    if (emissiveDisplayEvidence && !reflectedRealityEvidence) {
      final probability =
          (electronicCueScore * 0.48 +
                  emissiveIndependenceScore * 0.32 +
                  hotspot * 0.20)
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

    if (reflectedRealityEvidence && !emissiveDisplayEvidence) {
      final probability =
          ((1.0 - illuminationResponseScore) * 0.52 +
                  electronicCueScore * 0.28 +
                  hotspot * 0.20)
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

    if (emissiveDisplayEvidence && reflectedRealityEvidence) {
      reasons.add('FLASH_AND_ELECTRONIC_EVIDENCE_CONFLICT');
    } else {
      reasons.add('ACTIVE_CHALLENGE_INDETERMINATE');
    }
    return HCVActiveDisplayClassification(
      decision: 'NON_CONCLUSIVE',
      risk: 'MEDIUM',
      score: 45,
      displayProbability:
          max(0.30, electronicCueScore * 0.60).clamp(0.0, 1.0).toDouble(),
      illuminationResponseScore: illuminationResponseScore,
      emissiveIndependenceScore: emissiveIndependenceScore,
      electronicCueScore: electronicCueScore,
      reasons: reasons,
    );
  }
}
