import 'dart:math';

import 'hcv_display_risk_fusion.dart';

/// BUILD123 binary DISPLAY/REALITY decision policy.
///
/// Scene context, geometry, sensors and optical analysis are deliberately not
/// inputs. They remain diagnostic certificate evidence only.
///
/// The policy was selected offline against every compatible physical sample
/// available in Archives 70, 71 and 72 (62 captures total):
/// - HFR physical full-frame family gate;
/// - strong coherent PHOTO ML gate;
/// - persistent full-frame VIDEO ML gate.
///
/// Missing/invalid decision evidence remains NON_CONCLUSIVE rather than being
/// silently converted into REALITY.
class HCVContextFreeDisplayPolicy {
  const HCVContextFreeDisplayPolicy._();

  static HCVDisplayRiskResult resolvePhoto({
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? ml,
  }) {
    final hfr = _hfrDisplay(temporalFrequencyProbe);
    if (hfr != null) return hfr;

    if (_photoMlDisplay(ml)) {
      final signals = _signals(ml);
      final probability = (ml?['screenProbability'] as num?)?.toDouble() ?? 0.0;
      final fullFrame =
          (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      final contentArea =
          (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
      final score = max(
        (probability * 100).round(),
        max(fullFrame, contentArea),
      ).clamp(90, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['BUILD123_PHOTO_ML'],
        strongSources: const <String>['BUILD123_PHOTO_ML'],
        reasons: const <String>[
          'BUILD123_CONTEXT_FREE_PHOTO_DISPLAY',
          'PHOTO_SCREEN_CLASS_PROBABILITY_AT_LEAST_0_90',
          'PHOTO_FULL_FRAME_RISK_AT_LEAST_90',
          'PHOTO_CONTENT_AREA_RISK_AT_LEAST_75',
        ],
      );
    }

    if (_hasUsableMl(ml) || _hasUsableHfr(temporalFrequencyProbe)) {
      return const HCVDisplayRiskResult(
        risk: 'LOW',
        score: 20,
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: <String>['BUILD123_CONTEXT_FREE_CLASSIFIER'],
        strongSources: <String>[],
        reasons: <String>[
          'BUILD123_CONTEXT_FREE_REALITY',
          'NO_HFR_FULL_FRAME_DISPLAY_GATE',
          'NO_PHOTO_ML_DISPLAY_GATE',
        ],
      );
    }

    return _notAnalyzed();
  }

  static HCVDisplayRiskResult resolveVideo({
    required Map<String, dynamic>? temporalFrequencyProbe,
    required Map<String, dynamic>? ml,
  }) {
    final hfr = _hfrDisplay(temporalFrequencyProbe);
    if (hfr != null) return hfr;

    final video = _videoMlEvidence(ml);
    if (video.isDisplay) {
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: max(90, video.maxFullFrameRisk).clamp(90, 100).toInt(),
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const <String>['BUILD123_VIDEO_ML_PERSISTENCE'],
        strongSources: const <String>['BUILD123_VIDEO_ML_PERSISTENCE'],
        reasons: const <String>[
          'BUILD123_CONTEXT_FREE_VIDEO_DISPLAY',
          'VIDEO_SCREEN_CLASS_PROBABILITY_AT_LEAST_0_80',
          'VIDEO_AT_LEAST_TWO_FULL_FRAME_SAMPLES_AT_80',
          'VIDEO_AT_LEAST_ONE_FULL_FRAME_SAMPLE_AT_90',
        ],
      );
    }

    if (_hasUsableMl(ml) || _hasUsableHfr(temporalFrequencyProbe)) {
      return const HCVDisplayRiskResult(
        risk: 'LOW',
        score: 20,
        decision: 'NO_DISPLAY_EVIDENCE',
        analysisStatus: 'COMPLETE',
        evidenceSources: <String>['BUILD123_CONTEXT_FREE_CLASSIFIER'],
        strongSources: <String>[],
        reasons: <String>[
          'BUILD123_CONTEXT_FREE_REALITY',
          'NO_HFR_FULL_FRAME_DISPLAY_GATE',
          'NO_VIDEO_ML_PERSISTENCE_GATE',
        ],
      );
    }

    return _notAnalyzed();
  }

  static HCVDisplayRiskResult? _hfrDisplay(
    Map<String, dynamic>? probe,
  ) {
    if (!_hasUsableHfr(probe)) return null;
    final v3 = _v3(probe);
    if (v3 == null) return null;

    final displayLike =
        (v3['displayLikeCellCount'] as num?)?.toInt() ?? 0;
    final realityLike =
        (v3['realityLikeCellCount'] as num?)?.toInt() ?? 0;
    final periodic =
        (v3['periodicCellCount'] as num?)?.toInt() ?? 0;
    final stable =
        (v3['stableCellCount'] as num?)?.toInt() ?? 0;
    final spatial =
        (v3['spatialFamilyCellCount'] as num?)?.toInt() ?? 0;
    final harmonic =
        (v3['harmonicAwareSpatialFamilyCellCount'] as num?)?.toInt() ?? 0;
    final rowTime =
        (v3['rowTimeFamilyCellCount'] as num?)?.toInt() ?? 0;

    final display = displayLike >= 7 &&
        realityLike == 0 &&
        periodic >= 7 &&
        stable >= 7 &&
        spatial == 9 &&
        harmonic == 9 &&
        rowTime == 9;
    if (!display) return null;

    return const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 98,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['BUILD123_HFR_FULL_FRAME_PHYSICS'],
      strongSources: <String>['BUILD123_HFR_FULL_FRAME_PHYSICS'],
      reasons: <String>[
        'BUILD123_CONTEXT_FREE_HFR_DISPLAY',
        'HFR_DISPLAY_LIKE_CELLS_AT_LEAST_7',
        'HFR_ZERO_REALITY_LIKE_CELLS',
        'HFR_PERIODIC_AND_STABLE_CELLS_AT_LEAST_7',
        'HFR_SPATIAL_HARMONIC_ROW_FAMILIES_ALL_9',
      ],
    );
  }

  static bool _photoMlDisplay(Map<String, dynamic>? ml) {
    if (!_hasUsableMl(ml)) return false;
    final predictedClass = ml?['predictedClass']?.toString() ?? '';
    final probability =
        (ml?['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final signals = _signals(ml);
    final fullFrame =
        (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final contentArea =
        (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;

    return predictedClass.startsWith('SCREEN_') &&
        probability >= 0.90 &&
        fullFrame >= 90 &&
        contentArea >= 75;
  }

  static _VideoEvidence _videoMlEvidence(Map<String, dynamic>? ml) {
    if (!_hasUsableMl(ml)) return const _VideoEvidence();
    final predictedClass = ml?['predictedClass']?.toString() ?? '';
    final probability =
        (ml?['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final frames = ml?['videoFrameAnalyses'];
    if (!predictedClass.startsWith('SCREEN_') ||
        probability < 0.80 ||
        frames is! List) {
      return const _VideoEvidence();
    }

    var frames80 = 0;
    var frames90 = 0;
    var maxFullFrame = 0;
    for (final raw in frames) {
      if (raw is! Map) continue;
      final signals = raw['signals'];
      if (signals is! Map) continue;
      final fullFrame =
          (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      if (fullFrame >= 80) frames80++;
      if (fullFrame >= 90) frames90++;
      if (fullFrame > maxFullFrame) maxFullFrame = fullFrame;
    }

    return _VideoEvidence(
      isDisplay: frames80 >= 2 && frames90 >= 1,
      frames80: frames80,
      frames90: frames90,
      maxFullFrameRisk: maxFullFrame,
    );
  }

  static bool _hasUsableMl(Map<String, dynamic>? ml) =>
      ml != null && ml['analysisStatus'] == 'ANALYZED';

  static bool _hasUsableHfr(Map<String, dynamic>? probe) =>
      probe != null &&
      probe['analysisStatus'] == 'ANALYZED' &&
      probe['shortExposureVerified'] == true &&
      probe['exposureLockedForEntireNativeCapture'] == true;

  static Map<String, dynamic>? _v3(Map<String, dynamic>? probe) {
    final raw = probe?['displayRealityEvidenceV3'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static Map<String, dynamic> _signals(Map<String, dynamic>? analysis) {
    final raw = analysis?['signals'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  static HCVDisplayRiskResult _notAnalyzed() =>
      const HCVDisplayRiskResult(
        risk: 'MEDIUM',
        score: 45,
        decision: 'NON_CONCLUSIVE',
        analysisStatus: 'NOT_ANALYZED',
        evidenceSources: <String>[],
        strongSources: <String>[],
        reasons: <String>[
          'BUILD123_CONTEXT_FREE_DECISION_EVIDENCE_UNAVAILABLE',
        ],
      );
}

class _VideoEvidence {
  const _VideoEvidence({
    this.isDisplay = false,
    this.frames80 = 0,
    this.frames90 = 0,
    this.maxFullFrameRisk = 0,
  });

  final bool isDisplay;
  final int frames80;
  final int frames90;
  final int maxFullFrameRisk;
}
