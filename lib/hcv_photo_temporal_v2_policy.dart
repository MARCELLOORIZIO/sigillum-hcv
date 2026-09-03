class HCVPhotoTemporalV2Policy {
  const HCVPhotoTemporalV2Policy._();

  static const double moderateStillScreenProbabilityMin = 0.40;
  static const double moderateTemporalScreenProbabilityMin = 0.40;
  static const int moderateStillFullFrameRiskMin = 40;
  static const int requiredTemporalFrames = 4;

  /// Conservative PHOTO-only recovery gate for a narrow false-negative mode.
  ///
  /// This gate does not establish STRONG display evidence. It only says that
  /// a NO_DISPLAY result should be promoted to NON_CONCLUSIVE when the final
  /// still and the immediately-preceding four-frame Temporal V2 clip both
  /// independently land in the SCREEN semantic family at moderate strength.
  ///
  /// The caller must still require the existing decision to be NO_DISPLAY.
  static bool hasModerateCrossCaptureScreenAgreement({
    required Map<String, dynamic>? stillMl,
    required Map<String, dynamic>? liveProbe,
  }) {
    if (stillMl == null || liveProbe == null) return false;
    if (liveProbe['photoDecisionMethod'] !=
        'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT') {
      return false;
    }
    if (stillMl['analysisStatus'] == 'NOT_ANALYZED') return false;

    final stillClass = stillMl['predictedClass']?.toString() ?? '';
    final stillProbability =
        (stillMl['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final stillSignalsRaw = stillMl['signals'];
    final stillSignals = stillSignalsRaw is Map
        ? Map<String, dynamic>.from(stillSignalsRaw)
        : const <String, dynamic>{};
    final stillFullFrameRisk =
        (stillSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;

    if (!stillClass.startsWith('SCREEN_') ||
        stillProbability < moderateStillScreenProbabilityMin ||
        stillFullFrameRisk < moderateStillFullFrameRiskMin) {
      return false;
    }

    final temporalProbeRaw = liveProbe['photoTemporalVideoProbe'];
    if (temporalProbeRaw is! Map) return false;
    final temporalMlRaw = temporalProbeRaw['mlScreenReplayAnalysis'];
    if (temporalMlRaw is! Map) return false;
    final temporalMl = Map<String, dynamic>.from(temporalMlRaw);
    if (temporalMl['analysisStatus'] == 'NOT_ANALYZED') return false;

    final framesAnalyzed =
        (temporalMl['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final temporalClass = temporalMl['predictedClass']?.toString() ?? '';
    final temporalProbability =
        (temporalMl['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final rawFrames = temporalMl['videoFrameAnalyses'];

    if (framesAnalyzed < requiredTemporalFrames ||
        rawFrames is! List ||
        rawFrames.length != framesAnalyzed ||
        !temporalClass.startsWith('SCREEN_') ||
        temporalProbability < moderateTemporalScreenProbabilityMin) {
      return false;
    }

    return rawFrames.any((frame) {
      if (frame is! Map) return false;
      final frameClass = frame['predictedClass']?.toString() ?? '';
      final frameProbability =
          (frame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      return frameClass.startsWith('SCREEN_') &&
          frameProbability >= moderateTemporalScreenProbabilityMin;
    });
  }
}
