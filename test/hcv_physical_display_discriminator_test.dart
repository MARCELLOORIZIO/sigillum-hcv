import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_physical_display_discriminator.dart';

HCVDisplayRiskResult _base(String decision, {int score = 45}) {
  return HCVDisplayRiskResult(
    risk: decision == 'STRONG_DISPLAY_RISK' ? 'HIGH' : 'MEDIUM',
    score: score,
    decision: decision,
    analysisStatus: 'COMPLETE',
    evidenceSources: const ['BASE'],
    strongSources:
        decision == 'STRONG_DISPLAY_RISK' ? const ['BASE'] : const [],
    reasons: const ['BASE_REASON'],
  );
}

Map<String, dynamic> _analysis(double mean, double minCell) => {
      'analysisStatus': 'ANALYZED',
      'phaseResults': {
        'SHORT_1X': {
          'structuredTemporalAxisRatio': mean,
          'minimumCellStructuredTemporalAxisRatio': minCell,
          'cellsAnalyzed': 9,
        },
      },
    };

void main() {
  test('display corpus-side values promote strong display', () {
    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: _base('NO_DISPLAY_EVIDENCE', score: 20),
      physicalAnalysis: _analysis(0.423, 0.250),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, greaterThanOrEqualTo(90));
    expect(result.strongSources, contains('PHYSICAL_SHORT_1X_3X3'));
  });

  test('reality corpus-side values resolve non-conclusive', () {
    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: _base('NON_CONCLUSIVE'),
      physicalAnalysis: _analysis(0.285, 0.212),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, lessThanOrEqualTo(20));
  });

  test('indeterminate band leaves base decision unchanged', () {
    final base = _base('NON_CONCLUSIVE');
    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: base,
      physicalAnalysis: _analysis(0.335, 0.230),
    );
    expect(result.decision, base.decision);
    expect(result.score, base.score);
  });

  test('reality support never vetoes an existing strong display decision', () {
    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: _base('STRONG_DISPLAY_RISK', score: 98),
      physicalAnalysis: _analysis(0.200, 0.180),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, 98);
  });

  test('requires all nine cells', () {
    final physical = _analysis(0.500, 0.300);
    (physical['phaseResults']['SHORT_1X']
        as Map<String, dynamic>)['cellsAnalyzed'] = 8;
    final result = HCVPhysicalDisplayDiscriminator.evaluate(physical);
    expect(result['decision'], 'INDETERMINATE');
    expect(result['analysisStatus'], 'NOT_ANALYZED');
  });
}
