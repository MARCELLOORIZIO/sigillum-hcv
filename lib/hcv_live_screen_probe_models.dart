part of 'hcv_live_screen_probe.dart';

class _FrameStats {
  const _FrameStats({
    required this.phase,
    required this.meanLuma,
    required this.tileMeans,
    required this.bandMeans,
    required this.bandContrast,
    required this.fineStripeScore,
    required this.fineGridScore,
    required this.moireFrequencyScore,
    required this.geometryWidth,
    required this.geometryHeight,
    required this.geometryLuma,
  });

  final int phase;
  final double meanLuma;
  final List<double> tileMeans;
  final List<double> bandMeans;
  final double bandContrast;
  final double fineStripeScore;
  final double fineGridScore;
  final double moireFrequencyScore;
  final int geometryWidth;
  final int geometryHeight;
  final List<double> geometryLuma;
}

class _FlowVector {
  const _FlowVector({
    required this.dx,
    required this.dy,
    required this.quality,
  });

  final double dx;
  final double dy;
  final double quality;
}

class _GeometryMetrics {
  const _GeometryMetrics({
    required this.motionMagnitude,
    required this.flowReliability,
    required this.directionCoherence,
    required this.depthDispersion,
    required this.planarCoherence,
    required this.matchedRegions,
  });

  const _GeometryMetrics.empty()
      : motionMagnitude = 0,
        flowReliability = 0,
        directionCoherence = 0,
        depthDispersion = 0,
        planarCoherence = 0,
        matchedRegions = 0;

  final double motionMagnitude;
  final double flowReliability;
  final double directionCoherence;
  final double depthDispersion;
  final double planarCoherence;
  final int matchedRegions;
}

class _PassiveMetrics {
  const _PassiveMetrics({
    required this.globalFlicker,
    required this.localFlicker,
    required this.refreshBand,
    required this.fineStripe,
    required this.fineGrid,
    required this.moire,
    required this.bandTemporal,
    required this.electronicLight,
    required this.stableExposure,
  });

  final double globalFlicker;
  final double localFlicker;
  final double refreshBand;
  final double fineStripe;
  final double fineGrid;
  final double moire;
  final double bandTemporal;
  final double electronicLight;
  final double stableExposure;
}

class _FlashResponseProfile {
  const _FlashResponseProfile({
    required this.globalLiftRatio,
    required this.responsiveTileFraction,
    required this.responseEntropy,
    required this.hotspotConcentration,
  });

  const _FlashResponseProfile.empty()
      : globalLiftRatio = 0,
        responsiveTileFraction = 0,
        responseEntropy = 0,
        hotspotConcentration = 1;

  final double globalLiftRatio;
  final double responsiveTileFraction;
  final double responseEntropy;
  final double hotspotConcentration;
}
