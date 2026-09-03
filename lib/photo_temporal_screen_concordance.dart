import 'dart:math';

import 'hcv_display_risk_fusion.dart';

/// Conservative PHOTO-only promotion for the Temporal V2 path.
///
/// A moderate SCREEN_* prediction is never sufficient by itself. Promotion
/// requires the same semantic screen family to be observed independently in
/// the final still and in at least one frame of the disposable mini-video
/// captured immediately before that still.
class PhotoTemporalScreenConcordance {
  const PhotoTemporalScreenConcordance._();

  static const double minimumScreenProbability = 0.40;
  static const double minimumClassConfidence = 0.40;

  static HCVDisplayRiskResult? evaluate(
    Map<String, dynamic>? finalStillMl,
    Map<String, dynamic>? liveProbe,
  ) {
    if (finalStillMl == null || liveProbe == null) return null;
    if (liveProbe['photoDecisionMethod'] !=
        'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT') {
      return null;
    }
    if (finalStillMl['analysisStatus'] != 'ANALYZED') return null;
    if ((finalStillMl['framesAnalyzed'] as num?)?.toInt() != 1) return null;

    final stillClass = finalStillMl['predictedClass']?.toString() ?? '';
    final stillProbability =
        (finalStillMl['screenProbability'] as num?)?.toDouble() ?? 0.0;
    final stillConfidence =
        (finalStillMl['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
    if (!stillClass.startsWith('SCREEN_') ||
        stillProbability < minimumScreenProbability ||
        stillConfidence < minimumClassConfidence) {
      return null;
    }

    final rawTemporalProbe = liveProbe['photoTemporalVideoProbe'];
    if (rawTemporalProbe is! Map) return null;
    final rawTemporalMl = rawTemporalProbe['mlScreenReplayAnalysis'];
    if (rawTemporalMl is! Map) return null;
    if (rawTemporalMl['analysisStatus'] != 'ANALYZED' ||
        rawTemporalMl['captureSource'] != 'PHOTO_TECHNICAL_MINI_VIDEO_V2') {
      return null;
    }

    final framesAnalyzed =
        (rawTemporalMl['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final rawFrames = rawTemporalMl['videoFrameAnalyses'];
    if (framesAnalyzed < 2 ||
        rawFrames is! List ||
        rawFrames.length != framesAnalyzed) {
      return null;
    }

    var bestTemporalScreenProbability = 0.0;
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map) continue;
      final frameClass = rawFrame['predictedClass']?.toString() ?? '';
      final probability =
          (rawFrame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      final confidence =
          (rawFrame['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
      if (frameClass.startsWith('SCREEN_') &&
          probability >= minimumScreenProbability &&
          confidence >= minimumClassConfidence) {
        bestTemporalScreenProbability =
            max(bestTemporalScreenProbability, probability);
      }
    }

    if (bestTemporalScreenProbability < minimumScreenProbability) return null;

    // Two independent moderate semantic observations are enough to resolve the
    // PHOTO as display recapture, but the score is deliberately capped at the
    // same conservative floor used by strong video ML decisions.
    final evidenceScore =
        (((stillProbability + bestTemporalScreenProbability) / 2) * 100)
            .round()
            .clamp(75, 89)
            .toInt();
    return HCVDisplayRiskResult(
      risk: 'HIGH',
      score: evidenceScore,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: const [
        'ML_SCREEN_CLASS',
        'PHOTO_TEMPORAL_SCREEN_CLASS',
      ],
      strongSources: const ['DUAL_STAGE_ML_SCREEN_CONCORDANCE'],
      reasons: const [
        'PHOTO_FINAL_AND_PRECAPTURE_SCREEN_FAMILY_MODERATE_CONCORDANCE',
      ],
    );
  }
}
