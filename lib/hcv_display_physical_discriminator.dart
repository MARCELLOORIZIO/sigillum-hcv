class HCVDisplayPhysicalDiscriminator {
  const HCVDisplayPhysicalDiscriminator();

  // Calibrated from the first BUILD 82 physical corpus. The gap observed in
  // SHORT_1X was reality mean <= 0.285 / min-cell <= 0.212 versus display
  // mean >= 0.423 / min-cell >= 0.250. Production activation deliberately
  // keeps a dead-band between the two classes instead of using the midpoint as
  // one hard threshold.
  static const double displayMeanThreshold = 0.36;
  static const double displayMinCellThreshold = 0.23;
  static const double realityMeanThreshold = 0.30;
  static const double realityMinCellThreshold = 0.22;
  static const int requiredCells = 9;

  static Map<String, dynamic> evaluate(
    Map<String, dynamic>? microtextureAnalysis, {
    required String source,
  }) {
    final phaseResultsRaw = microtextureAnalysis?['phaseResults'];
    final phaseResults = phaseResultsRaw is Map ? phaseResultsRaw : null;
    final shortRaw = phaseResults?['SHORT_1X'];
    final short = shortRaw is Map ? shortRaw : null;

    final mean = (short?['structuredTemporalAxisRatio'] as num?)?.toDouble();
    final minCell = (short?['minimumCellStructuredTemporalAxisRatio'] as num?)
        ?.toDouble();
    final cells = (short?['cellsAnalyzed'] as num?)?.toInt() ?? 0;
    final frames = (short?['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final shortStatus = short?['analysisStatus']?.toString() ?? 'NOT_ANALYZED';

    final analyzable =
        microtextureAnalysis?['analysisStatus'] == 'ANALYZED' &&
        short != null &&
        shortStatus != 'NOT_ANALYZED' &&
        mean != null &&
        minCell != null &&
        cells == requiredCells;

    if (!analyzable) {
      return {
        'type': 'SIGILLUM_DISPLAY_PHYSICAL_DISCRIMINATOR_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'physicalDecision': 'PHYSICAL_INDETERMINATE',
        'decisionRole': 'ACTIVE_PHYSICAL_DISPLAY_DISCRIMINATOR',
        'source': source,
        'requiredCoverageCells': requiredCells,
        'cellsAnalyzed': cells,
        'framesAnalyzed': frames,
        'reason': 'SHORT_1X_9_CELL_EVIDENCE_UNAVAILABLE',
      };
    }

    final displayConfirmed =
        mean >= displayMeanThreshold && minCell >= displayMinCellThreshold;
    final realityConfirmed =
        mean <= realityMeanThreshold && minCell <= realityMinCellThreshold;

    final decision = displayConfirmed
        ? 'PHYSICAL_DISPLAY_CONFIRMED'
        : realityConfirmed
        ? 'PHYSICAL_REALITY_CONFIRMED'
        : 'PHYSICAL_INDETERMINATE';

    return {
      'type': 'SIGILLUM_DISPLAY_PHYSICAL_DISCRIMINATOR_V1',
      'analysisStatus': 'ANALYZED',
      'physicalDecision': decision,
      'decisionRole': 'ACTIVE_PHYSICAL_DISPLAY_DISCRIMINATOR',
      'source': source,
      'short1xStructuredTemporalAxisRatio': mean,
      'short1xMinimumCellStructuredTemporalAxisRatio': minCell,
      'cellsAnalyzed': cells,
      'framesAnalyzed': frames,
      'requiredCoverageCells': requiredCells,
      'allowedRealityEscapeCells': 0,
      'thresholds': const {
        'displayMeanMin': displayMeanThreshold,
        'displayMinCellMin': displayMinCellThreshold,
        'realityMeanMax': realityMeanThreshold,
        'realityMinCellMax': realityMinCellThreshold,
      },
      'reason': displayConfirmed
          ? 'SHORT_1X_FULL_FRAME_9_CELL_DISPLAY_SIGNATURE'
          : realityConfirmed
          ? 'SHORT_1X_REALITY_SIGNATURE'
          : 'SHORT_1X_DEAD_BAND_INDETERMINATE',
    };
  }
}
