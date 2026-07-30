import 'dart:math';

class HCVSceneGeometryClassification {
  const HCVSceneGeometryClassification({
    required this.sceneClass,
    required this.realityEvidence,
    required this.planarEvidence,
    required this.motionMagnitude,
    required this.flowReliability,
    required this.directionCoherence,
    required this.depthDispersion,
    required this.planarCoherence,
    required this.matchedRegions,
    required this.reasons,
  });

  final String sceneClass;
  final bool realityEvidence;
  final bool planarEvidence;
  final double motionMagnitude;
  final double flowReliability;
  final double directionCoherence;
  final double depthDispersion;
  final double planarCoherence;
  final int matchedRegions;
  final List<String> reasons;

  bool get movementSufficient =>
      matchedRegions >= 5 && motionMagnitude >= 0.16 && flowReliability >= 0.46;

  Map<String, dynamic> toJson() => {
        'sceneClass': sceneClass,
        'realityEvidence': realityEvidence,
        'planarEvidence': planarEvidence,
        'motionMagnitude': _round(motionMagnitude),
        'flowReliability': _round(flowReliability),
        'directionCoherence': _round(directionCoherence),
        'depthDispersion': _round(depthDispersion),
        'planarCoherence': _round(planarCoherence),
        'matchedRegions': matchedRegions,
        'movementSufficient': movementSufficient,
        'reasons': reasons,
      };

  static double _round(double value) =>
      double.parse(value.clamp(0.0, 1.0).toStringAsFixed(4));
}

class HCVSceneGeometryClassifier {
  const HCVSceneGeometryClassifier._();

  static HCVSceneGeometryClassification classify({
    required double motionMagnitude,
    required double flowReliability,
    required double directionCoherence,
    required double depthDispersion,
    required double planarCoherence,
    required int matchedRegions,
  }) {
    final motion = motionMagnitude.clamp(0.0, 1.0).toDouble();
    final reliability = flowReliability.clamp(0.0, 1.0).toDouble();
    final direction = directionCoherence.clamp(0.0, 1.0).toDouble();
    final dispersion = depthDispersion.clamp(0.0, 1.0).toDouble();
    final planar = planarCoherence.clamp(0.0, 1.0).toDouble();
    final reasons = <String>[];

    final enoughRegions = matchedRegions >= 5;
    final sufficientMotion = motion >= 0.16;
    final reliableFlow = reliability >= 0.46;

    if (!enoughRegions) reasons.add('GEOMETRY_NOT_ENOUGH_TEXTURED_REGIONS');
    if (!sufficientMotion) reasons.add('GEOMETRY_MOTION_TOO_SMALL');
    if (!reliableFlow) reasons.add('GEOMETRY_FLOW_NOT_RELIABLE');

    final realityEvidence = enoughRegions &&
        sufficientMotion &&
        reliableFlow &&
        dispersion >= 0.28 &&
        direction >= 0.38 &&
        planar <= 0.68;

    // A plane is only corroborating evidence. Paper, walls and paintings can
    // also be planar, so planarity must never become display proof by itself.
    final planarEvidence = enoughRegions &&
        sufficientMotion &&
        reliableFlow &&
        dispersion <= 0.20 &&
        direction >= 0.72 &&
        planar >= 0.70;

    if (realityEvidence) {
      reasons.add('MULTI_DEPTH_PARALLAX_DETECTED');
      reasons.add('NON_PLANAR_CAMERA_MOTION_RESPONSE');
    } else if (planarEvidence) {
      reasons.add('COHERENT_PLANAR_MOTION_DETECTED');
      reasons.add('PLANARITY_IS_CORROBORATION_ONLY');
    } else if (enoughRegions && sufficientMotion && reliableFlow) {
      reasons.add('GEOMETRY_RESPONSE_AMBIGUOUS');
    }

    return HCVSceneGeometryClassification(
      sceneClass: realityEvidence
          ? 'REALITY'
          : planarEvidence
              ? 'PLANAR'
              : 'UNKNOWN',
      realityEvidence: realityEvidence,
      planarEvidence: planarEvidence,
      motionMagnitude: motion,
      flowReliability: reliability,
      directionCoherence: direction,
      depthDispersion: dispersion,
      planarCoherence: planar,
      matchedRegions: max(0, matchedRegions),
      reasons: reasons,
    );
  }
}
