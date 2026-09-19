import 'dart:math';

import 'hcv_display_risk_fusion.dart';

/// BUILD123: one context-free DISPLAY/NO DISPLAY decision for PHOTO and VIDEO.
///
/// This policy consumes only HFR's physical grid and the captured ML evidence.
/// No scene context, parallax, optical, sensor or earlier risk verdict may
/// promote or absolve the final decision. Missing ML evidence never yields
/// NO_DISPLAY_EVIDENCE by default.
class HCVContextFreeDisplayPolicy {
  const HCVContextFreeDisplayPolicy._();

  static HCVDisplayRiskResult resolve({
    required bool isPhoto,
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? mlScreenReplayAnalysis,
  }) {
    if (_strongHfr(temporalFrequencyProbe)) {
      return _display(
        score: 98,
        source: 'BUILD123_HFR_PHYSICAL_GRID',
        reason: 'BUILD123_HFR_7_OF_9_PHYSICAL_DISPLAY',
      );
    }

    final ml = mlScreenReplayAnalysis;
    if (ml == null || ml['analysisStatus'] != 'ANALYZED') {
      return _incomplete();
    }
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final screenClass = predictedClass.startsWith('SCREEN_');
    final screenProbability = _number(ml['screenProbability']);
    if (screenProbability == null) return _incomplete();

    if (isPhoto) {
      final signals = ml['signals'];
      if (signals is! Map ||
          _number(signals['fullFrameRiskScore']) == null ||
          _number(signals['contentAreaRiskScore']) == null) {
        return _incomplete();
      }
      if (screenClass &&
          screenProbability >= 0.90 &&
          _number(signals['fullFrameRiskScore'])! >= 90 &&
          _number(signals['contentAreaRiskScore'])! >= 75) {
        return _display(
          score: max(95, (screenProbability * 100).round()),
          source: 'BUILD123_PHOTO_ML_SPATIAL',
          reason: 'BUILD123_PHOTO_STRONG_FULL_FRAME_AND_CONTENT',
        );
      }
    } else {
      final frames = ml['videoFrameAnalyses'];
      final analyzed = _number(ml['framesAnalyzed'])?.toInt() ?? 0;
      if (frames is! List || analyzed < 2 || frames.length < analyzed) {
        return _incomplete();
      }
      final frameScores = <double>[];
      for (final frame in frames.take(analyzed)) {
        if (frame is! Map || frame['signals'] is! Map) {
          return _incomplete();
        }
        final score = _number((frame['signals'] as Map)['fullFrameRiskScore']);
        if (score == null) return _incomplete();
        frameScores.add(score);
      }
      final sustained = frameScores.where((value) => value >= 80).length >= 2;
      final hasHigh = frameScores.any((value) => value >= 90);
      if (screenClass &&
          screenProbability >= 0.80 &&
          sustained &&
          hasHigh) {
        return _display(
          score: max(95, frameScores.reduce(max).round()),
          source: 'BUILD123_VIDEO_ML_PERSISTENCE',
          reason: 'BUILD123_VIDEO_SUSTAINED_FULL_FRAME_DISPLAY',
        );
      }
    }

    return const HCVDisplayRiskResult(
      risk: 'LOW',
      score: 20,
      decision: 'NO_DISPLAY_EVIDENCE',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['BUILD123_CONTEXT_FREE_CLASSIFIER'],
      strongSources: <String>[],
      reasons: <String>[
        'BUILD123_COMPLETE_ML_WITHOUT_DISPLAY_GATE',
        'NO_DISPLAY_EVIDENCE_IS_NOT_ABSOLUTE_REALITY_PROOF',
      ],
    );
  }

  static bool _strongHfr(Map<String, dynamic>? probe) {
    if (probe == null ||
        probe['analysisStatus'] != 'ANALYZED' ||
        probe['shortExposureVerified'] != true ||
        probe['exposureLockedForEntireNativeCapture'] != true) {
      return false;
    }
    final frames = _number(probe['framesAnalyzed'])?.toInt() ?? 0;
    final target = _number(probe['targetFrameCount'])?.toInt() ?? 60;
    final actualFps = _number(probe['actualFrameRateFromTimestamps']) ?? 0;
    final configuredFps = _number(probe['configuredFrameRate']) ?? 120;
    if (target <= 0 ||
        frames < target ||
        actualFps < configuredFps * 0.98) {
      return false;
    }
    final grid = probe['displayRealityEvidenceV3'];
    final temporal = probe['coherentDisplayPeriodicityEvidence'];
    if (grid is! Map || temporal is! Map) return false;
    return (_number(grid['displayLikeCellCount']) ?? 0) >= 7 &&
        _number(grid['realityLikeCellCount']) == 0 &&
        (_number(temporal['periodicCellCount']) ?? 0) >= 7 &&
        (_number(temporal['stableCellCount']) ?? 0) >= 7 &&
        _number(grid['spatialFamilyCellCount']) == 9 &&
        _number(grid['harmonicAwareSpatialFamilyCellCount']) == 9 &&
        _number(grid['rowTimeFamilyCellCount']) == 9;
  }

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;

  static HCVDisplayRiskResult _display({
    required int score,
    required String source,
    required String reason,
  }) =>
      HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score.clamp(95, 100).toInt(),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: <String>[source],
        strongSources: <String>[source],
        reasons: <String>[reason, 'BUILD123_CONTEXT_FREE_FINAL_POLICY'],
      );

  static HCVDisplayRiskResult _incomplete() => const HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: 45,
        decision: 'NON_CONCLUSIVE',
        analysisStatus: 'INCOMPLETE',
        evidenceSources: <String>[],
        strongSources: <String>[],
        reasons: <String>['BUILD123_REQUIRED_ML_EVIDENCE_UNAVAILABLE'],
      );
}
