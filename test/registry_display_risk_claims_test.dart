import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/registry_verify_page.dart';

void main() {
  group('resolveHCVDisplayRiskClaimValues', () {
    test('signed capture evidence overrides conflicting legacy claims', () {
      final result = resolveHCVDisplayRiskClaimValues({
        'screenReplayRisk': 'LOW',
        'screenReplayRiskScore': 20,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'displayRiskEvidence': {
          'risk': 'MEDIUM',
          'score': 55,
          'decision': 'NON_CONCLUSIVE',
        },
      });

      expect(result.risk, 'MEDIUM');
      expect(result.score, '55');
      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.requiresLegacyNormalization, isFalse);
    });

    test('legacy claims request normalization when signed evidence is absent', () {
      final result = resolveHCVDisplayRiskClaimValues({
        'screenReplayRisk': 'HIGH',
        'screenReplayRiskScore': 70,
        'displayRiskDecision': 'STRONG_DISPLAY_RISK',
      });

      expect(result.risk, 'HIGH');
      expect(result.score, '70');
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.requiresLegacyNormalization, isTrue);
    });

    test('incomplete evidence is treated as legacy', () {
      final result = resolveHCVDisplayRiskClaimValues({
        'screenReplayRisk': 'LOW',
        'screenReplayRiskScore': 20,
        'displayRiskDecision': 'NO_DISPLAY_EVIDENCE',
        'displayRiskEvidence': {
          'risk': 'MEDIUM',
          'score': 55,
        },
      });

      expect(result.risk, 'LOW');
      expect(result.score, '20');
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.requiresLegacyNormalization, isTrue);
    });
  });
}
