import 'dart:math';

import 'hcv_display_risk_fusion.dart';

/// BUILD124: context-free, multi-evidence DISPLAY classification.
///
/// HFR/PHOTO still/PHOTO technical mini-video/VIDEO temporal ML and the
/// established fusion are independent inputs. Scene context, geometry and
/// motion sensors cannot absolve a detected DISPLAY. An inconclusive physical
/// result is NOT positive proof of REALITY.
///
/// Scores/thresholds below are bounded recovery criteria observed in the
/// Archive 70-73 diagnostic corpus. This is not a universal accuracy claim.
class HCVContextFreeDisplayPolicy {
  const HCVContextFreeDisplayPolicy._();

  static HCVDisplayRiskResult resolvePhoto({
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? ml,
    Map<String, dynamic>? photoTemporalMl,
    Map<String, dynamic>? passiveOptical,
    Map<String, dynamic>? photoTemporalOptical,
    HCVDisplayRiskResult? base,
  }) {
    final hfr = _hfrDisplay(temporalFrequencyProbe);
    if (hfr != null) return hfr;

    if (_photoMlDisplay(ml)) {
      return _display(
        'BUILD124_PHOTO_STILL_ML',
        max(90, _fullFrame(ml)),
        const <String>[
          'BUILD124_PHOTO_STILL_ML_SPATIAL_PROOF',
          'STILL_SCREEN_CLASS_AND_FULL_FRAME_CONTENT_AGREE',
        ],
      );
    }

    // BUILD114's temporal PHOTO evidence is available in liveScreenProbe.
    // It must not be erased merely because the still was taken a moment later
    // with lower confidence. The still MUST independently identify SCREEN;
    // this prevents the D56D printed fabric false positive (temporal high,
    // still REALITY_ROOM).
    if (_photoTemporalCorroboration(ml, photoTemporalMl)) {
      return _display(
        'BUILD124_PHOTO_TEMPORAL_STILL_CORROBORATION',
        95,
        const <String>[
          'BUILD124_PHOTO_THREE_PERSISTENT_SCREEN_FRAMES',
          'PHOTO_STILL_INDEPENDENT_SCREEN_CLASS',
        ],
      );
    }

    if (_partialHfrCorroborated(temporalFrequencyProbe, ml)) {
      return _display(
        'BUILD124_HFR_PARTIAL_ML_CORROBORATION',
        95,
        const <String>[
          'BUILD124_HFR_PHYSICAL_PARTIAL_DISPLAY_PROOF',
          'FIVE_LOCAL_DISPLAY_CELLS_WITH_GLOBAL_TEMPORAL_FAMILY',
          'INDEPENDENT_SCREEN_ML_CORROBORATION',
        ],
      );
    }

    // Recover the validated multi-source PHOTO fusion only when its strong
    // verdict is consistent with the independent still. A SCREEN-like
    // technical mini-video must never promote a REALITY-classified still by
    // itself, even when the legacy base was STRONG.
    if (base?.decision == 'STRONG_DISPLAY_RISK' &&
        _photoBaseCorroboration(
            ml, photoTemporalMl, passiveOptical, photoTemporalOptical)) {
      return _display(
        'BUILD124_RESTORED_PHOTO_FUSION',
        max(90, base!.score),
        <String>[
          ...base.reasons,
          'BUILD124_LEGACY_PHOTO_EVIDENCE_INDEPENDENTLY_CORROBORATED',
        ],
      );
    }

    if (_weakPhotoUnresolved(temporalFrequencyProbe, ml)) {
      return _unresolved(
        'BUILD124_WEAK_PHOTO_DISPLAY_EVIDENCE_NOT_REALITY',
      );
    }

    if (!_hasUsableMl(ml) && !_hasUsableHfr(temporalFrequencyProbe)) {
      return _unresolved('BUILD124_DECISION_EVIDENCE_UNAVAILABLE');
    }
    return _reality('BUILD124_NO_CORROBORATED_PHOTO_DISPLAY_EVIDENCE');
  }

  static HCVDisplayRiskResult resolveVideo({
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? ml,
    Map<String, dynamic>? passiveOptical,
    HCVDisplayRiskResult? base,
  }) {
    final hfr = _hfrDisplay(temporalFrequencyProbe);
    if (hfr != null) return hfr;

    if (_videoMlDisplay(ml)) {
      return _display(
        'BUILD124_VIDEO_ML_PERSISTENCE',
        max(90, _maxVideoFullFrame(ml)),
        const <String>[
          'BUILD124_VIDEO_PERSISTENT_FULL_FRAME_SCREEN',
          'VIDEO_TWO_FRAMES_80_AND_ONE_FRAME_90',
        ],
      );
    }

    if (_partialHfrCorroborated(temporalFrequencyProbe, ml)) {
      return _display(
        'BUILD124_HFR_PARTIAL_ML_CORROBORATION',
        95,
        const <String>[
          'BUILD124_HFR_PHYSICAL_PARTIAL_DISPLAY_PROOF',
          'FIVE_LOCAL_DISPLAY_CELLS_WITH_GLOBAL_TEMPORAL_FAMILY',
          'INDEPENDENT_SCREEN_ML_CORROBORATION',
        ],
      );
    }

    if (base?.decision == 'STRONG_DISPLAY_RISK' &&
        _videoBaseCorroboration(ml, passiveOptical)) {
      return _display(
        'BUILD124_RESTORED_VIDEO_FUSION',
        max(90, base!.score),
        <String>[
          ...base.reasons,
          'BUILD124_LEGACY_VIDEO_EVIDENCE_INDEPENDENTLY_CORROBORATED',
        ],
      );
    }

    if (_weakVideoUnresolved(temporalFrequencyProbe, ml)) {
      return _unresolved(
        'BUILD124_WEAK_VIDEO_DISPLAY_EVIDENCE_NOT_REALITY',
      );
    }

    if (!_hasUsableMl(ml) && !_hasUsableHfr(temporalFrequencyProbe)) {
      return _unresolved('BUILD124_DECISION_EVIDENCE_UNAVAILABLE');
    }
    return _reality('BUILD124_NO_CORROBORATED_VIDEO_DISPLAY_EVIDENCE');
  }

  static HCVDisplayRiskResult? _hfrDisplay(Map<String, dynamic>? probe) {
    if (!_hasUsableHfr(probe)) return null;
    final v3 = _v3(probe);
    final periodicity = _periodicity(probe);
    if (v3 == null || periodicity == null) return null;

    final displayLike = _i(v3, 'displayLikeCellCount');
    final realityLike = _i(v3, 'realityLikeCellCount');
    // These counters are in coherentDisplayPeriodicityEvidence, NOT in V3.
    final periodic = _i(periodicity, 'periodicCellCount');
    final stable = _i(periodicity, 'stableCellCount');
    final spatial = _i(v3, 'spatialFamilyCellCount');
    final harmonic = _i(v3, 'harmonicAwareSpatialFamilyCellCount');
    final rowTime = _i(v3, 'rowTimeFamilyCellCount');

    final physicallyFullFrame = probe?['coherentDisplayPeriodicity'] == true &&
        v3['fullFrameDisplay'] == true &&
        v3['mixedSceneDetected'] != true &&
        v3['allNineCellsSameDisplayFamily'] == true;
    final sevenCellRecovery = displayLike >= 7 &&
        realityLike == 0 &&
        periodic >= 7 &&
        stable >= 7 &&
        spatial == 9 &&
        harmonic == 9 &&
        rowTime == 9;

    if (!physicallyFullFrame && !sevenCellRecovery) return null;

    return _display(
      'BUILD124_HFR_FULL_FRAME_PHYSICS',
      98,
      const <String>[
        'BUILD124_HFR_FULL_FRAME_DISPLAY',
        'BUILD124_HFR_COUNTERS_READ_FROM_CORRECT_JSON_SECTION',
      ],
    );
  }

  static bool _partialHfrCorroborated(
    Map<String, dynamic>? probe,
    Map<String, dynamic>? ml,
  ) {
    if (!_hasUsableHfr(probe) || !_hasUsableMl(ml)) return false;
    final v3 = _v3(probe);
    final periodicity = _periodicity(probe);
    if (v3 == null || periodicity == null) return false;
    final predictedClass = ml?['predictedClass']?.toString() ?? '';
    if (!predictedClass.startsWith('SCREEN_') ||
        _d(ml, 'screenProbability') < 0.60 ||
        _fullFrame(ml) < 60) {
      return false;
    }

    return _i(v3, 'displayLikeCellCount') >= 5 &&
        _i(v3, 'realityLikeCellCount') == 0 &&
        _i(periodicity, 'periodicCellCount') >= 6 &&
        _i(periodicity, 'stableCellCount') >= 5 &&
        _i(v3, 'spatialFamilyCellCount') == 9 &&
        _i(v3, 'harmonicAwareSpatialFamilyCellCount') == 9 &&
        _i(v3, 'rowTimeFamilyCellCount') == 9 &&
        _d(periodicity, 'medianCellPeriodicityStrength') >= 0.15 &&
        _d(periodicity, 'dominantTemporalFrequencyHz') >= 40.0 &&
        _d(periodicity, 'globalSpectralConcentration') >= 0.85;
  }

  static bool _photoMlDisplay(Map<String, dynamic>? ml) {
    if (!_hasUsableMl(ml)) return false;
    return (ml?['predictedClass']?.toString() ?? '').startsWith('SCREEN_') &&
        _d(ml, 'screenProbability') >= 0.90 &&
        _fullFrame(ml) >= 90 &&
        _contentArea(ml) >= 75;
  }

  static bool _photoTemporalCorroboration(
    Map<String, dynamic>? still,
    Map<String, dynamic>? temporal,
  ) {
    if (!_hasUsableMl(still) || !_hasUsableMl(temporal)) return false;
    if (!(still?['predictedClass']?.toString() ?? '').startsWith('SCREEN_') ||
        _d(still, 'screenProbability') < 0.60 ||
        _contentArea(still) < 75) {
      return false;
    }
    final frames = temporal?['videoFrameAnalyses'];
    if (frames is! List || frames.length < 3) return false;
    var strongScreenFrames = 0;
    for (final frame in frames) {
      if (frame is! Map) continue;
      final frameSignals = frame['signals'];
      if ((frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_') &&
          _d(frame, 'screenProbability') >= 0.90 &&
          frameSignals is Map &&
          _i(frameSignals, 'fullFrameRiskScore') >= 90) {
        strongScreenFrames++;
      }
    }
    return strongScreenFrames >= 3;
  }

  static bool _videoMlDisplay(Map<String, dynamic>? ml) {
    if (!_hasUsableMl(ml) ||
        !(ml?['predictedClass']?.toString() ?? '').startsWith('SCREEN_') ||
        _d(ml, 'screenProbability') < 0.80) {
      return false;
    }
    return _videoFrameCountAtLeast(ml, 80) >= 2 &&
        _videoFrameCountAtLeast(ml, 90) >= 1;
  }

  static bool _photoBaseCorroboration(
    Map<String, dynamic>? ml,
    Map<String, dynamic>? temporal,
    Map<String, dynamic>? optical,
    Map<String, dynamic>? temporalOptical,
  ) {
    if (!_hasUsableMl(ml) ||
        !(ml?['predictedClass']?.toString() ?? '').startsWith('SCREEN_') ||
        _d(ml, 'screenProbability') < 0.80 ||
        _fullFrame(ml) < 80 ||
        _contentArea(ml) < 75) {
      return false;
    }
    return _photoTemporalCorroboration(ml, temporal) ||
        _strongOpticalDisplayTrace(optical) ||
        _strongOpticalDisplayTrace(temporalOptical);
  }

  static bool _videoBaseCorroboration(
    Map<String, dynamic>? ml,
    Map<String, dynamic>? optical,
  ) {
    if (!_hasUsableMl(ml) ||
        !(ml?['predictedClass']?.toString() ?? '').startsWith('SCREEN_') ||
        _d(ml, 'screenProbability') < 0.75 ||
        _videoFrameCountAtLeast(ml, 80) < 2) {
      return false;
    }
    return _videoFrameCountAtLeast(ml, 90) >= 1 ||
        _strongOpticalDisplayTrace(optical);
  }

  static bool _strongOpticalDisplayTrace(Map<String, dynamic>? analysis) {
    if (analysis == null || analysis['analysisStatus'] == 'NOT_ANALYZED') {
      return false;
    }
    final signals = analysis['signals'];
    return signals is Map &&
        (signals['confirmedDisplayTrace'] == true ||
            signals['strongDisplayTrace'] == true ||
            signals['structuralDisplayTrace'] == true);
  }

  static bool _weakPhotoUnresolved(
    Map<String, dynamic>? probe,
    Map<String, dynamic>? ml,
  ) {
    if (!_hasUsableHfr(probe) || !_hasUsableMl(ml)) return false;
    final v3 = _v3(probe);
    if (v3 == null ||
        _i(v3, 'displayLikeCellCount') < 2 ||
        _i(v3, 'realityLikeCellCount') != 0) {
      return false;
    }
    return (ml?['predictedClass']?.toString() ?? '').startsWith('SCREEN_') &&
        _d(ml, 'screenProbability') >= 0.55 &&
        _contentArea(ml) >= 75;
  }

  static bool _weakVideoUnresolved(
    Map<String, dynamic>? probe,
    Map<String, dynamic>? ml,
  ) {
    if (!_hasUsableHfr(probe) || !_hasUsableMl(ml)) return false;
    final v3 = _v3(probe);
    if (v3 == null ||
        _i(v3, 'displayLikeCellCount') < 2 ||
        _i(v3, 'realityLikeCellCount') != 0) {
      return false;
    }
    return (ml?['predictedClass']?.toString() ?? '').startsWith('SCREEN_') &&
        _d(ml, 'screenProbability') >= 0.65 &&
        _videoFrameCountAtLeast(ml, 60) >= 2;
  }

  static int _videoFrameCountAtLeast(
    Map<String, dynamic>? ml,
    int threshold,
  ) {
    final frames = ml?['videoFrameAnalyses'];
    if (frames is! List) return 0;
    var count = 0;
    for (final frame in frames) {
      if (frame is! Map) continue;
      final signals = frame['signals'];
      if (signals is Map && _i(signals, 'fullFrameRiskScore') >= threshold) {
        count++;
      }
    }
    return count;
  }

  static int _maxVideoFullFrame(Map<String, dynamic>? ml) {
    final frames = ml?['videoFrameAnalyses'];
    if (frames is! List) return 0;
    var maximum = 0;
    for (final frame in frames) {
      if (frame is! Map) continue;
      final signals = frame['signals'];
      if (signals is Map) {
        maximum = max(maximum, _i(signals, 'fullFrameRiskScore'));
      }
    }
    return maximum;
  }

  static int _fullFrame(Map<String, dynamic>? ml) =>
      _i(_signals(ml), 'fullFrameRiskScore');

  static int _contentArea(Map<String, dynamic>? ml) =>
      _i(_signals(ml), 'contentAreaRiskScore');

  static Map<String, dynamic> _signals(Map<String, dynamic>? ml) {
    final raw = ml?['signals'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  static bool _hasUsableMl(Map<String, dynamic>? ml) =>
      ml != null && ml['analysisStatus'] == 'ANALYZED';

  static bool _hasUsableHfr(Map<String, dynamic>? probe) =>
      probe != null &&
      probe['analysisStatus'] == 'ANALYZED' &&
      probe['shortExposureVerified'] == true &&
      probe['exposureLockedForEntireNativeCapture'] == true &&
      (probe['framesAnalyzed'] as num? ?? 0) >= 42 &&
      (probe['actualFrameRateFromTimestamps'] as num? ?? 0) >= 115;

  static Map<String, dynamic>? _v3(Map<String, dynamic>? probe) {
    final raw = probe?['displayRealityEvidenceV3'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static Map<String, dynamic>? _periodicity(Map<String, dynamic>? probe) {
    final raw = probe?['coherentDisplayPeriodicityEvidence'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static int _i(Map? map, String key) => (map?[key] as num?)?.toInt() ?? 0;

  static double _d(Map? map, String key) =>
      (map?[key] as num?)?.toDouble() ?? 0.0;

  static HCVDisplayRiskResult _display(
    String source,
    int score,
    List<String> reasons,
  ) =>
      HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score.clamp(90, 100).toInt(),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: <String>[source],
        strongSources: <String>[source],
        reasons: reasons,
      );

  static HCVDisplayRiskResult _reality(String reason) => HCVDisplayRiskResult(
        risk: 'LOW',
        score: 20,
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['BUILD124_EVIDENCE_RESOLVER'],
        strongSources: const <String>[],
        reasons: <String>[reason],
      );

  static HCVDisplayRiskResult _unresolved(String reason) =>
      HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: 45,
        decision: 'NON_CONCLUSIVE',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['BUILD124_EVIDENCE_RESOLVER'],
        strongSources: const <String>[],
        reasons: <String>[reason],
      );
}
