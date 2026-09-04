import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_physical_discriminator.dart';

Map<String, dynamic> analysis(double mean, double minCell) => {
  'analysisStatus': 'ANALYZED',
  'phaseResults': {
    'SHORT_1X': {
      'analysisStatus': 'ANALYZED',
      'structuredTemporalAxisRatio': mean,
      'minimumCellStructuredTemporalAxisRatio': minCell,
      'cellsAnalyzed': 9,
      'framesAnalyzed': 6,
    },
  },
};

void main() {
  test('BUILD 82 display floor is physically confirmed', () {
    final result = HCVDisplayPhysicalDiscriminator.evaluate(
      analysis(0.423, 0.250),
      source: 'TEST',
    );
    expect(result['physicalDecision'], 'PHYSICAL_DISPLAY_CONFIRMED');
  });

  test('BUILD 82 reality ceiling is physically confirmed', () {
    final result = HCVDisplayPhysicalDiscriminator.evaluate(
      analysis(0.285, 0.212),
      source: 'TEST',
    );
    expect(result['physicalDecision'], 'PHYSICAL_REALITY_CONFIRMED');
  });

  test('dead band remains non decisional', () {
    final result = HCVDisplayPhysicalDiscriminator.evaluate(
      analysis(0.33, 0.225),
      source: 'TEST',
    );
    expect(result['physicalDecision'], 'PHYSICAL_INDETERMINATE');
  });

  test('nine cell coverage is mandatory', () {
    final raw = analysis(0.60, 0.40);
    (raw['phaseResults']['SHORT_1X'] as Map<String, dynamic>)['cellsAnalyzed'] =
        8;
    final result = HCVDisplayPhysicalDiscriminator.evaluate(
      raw,
      source: 'TEST',
    );
    expect(result['physicalDecision'], 'PHYSICAL_INDETERMINATE');
    expect(result['analysisStatus'], 'NOT_ANALYZED');
  });
}
