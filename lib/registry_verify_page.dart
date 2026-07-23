import 'production_registry_verify_page.dart';

class HCVDisplayRiskClaimValues {
  const HCVDisplayRiskClaimValues({
    required this.risk,
    required this.score,
    required this.decision,
    required this.requiresLegacyNormalization,
  });

  final String? risk;
  final String? score;
  final String? decision;
  final bool requiresLegacyNormalization;
}

HCVDisplayRiskClaimValues resolveHCVDisplayRiskClaimValues(
  Map<dynamic, dynamic> claims,
) {
  final evidence = claims['displayRiskEvidence'];
  final signedRisk = evidence is Map ? evidence['risk']?.toString() : null;
  final signedScore = evidence is Map ? evidence['score']?.toString() : null;
  final signedDecision =
      evidence is Map ? evidence['decision']?.toString() : null;
  final hasCompleteSignedEvidence =
      signedRisk != null && signedScore != null && signedDecision != null;

  if (hasCompleteSignedEvidence) {
    return HCVDisplayRiskClaimValues(
      risk: signedRisk,
      score: signedScore,
      decision: signedDecision,
      requiresLegacyNormalization: false,
    );
  }

  return HCVDisplayRiskClaimValues(
    risk: claims['screenReplayRisk']?.toString(),
    score: claims['screenReplayRiskScore']?.toString(),
    decision: claims['displayRiskDecision']?.toString(),
    requiresLegacyNormalization: true,
  );
}

class RegistryVerifyPage extends ProductionRegistryVerifyPage {
  const RegistryVerifyPage({
    super.key,
    super.initialMediaPath,
    super.languageCode = 'it',
  });
}
