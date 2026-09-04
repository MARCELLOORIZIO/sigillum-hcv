import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_physical_display_discriminator.dart';

HCVDisplayRiskResult _base(
  String decision, {
  int score = 45,
  List<String>? strongSources,
  List<String>? reasons,
  String analysisStatus = 'COMPLETE',
}) {
  return HCVDisplayRiskResult(
    risk: decision == 'STRONG_DISPLAY_RISK'
        ? 'HIGH'
        : decision == 'NON_CONCLUSIVE'
            ? 'MEDIUM'
            : 'LOW',
    score: score,
    decision: decision,
    analysisStatus: analysisStatus,
    evidenceSources: const ['BASE'],
    strongSources: strongSources ??
        (decision == 'STRONG_DISPLAY_RISK' ? const ['BASE'] : const []),
    reasons: reasons ?? const ['BASE_REASON'],
  );
}

Map<String, dynamic> _directCell(
  double axis, {
  double row = 0.30,
  double column = 0.15,
  double lattice = 0.50,
  double highFrequencyLuma = 0.05,
  int gridRow = 0,
  int gridColumn = 0,
}) =>
    {
      'row': gridRow,
      'column': gridColumn,
      'structuredTemporalAxisRatio': axis,
      'rowTemporalCoherence': row,
      'columnTemporalCoherence': column,
      'flatFieldLatticeScore': lattice,
      'highFrequencyLumaEnergy': highFrequencyLuma,
    };

Map<String, dynamic> _analysis(
  double mean,
  double minCell, {
  double lumaCompensationRatio = 1.0,
  bool isoCompensationClamped = false,
  double sceneMotionScore = 0.0,
  List<Map<String, dynamic>>? cells,
}) {
  final cellList = cells ??
      List.generate(
        9,
        (index) => _directCell(
          minCell,
          gridRow: index ~/ 3,
          gridColumn: index % 3,
        ),
      );
  return {
    'analysisStatus': 'ANALYZED',
    'phaseResults': {
      'SHORT_1X': {
        'structuredTemporalAxisRatio': mean,
        'minimumCellStructuredTemporalAxisRatio': minCell,
        'cellsAnalyzed': 9,
        'sceneMotionScore': sceneMotionScore,
        'motionRejectedForActiveDecision': sceneMotionScore > 0.08,
        'cells': cellList,
      },
    },
    'comparisons': {
      'shortExposureLumaCompensationRatio1x': lumaCompensationRatio,
      'isoCompensationClamped1x': isoCompensationClamped,
    },
  };
}

void main() {
  test('display corpus-side values promote strong display', () {
    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: _base('NO_DISPLAY_EVIDENCE', score: 20),
      physicalAnalysis: _analysis(0.423, 0.250),
    );
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, greaterThanOrEqualTo(90));
    expect(result.strongSources, contains('PHYSICAL_DIRECT_DISPLAY_9_OF_9'));
  });

  test('weak full-display cell can pass via lattice emission path', () {
    final cells = List.generate(
      9,
      (index) => _directCell(
        0.270,
        gridRow: index ~/ 3,
        gridColumn: index % 3,
      ),
    );
    cells[7] = _directCell(
      0.285,
      row: 0.210,
      column: 0.192,
      lattice: 0.976,
      highFrequencyLuma: 0.005,
      gridRow: 2,
      gridColumn: 1,
    );
    final evaluated = HCVPhysicalDisplayDiscriminator.evaluate(
      _analysis(0.413, 0.261, cells: cells),
    );
    expect(evaluated['directDisplayCellCount'], 9);
    expect(evaluated['decision'], 'DISPLAY_CONFIRMED');
  });

  test('mixed-scene reality escape blocks 9 of 9 display confirmation', () {
    final cells = List.generate(
      9,
      (index) => _directCell(
        0.500,
        gridRow: index ~/ 3,
        gridColumn: index % 3,
      ),
    );
    cells[8] = _directCell(
      0.308,
      row: 0.239,
      column: 0.191,
      lattice: 0.872,
      highFrequencyLuma: 0.003,
      gridRow: 2,
      gridColumn: 2,
    );
    final evaluated = HCVPhysicalDisplayDiscriminator.evaluate(
      _analysis(0.592, 0.308, cells: cells),
    );
    expect(evaluated['directDisplayCellCount'], 8);
    expect(evaluated['directDisplayCoverageConfirmed'], false);
    expect(evaluated['displayBlockedByDirectCellCoverage'], true);
    expect(evaluated['decision'], 'INDETERMINATE');
  });

  test('active probe motion blocks physical display promotion', () {
    final evaluated = HCVPhysicalDisplayDiscriminator.evaluate(
      _analysis(0.550, 0.286, sceneMotionScore: 0.11),
    );
    expect(evaluated['activeMotionRejected'], true);
    expect(evaluated['displayBlockedByMotion'], true);
    expect(evaluated['decision'], 'INDETERMINATE');
  });

  test('severe short-exposure undercompensation blocks display promotion', () {
    final physical = _analysis(
      0.500,
      0.300,
      lumaCompensationRatio: 0.40,
      isoCompensationClamped: true,
    );
    final evaluated = HCVPhysicalDisplayDiscriminator.evaluate(physical);
    expect(evaluated['decision'], 'INDETERMINATE');
    expect(evaluated['displayThresholdsPassed'], true);
    expect(evaluated['displayBlockedByExposureQuality'], true);

    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: _base('NO_DISPLAY_EVIDENCE', score: 20),
      physicalAnalysis: physical,
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
  });

  test('physical reality conflicts with ML-only display as non-conclusive', () {
    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: _base(
        'STRONG_DISPLAY_RISK',
        score: 75,
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: const ['ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY'],
      ),
      physicalAnalysis: _analysis(0.285, 0.212),
    );
    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.score, inInclusiveRange(45, 69));
    expect(
      result.reasons,
      contains('PHYSICAL_REALITY_CONFLICTS_WITH_ML_ONLY_DISPLAY'),
    );
  });

  test('photo video-equivalent ML-only strong requires physical confirmation',
      () {
    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: _base(
        'STRONG_DISPLAY_RISK',
        score: 75,
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: const [
          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
          'LIVE_PROBE_MISSING',
          'PHOTO_VIDEO_EQUIVALENT_METHOD',
        ],
        analysisStatus: 'PARTIAL',
      ),
      physicalAnalysis: _analysis(
        0.313,
        0.234,
        lumaCompensationRatio: 0.46,
      ),
    );
    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.reasons, isNot(contains('LIVE_PROBE_MISSING')));
    expect(
      result.reasons,
      contains('ACTIVE_PHYSICAL_PROBE_REPLACES_LEGACY_LIVE_PROBE'),
    );
    expect(
      result.reasons,
      contains('PHOTO_VIDEO_EQUIVALENT_REQUIRES_PHYSICAL_DISPLAY_CONFIRMATION'),
    );
    expect(result.analysisStatus, 'COMPLETE');
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

  test(
      'reality support does not veto independently corroborated strong display',
      () {
    final result = HCVPhysicalDisplayDiscriminator.apply(
      base: _base(
        'STRONG_DISPLAY_RISK',
        score: 98,
        strongSources: const ['STATIC_OPTICAL', 'ML_SCREEN_CLASS'],
      ),
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
