from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:180]!r}')
    if text.count(old) != 1:
        raise SystemExit(f'pattern not unique in {path}: {text.count(old)}')
    p.write_text(text.replace(old, new, 1))


# 1) Physical acquisition/analysis: record real luminance compensation and
# reject motion-contaminated passive video windows before aggregation.
probe = 'lib/hcv_display_microtexture_probe.dart'
replace_once(
    probe,
    "  static const double _requestedShortExposure = 1.0 / 240.0;\n",
    "  static const double _requestedShortExposure = 1.0 / 240.0;\n"
    "  static const double passiveMotionRejectionThreshold = 0.08;\n",
)

replace_once(
    probe,
    """      double? structured(String id) =>
          (results[id]?['structuredTemporalAxisRatio'] as num?)?.toDouble();

      return {
""",
    """      double? structured(String id) =>
          (results[id]?['structuredTemporalAxisRatio'] as num?)?.toDouble();
      double? phaseMeanLuma(String id) =>
          (results[id]?['meanFrameLuma'] as num?)?.toDouble();

      final normal1xLuma = phaseMeanLuma('NORMAL_1X');
      final short1xLuma = phaseMeanLuma('SHORT_1X');
      final shortExposureLumaCompensationRatio1x =
          _gain(short1xLuma, normal1xLuma);
      final shortStateRaw = results['SHORT_1X']?['exposureState'];
      final shortState = shortStateRaw is Map
          ? Map<String, dynamic>.from(shortStateRaw)
          : const <String, dynamic>{};
      final shortIso = (shortState['iso'] as num?)?.toDouble();
      final maxIso = (shortState['maxISO'] as num?)?.toDouble();
      final isoCompensationClamped1x = shortIso != null &&
          maxIso != null &&
          shortIso >= maxIso - 0.5;

      return {
""",
)

replace_once(
    probe,
    """        'comparisons': {
          'shortExposureGain1x': _gain(
""",
    """        'comparisons': {
          'shortExposureLumaCompensationRatio1x':
              shortExposureLumaCompensationRatio1x,
          'isoCompensationClamped1x': isoCompensationClamped1x,
          'normal1xMeanFrameLuma': normal1xLuma,
          'short1xMeanFrameLuma': short1xLuma,
          'shortExposureGain1x': _gain(
""",
)

replace_once(
    probe,
    """        final metrics = _phaseMetrics(frames);
        if (metrics['analysisStatus'] == 'NOT_ANALYZED') continue;
        windows.add({
          'windowIndex': i,
          'startMs': startMs,
          'endMs': endMs,
          ...metrics,
        });
""",
    """        final metrics = _phaseMetrics(frames);
        if (metrics['analysisStatus'] == 'NOT_ANALYZED') continue;
        final sceneMotionScore = _sceneMotionScore(frames);
        final motionRejected =
            sceneMotionScore > passiveMotionRejectionThreshold;
        windows.add({
          'windowIndex': i,
          'startMs': startMs,
          'endMs': endMs,
          'sceneMotionScore': sceneMotionScore,
          'motionRejected': motionRejected,
          'usableForPassivePhysicalCorroboration': !motionRejected,
          ...metrics,
        });
""",
)

replace_once(
    probe,
    """      final meanAxis = windows
          .map(
""",
    """      final usableWindows = windows
          .where(
            (window) =>
                window['usableForPassivePhysicalCorroboration'] == true,
          )
          .toList();
      final meanAxis = usableWindows
          .map(
""",
)
replace_once(
    probe,
    """      final minimumCells = windows
          .map(
""",
    """      final minimumCells = usableWindows
          .map(
""",
)
replace_once(
    probe,
    """        'analysisStatus': windows.isEmpty ? 'NOT_ANALYZED' : 'ANALYZED',
""",
    """        'analysisStatus': windows.isEmpty
            ? 'NOT_ANALYZED'
            : usableWindows.isEmpty
                ? 'PARTIAL'
                : 'ANALYZED',
""",
)
replace_once(
    probe,
    """        'windowsAnalyzed': windows.length,
        'firstWindowStartMs': starts.isEmpty ? null : starts.first,
""",
    """        'windowsAnalyzed': windows.length,
        'windowsUsedForPhysicalCorroboration': usableWindows.length,
        'windowsRejectedForMotion': windows.length - usableWindows.length,
        'firstWindowStartMs': starts.isEmpty ? null : starts.first,
""",
)
replace_once(
    probe,
    """        'zoomChangedDuringRecordedVideo': false,
        'spatialPolicy': const {
""",
    """        'zoomChangedDuringRecordedVideo': false,
        'motionPolicy': const {
          'method': 'GLOBAL_LUMA_DELTA_REMOVED_RESIDUAL_MOTION_SCORE_V1',
          'rejectionThreshold': passiveMotionRejectionThreshold,
          'rejectedWindowsExcludedFromAggregateMetrics': true,
        },
        'spatialPolicy': const {
""",
)
replace_once(
    probe,
    """      'flatFieldLatticeScore': _mean(lattice),
      'cells': cells,
""",
    """      'flatFieldLatticeScore': _mean(lattice),
      'meanFrameLuma': _meanFrameLuma(frames),
      'cells': cells,
""",
)

replace_once(
    probe,
    """  double _autocorrelationPeak(List<double> values) {
""",
    """  double sceneMotionScoreForFrames(List<img.Image> frames) =>
      _sceneMotionScore(frames);

  double _sceneMotionScore(List<img.Image> frames) {
    if (frames.length < 2) return 0.0;
    final pairScores = <double>[];
    for (var i = 1; i < frames.length; i++) {
      final a = frames[i - 1];
      final b = frames[i];
      final width = min(a.width, b.width);
      final height = min(a.height, b.height);
      final step = max(4, min(width, height) ~/ 96);
      var globalDelta = 0.0;
      var samples = 0;
      for (var y = 0; y < height; y += step) {
        for (var x = 0; x < width; x += step) {
          globalDelta += _luma(b.getPixel(x, y)) - _luma(a.getPixel(x, y));
          samples++;
        }
      }
      if (samples == 0) continue;
      globalDelta /= samples;
      var residual = 0.0;
      var residualSamples = 0;
      for (var y = 0; y < height; y += step) {
        for (var x = 0; x < width; x += step) {
          final delta =
              _luma(b.getPixel(x, y)) - _luma(a.getPixel(x, y)) - globalDelta;
          residual += delta.abs();
          residualSamples++;
        }
      }
      if (residualSamples > 0) {
        pairScores.add(residual / residualSamples);
      }
    }
    pairScores.sort();
    return _median(pairScores) ?? 0.0;
  }

  double _meanFrameLuma(List<img.Image> frames) {
    if (frames.isEmpty) return 0.0;
    var total = 0.0;
    var samples = 0;
    for (final frame in frames) {
      final step = max(4, min(frame.width, frame.height) ~/ 160);
      for (var y = 0; y < frame.height; y += step) {
        for (var x = 0; x < frame.width; x += step) {
          total += _luma(frame.getPixel(x, y));
          samples++;
        }
      }
    }
    return samples == 0 ? 0.0 : total / samples;
  }

  double _autocorrelationPeak(List<double> values) {
""",
)

# 2) Active discriminator: keep 0.36/0.235 thresholds, but require adequate
# real image brightness compensation before a short-shutter sample can promote
# DISPLAY. Poor compensation remains diagnostic/indeterminate.
disc = 'lib/hcv_physical_display_discriminator.dart'
replace_once(
    disc,
    "  static const double realityMinCellThreshold = 0.22;\n",
    "  static const double realityMinCellThreshold = 0.22;\n"
    "  static const double minimumDisplayLumaCompensationRatio = 0.60;\n",
)
replace_once(
    disc,
    """    final cells = (short['cellsAnalyzed'] as num?)?.toInt() ?? 0;

    if (mean == null || minCell == null || cells < 9) {
""",
    """    final cells = (short['cellsAnalyzed'] as num?)?.toInt() ?? 0;
    final comparisonsRaw = analysis?['comparisons'];
    final comparisons = comparisonsRaw is Map
        ? Map<String, dynamic>.from(comparisonsRaw)
        : const <String, dynamic>{};
    final lumaCompensationRatio =
        (comparisons['shortExposureLumaCompensationRatio1x'] as num?)
            ?.toDouble();
    final isoCompensationClamped =
        comparisons['isoCompensationClamped1x'] == true;

    if (mean == null || minCell == null || cells < 9) {
""",
)
replace_once(
    disc,
    """    final display =
        mean >= displayMeanThreshold && minCell >= displayMinCellThreshold;
    final reality =
        mean <= realityMeanThreshold && minCell <= realityMinCellThreshold;
""",
    """    final displayThresholdsPassed =
        mean >= displayMeanThreshold && minCell >= displayMinCellThreshold;
    final displayMeasurementQualitySufficient =
        lumaCompensationRatio != null &&
        lumaCompensationRatio >= minimumDisplayLumaCompensationRatio;
    final display =
        displayThresholdsPassed && displayMeasurementQualitySufficient;
    final reality =
        mean <= realityMeanThreshold && minCell <= realityMinCellThreshold;
""",
)
replace_once(
    disc,
    """      'cellsAnalyzed': cells,
      'thresholds': thresholds,
""",
    """      'cellsAnalyzed': cells,
      'shortExposureLumaCompensationRatio1x': lumaCompensationRatio,
      'isoCompensationClamped1x': isoCompensationClamped,
      'displayThresholdsPassed': displayThresholdsPassed,
      'displayMeasurementQualitySufficient':
          displayMeasurementQualitySufficient,
      'displayBlockedByExposureQuality':
          displayThresholdsPassed && !displayMeasurementQualitySufficient,
      'thresholds': thresholds,
""",
)
replace_once(
    disc,
    """        'displayRequiresBothThresholds': true,
        'realityRequiresBothThresholds': true,
""",
    """        'displayRequiresBothThresholds': true,
        'displayRequiresExposureQuality': true,
        'realityRequiresBothThresholds': true,
""",
)
replace_once(
    disc,
    """    'realityMinCellThreshold': realityMinCellThreshold,
    'source': 'BUILD_82_7_PAIR_EXPERIMENTAL_CORPUS',
    'status': 'ACTIVE_V1_CONSERVATIVE_TWO_CONDITION_GATE',
""",
    """    'realityMinCellThreshold': realityMinCellThreshold,
    'minimumDisplayLumaCompensationRatio':
        minimumDisplayLumaCompensationRatio,
    'source': 'ACTIVE_V1_PLUS_6_PACK_VALIDATION_2026_09_04',
    'status': 'ACTIVE_V2_EXPOSURE_QUALITY_GATED',
""",
)

# 3) Legacy fusion: a successfully analyzed new active physical probe replaces
# the removed legacy live-screen probe for completeness, so its absence no
# longer forces NON_CONCLUSIVE/LIVE_PROBE_MISSING by itself.
fusion = 'lib/hcv_display_risk_fusion.dart'
replace_once(
    fusion,
    """  static HCVDisplayRiskResult combine(
    List<Map<String, dynamic>?> analyses, {
    bool liveCaptureOnly = false,
  }) {
""",
    """  static HCVDisplayRiskResult combine(
    List<Map<String, dynamic>?> analyses, {
    bool liveCaptureOnly = false,
    bool alternativePhysicalProbeAvailable = false,
  }) {
""",
)
replace_once(
    fusion,
    """    final liveNotAnalyzed = live == null ||
        liveScore == null ||
        live?['analysisStatus'] == 'NOT_ANALYZED';
""",
    """    final liveNotAnalyzed = !alternativePhysicalProbeAvailable &&
        (live == null ||
            liveScore == null ||
            live?['analysisStatus'] == 'NOT_ANALYZED');
""",
)
replace_once(
    fusion,
    """    final missingReasons = <String>[];
    _appendMissingReason(
      missingReasons,
      live,
      missingTypeReason: 'LIVE_PROBE_MISSING',
    );
    if (!liveCaptureOnly) {
""",
    """    final missingReasons = <String>[];
    if (alternativePhysicalProbeAvailable) {
      reasons.add('ACTIVE_PHYSICAL_PROBE_REPLACES_LEGACY_LIVE_PROBE');
    } else {
      _appendMissingReason(
        missingReasons,
        live,
        missingTypeReason: 'LIVE_PROBE_MISSING',
      );
    }
    if (!liveCaptureOnly) {
""",
)

# 4) Camera integration: mark the new active probe as the live-proof substitute
# only when its physical analysis actually completed.
camera = 'lib/camera_page.dart'
replace_once(
    camera,
    """HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
""",
    """HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(
  List<Map<String, dynamic>?> analyses, {
  bool physicalProbeAvailable = false,
}) {
""",
)
replace_once(
    camera,
    """  final legacy = _combineVideoDisplayRiskLegacy(analyses);
""",
    """  final legacy = _combineVideoDisplayRiskLegacy(
    analyses,
    physicalProbeAvailable: physicalProbeAvailable,
  );
""",
)
replace_once(
    camera,
    """HCVDisplayRiskResult _combineVideoDisplayRiskLegacy(
  List<Map<String, dynamic>?> analyses,
) {
  final normalResult = HCVDisplayRiskFusion.combine(analyses);
""",
    """HCVDisplayRiskResult _combineVideoDisplayRiskLegacy(
  List<Map<String, dynamic>?> analyses, {
  bool physicalProbeAvailable = false,
}) {
  final normalResult = HCVDisplayRiskFusion.combine(
    analyses,
    alternativePhysicalProbeAvailable: physicalProbeAvailable,
  );
""",
)
replace_once(
    camera,
    """    final baseDisplayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
    );
    final videoPhysicalAnalysisRaw = videoPhysicalDisplayProbe?['analysis'];
    final videoPhysicalAnalysis = videoPhysicalAnalysisRaw is Map
        ? Map<String, dynamic>.from(videoPhysicalAnalysisRaw)
        : null;
""",
    """    final videoPhysicalAnalysisRaw = videoPhysicalDisplayProbe?['analysis'];
    final videoPhysicalAnalysis = videoPhysicalAnalysisRaw is Map
        ? Map<String, dynamic>.from(videoPhysicalAnalysisRaw)
        : null;
    final videoPhysicalProbeAvailable = videoPhysicalAnalysis != null &&
        videoPhysicalAnalysis['analysisStatus'] == 'ANALYZED';
    final baseDisplayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
      physicalProbeAvailable: videoPhysicalProbeAvailable,
    );
""",
)

print('PHYSICAL_DISPLAY_V2_MOTION_ISO_PATCH_APPLIED')
