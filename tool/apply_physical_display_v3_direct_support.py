from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"Expected exactly one match in {path}: {text.count(old)}")
    path.write_text(text.replace(old, new, 1))


probe = Path('lib/hcv_display_microtexture_probe.dart')
replace_once(
    probe,
    "  static const double passiveMotionRejectionThreshold = 0.08;\n",
    "  static const double passiveMotionRejectionThreshold = 0.08;\n"
    "  static const double activeProbeMotionRejectionThreshold = 0.08;\n",
)
replace_once(
    probe,
    "        results[id] = {...phase, ..._phaseMetrics(frames)};\n",
    "        final metrics = _phaseMetrics(frames);\n"
    "        final sceneMotionScore = _sceneMotionScore(frames);\n"
    "        final motionRejectedForActiveDecision =\n"
    "            sceneMotionScore > activeProbeMotionRejectionThreshold;\n"
    "        results[id] = {\n"
    "          ...phase,\n"
    "          'sceneMotionScore': sceneMotionScore,\n"
    "          'motionRejectedForActiveDecision':\n"
    "              motionRejectedForActiveDecision,\n"
    "          'usableForActivePhysicalDecision':\n"
    "              !motionRejectedForActiveDecision,\n"
    "          ...metrics,\n"
    "        };\n",
)
replace_once(
    probe,
    "        'spatialPolicy': capture?['spatialPolicy'],\n",
    "        'activeMotionPolicy': const {\n"
    "          'method': 'GLOBAL_LUMA_DELTA_REMOVED_RESIDUAL_MOTION_SCORE_V1',\n"
    "          'rejectionThreshold': activeProbeMotionRejectionThreshold,\n"
    "          'rejectedShort1xCannotDriveDisplayDecision': true,\n"
    "        },\n"
    "        'spatialPolicy': capture?['spatialPolicy'],\n",
)

Path('lib/hcv_physical_display_discriminator.dart').write_text(r'''import 'dart:math';

import 'hcv_display_risk_fusion.dart';

class HCVPhysicalDisplayDiscriminator {
  const HCVPhysicalDisplayDiscriminator._();

  static const double displayMeanThreshold = 0.36;
  static const double displayMinCellThreshold = 0.235;
  static const double realityMeanThreshold = 0.31;
  static const double realityMinCellThreshold = 0.22;
  static const double minimumDisplayLumaCompensationRatio = 0.60;
  static const double activeProbeMotionRejectionThreshold = 0.08;
  static const double directCellMinimumRowColumnRatio = 1.40;
  static const double directCellMinimumLatticeScore = 0.92;
  static const double directCellMaximumHighFrequencyLumaEnergy = 0.03;

  static Map<String, dynamic> _directDisplayCellSupport(Map rawCell) {
    final cell = Map<String, dynamic>.from(rawCell);
    final axis =
        (cell['structuredTemporalAxisRatio'] as num?)?.toDouble();
    final row = (cell['rowTemporalCoherence'] as num?)?.toDouble();
    final column =
        (cell['columnTemporalCoherence'] as num?)?.toDouble();
    final lattice = (cell['flatFieldLatticeScore'] as num?)?.toDouble();
    final highFrequencyLuma =
        (cell['highFrequencyLumaEnergy'] as num?)?.toDouble();
    final rowColumnRatio = row == null || column == null
        ? null
        : row / max(1e-6, column);

    final temporalSupport =
        axis != null && axis >= displayMinCellThreshold;
    final directionalRefreshSupport = rowColumnRatio != null &&
        rowColumnRatio >= directCellMinimumRowColumnRatio;
    final latticeEmissionSupport = lattice != null &&
        highFrequencyLuma != null &&
        lattice >= directCellMinimumLatticeScore &&
        highFrequencyLuma <= directCellMaximumHighFrequencyLumaEnergy;
    final directSupport = temporalSupport &&
        (directionalRefreshSupport || latticeEmissionSupport);

    return {
      'row': cell['row'],
      'column': cell['column'],
      'directDisplaySupport': directSupport,
      'temporalSupport': temporalSupport,
      'directionalRefreshSupport': directionalRefreshSupport,
      'latticeEmissionSupport': latticeEmissionSupport,
      'structuredTemporalAxisRatio': axis,
      'rowColumnTemporalCoherenceRatio': rowColumnRatio,
      'flatFieldLatticeScore': lattice,
      'highFrequencyLumaEnergy': highFrequencyLuma,
    };
  }

  static Map<String, dynamic> evaluate(Map<String, dynamic>? analysis) {
    final phaseResultsRaw = analysis?['phaseResults'];
    final phaseResults = phaseResultsRaw is Map
        ? Map<String, dynamic>.from(phaseResultsRaw)
        : const <String, dynamic>{};
    final shortRaw = phaseResults['SHORT_1X'];
    final short = shortRaw is Map
        ? Map<String, dynamic>.from(shortRaw)
        : const <String, dynamic>{};

    final mean = (short['structuredTemporalAxisRatio'] as num?)?.toDouble();
    final minCell =
        (short['minimumCellStructuredTemporalAxisRatio'] as num?)?.toDouble();
    final cells = (short['cellsAnalyzed'] as num?)?.toInt() ?? 0;
    final rawCells = short['cells'];
    final directCellResults = rawCells is List
        ? rawCells
            .whereType<Map>()
            .map(_directDisplayCellSupport)
            .toList()
        : <Map<String, dynamic>>[];
    final directDisplayCellCount = directCellResults
        .where((cell) => cell['directDisplaySupport'] == true)
        .length;
    final directDisplayCoverageConfirmed =
        directCellResults.length == 9 && directDisplayCellCount == 9;

    final comparisonsRaw = analysis?['comparisons'];
    final comparisons = comparisonsRaw is Map
        ? Map<String, dynamic>.from(comparisonsRaw)
        : const <String, dynamic>{};
    final lumaCompensationRatio =
        (comparisons['shortExposureLumaCompensationRatio1x'] as num?)
            ?.toDouble();
    final isoCompensationClamped =
        comparisons['isoCompensationClamped1x'] == true;
    final sceneMotionScore =
        (short['sceneMotionScore'] as num?)?.toDouble();
    final activeMotionRejected =
        short['motionRejectedForActiveDecision'] == true ||
            (sceneMotionScore != null &&
                sceneMotionScore > activeProbeMotionRejectionThreshold);
    final activeMotionQualitySufficient =
        sceneMotionScore != null && !activeMotionRejected;

    if (mean == null || minCell == null || cells < 9) {
      return {
        'type': 'SIGILLUM_PHYSICAL_DISPLAY_DISCRIMINATOR_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'decision': 'INDETERMINATE',
        'reason': 'SHORT_1X_9_CELL_METRICS_UNAVAILABLE',
        'thresholds': thresholds,
      };
    }

    final displayThresholdsPassed =
        mean >= displayMeanThreshold && minCell >= displayMinCellThreshold;
    final displayMeasurementQualitySufficient = lumaCompensationRatio != null &&
        lumaCompensationRatio >= minimumDisplayLumaCompensationRatio;
    final display = displayThresholdsPassed &&
        displayMeasurementQualitySufficient &&
        activeMotionQualitySufficient &&
        directDisplayCoverageConfirmed;
    final reality = activeMotionQualitySufficient &&
        mean <= realityMeanThreshold &&
        minCell <= realityMinCellThreshold;

    return {
      'type': 'SIGILLUM_PHYSICAL_DISPLAY_DISCRIMINATOR_V1',
      'analysisStatus': 'ANALYZED',
      'decision': display
          ? 'DISPLAY_CONFIRMED'
          : reality
              ? 'REALITY_SUPPORTED'
              : 'INDETERMINATE',
      'short1xMeanStructuredTemporalAxisRatio': mean,
      'short1xMinimumCellStructuredTemporalAxisRatio': minCell,
      'cellsAnalyzed': cells,
      'shortExposureLumaCompensationRatio1x': lumaCompensationRatio,
      'isoCompensationClamped1x': isoCompensationClamped,
      'short1xSceneMotionScore': sceneMotionScore,
      'activeMotionRejected': activeMotionRejected,
      'activeMotionQualitySufficient': activeMotionQualitySufficient,
      'directDisplayCellCount': directDisplayCellCount,
      'directDisplayCoverageConfirmed': directDisplayCoverageConfirmed,
      'directDisplayCellResults': directCellResults,
      'displayThresholdsPassed': displayThresholdsPassed,
      'displayMeasurementQualitySufficient':
          displayMeasurementQualitySufficient,
      'displayBlockedByExposureQuality':
          displayThresholdsPassed && !displayMeasurementQualitySufficient,
      'displayBlockedByMotion': displayThresholdsPassed && activeMotionRejected,
      'displayBlockedByDirectCellCoverage': displayThresholdsPassed &&
          displayMeasurementQualitySufficient &&
          activeMotionQualitySufficient &&
          !directDisplayCoverageConfirmed,
      'thresholds': thresholds,
      'policy': const {
        'requiredDisplayCoverageCells': 9,
        'allowedRealityEscapeCells': 0,
        'displayRequiresBothThresholds': true,
        'displayRequiresExposureQuality': true,
        'displayRequiresActiveMotionQuality': true,
        'displayRequiresDirectCellCoverage9of9': true,
        'realityRequiresBothThresholds': true,
      },
    };
  }

  static Map<String, dynamic>? analysisFromPhotoTemporalProbe(
    Map<String, dynamic>? temporalProbe,
  ) {
    final physicalRaw = temporalProbe?['displayMicrotextureShadowProbe'];
    if (physicalRaw is! Map) return null;
    final analysisRaw = physicalRaw['analysis'];
    if (analysisRaw is! Map) return null;
    return Map<String, dynamic>.from(analysisRaw);
  }

  static HCVDisplayRiskResult _normalizeLegacyLiveProbeReason(
    HCVDisplayRiskResult base,
    Map<String, dynamic> physical,
  ) {
    if (physical['analysisStatus'] != 'ANALYZED') return base;
    final reasons = base.reasons.where((r) => r != 'LIVE_PROBE_MISSING').toSet();
    reasons.add('ACTIVE_PHYSICAL_PROBE_REPLACES_LEGACY_LIVE_PROBE');
    final hasOtherMissing = reasons.any((reason) => reason.endsWith('_MISSING'));
    return HCVDisplayRiskResult(
      risk: base.risk,
      score: base.score,
      decision: base.decision,
      analysisStatus: base.analysisStatus == 'PARTIAL' && !hasOtherMissing
          ? 'COMPLETE'
          : base.analysisStatus,
      evidenceSources: base.evidenceSources,
      strongSources: base.strongSources,
      reasons: reasons.toList(),
    );
  }

  static bool _mlOnlyStrong(HCVDisplayRiskResult result) =>
      result.strongSources.isNotEmpty &&
      result.strongSources.every((source) => source == 'ML_SCREEN_CLASS');

  static HCVDisplayRiskResult _downgradeToConflict(
    HCVDisplayRiskResult base,
    String reason,
  ) {
    final reasons = <String>{...base.reasons, reason}.toList();
    return HCVDisplayRiskResult(
      risk: 'MEDIUM',
      score: base.score.clamp(45, 69).toInt(),
      decision: 'NON_CONCLUSIVE',
      analysisStatus: base.analysisStatus,
      evidenceSources: base.evidenceSources,
      strongSources: base.strongSources,
      reasons: reasons,
    );
  }

  static HCVDisplayRiskResult apply({
    required HCVDisplayRiskResult base,
    required Map<String, dynamic>? physicalAnalysis,
  }) {
    final physical = evaluate(physicalAnalysis);
    final normalizedBase = _normalizeLegacyLiveProbeReason(base, physical);
    final decision = physical['decision']?.toString() ?? 'INDETERMINATE';

    if (decision == 'DISPLAY_CONFIRMED') {
      final evidenceSources = <String>{
        ...normalizedBase.evidenceSources,
        'PHYSICAL_SHORT_1X_3X3',
        'PHYSICAL_DIRECT_DISPLAY_9_OF_9',
      }.toList()
        ..sort();
      final strongSources = <String>{
        ...normalizedBase.strongSources,
        'PHYSICAL_SHORT_1X_3X3',
        'PHYSICAL_DIRECT_DISPLAY_9_OF_9',
      }.toList()
        ..sort();
      final reasons = <String>{
        ...normalizedBase.reasons,
        'PHYSICAL_SHORT_1X_DIRECT_EMISSION_9_OF_9_DISPLAY_CONFIRMED',
      }.toList();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: normalizedBase.score < 90 ? 90 : normalizedBase.score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources,
        strongSources: strongSources,
        reasons: reasons,
      );
    }

    if (decision == 'REALITY_SUPPORTED' &&
        normalizedBase.decision == 'STRONG_DISPLAY_RISK' &&
        _mlOnlyStrong(normalizedBase)) {
      return _downgradeToConflict(
        normalizedBase,
        'PHYSICAL_REALITY_CONFLICTS_WITH_ML_ONLY_DISPLAY',
      );
    }

    if (decision == 'REALITY_SUPPORTED' &&
        normalizedBase.decision == 'NON_CONCLUSIVE') {
      final evidenceSources = <String>{
        ...normalizedBase.evidenceSources,
        'PHYSICAL_SHORT_1X_3X3',
      }.toList()
        ..sort();
      final reasons = <String>{
        ...normalizedBase.reasons,
        'PHYSICAL_SHORT_1X_REALITY_RESOLVES_NON_CONCLUSIVE',
      }.toList();
      return HCVDisplayRiskResult(
        risk: 'LOW',
        score: normalizedBase.score.clamp(0, 20).toInt(),
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources,
        strongSources: normalizedBase.strongSources,
        reasons: reasons,
      );
    }

    final photoVideoEquivalentMlOnly =
        normalizedBase.decision == 'STRONG_DISPLAY_RISK' &&
            normalizedBase.reasons.contains('PHOTO_VIDEO_EQUIVALENT_METHOD') &&
            _mlOnlyStrong(normalizedBase);
    if (photoVideoEquivalentMlOnly) {
      return _downgradeToConflict(
        normalizedBase,
        'PHOTO_VIDEO_EQUIVALENT_REQUIRES_PHYSICAL_DISPLAY_CONFIRMATION',
      );
    }

    return normalizedBase;
  }

  static const Map<String, dynamic> thresholds = {
    'displayMeanThreshold': displayMeanThreshold,
    'displayMinCellThreshold': displayMinCellThreshold,
    'realityMeanThreshold': realityMeanThreshold,
    'realityMinCellThreshold': realityMinCellThreshold,
    'minimumDisplayLumaCompensationRatio': minimumDisplayLumaCompensationRatio,
    'activeProbeMotionRejectionThreshold': activeProbeMotionRejectionThreshold,
    'directCellMinimumRowColumnRatio': directCellMinimumRowColumnRatio,
    'directCellMinimumLatticeScore': directCellMinimumLatticeScore,
    'directCellMaximumHighFrequencyLumaEnergy':
        directCellMaximumHighFrequencyLumaEnergy,
    'source': 'BUILD_84_13_PACK_PLUS_PRIOR_6_PACK_2026_09_04',
    'status': 'ACTIVE_V3_DIRECT_CELL_AND_MOTION_GATED',
  };
}
''')

Path('test/hcv_physical_display_discriminator_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
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

  test('photo video-equivalent ML-only strong requires physical confirmation', () {
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

  test('reality support does not veto independently corroborated strong display', () {
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
''')

print('PHYSICAL_DISPLAY_V3_DIRECT_SUPPORT_PATCH_APPLIED')
