class HCVTrustAnalyzer {
  static Map<String, dynamic> analyze({
    required Map<String, dynamic>? liveSignals,
    bool audioCaptured = false,
    String captureMode = "standard",
  }) {
    const mode = "standard";

    if (liveSignals == null) {
      return {
        "trustLevel": "BASIC",
        "captureMode": mode,
        "liveCaptureTrust": "NOT_RECORDED",
        "screenReplayRisk": "UNKNOWN",
        "syntheticRisk": "UNKNOWN",
        "sceneAuthenticity": "UNKNOWN",
        "audioTrust": audioCaptured ? "RECORDED" : "NOT_RECORDED",
        "reason": "No live sensor signals recorded",
      };
    }

    final accSamples = liveSignals["accelerometerSamples"] ?? 0;
    final gyroSamples = liveSignals["gyroscopeSamples"] ?? 0;
    final accMotion = (liveSignals["accelerometerMotionScore"] ?? 0).toDouble();
    final gyroMotion = (liveSignals["gyroscopeMotionScore"] ?? 0).toDouble();
    final continuity = liveSignals["continuity"]?.toString() ?? "UNKNOWN";

    var score = 0;
    if (accSamples >= 20) score += 20;
    if (gyroSamples >= 20) score += 20;
    if (continuity == "RECORDED") score += 20;
    if (audioCaptured) score += 10;
    if (accMotion > 0.05 || gyroMotion > 0.02) score += 15;
    if (accMotion > 0.5 || gyroMotion > 0.1) score += 15;
    if (score > 100) score = 100;

    late final String trustLevel;
    late final String liveCaptureTrust;
    late final String screenReplayRisk;
    late final String syntheticRisk;
    late final String sceneAuthenticity;

    if (score >= 80) {
      trustLevel = "HCV_LIVE";
      liveCaptureTrust = "HIGH";
      screenReplayRisk = "REDUCED";
      syntheticRisk = "REDUCED";
      sceneAuthenticity = "LIVE_CAPTURE_SUPPORTED";
    } else if (score >= 40) {
      trustLevel = "HCV_PARTIAL_LIVE";
      liveCaptureTrust = "MEDIUM";
      screenReplayRisk = "PARTIALLY_REDUCED";
      syntheticRisk = "PARTIALLY_REDUCED";
      sceneAuthenticity = "PARTIAL_LIVE_SIGNALS";
    } else {
      trustLevel = "HCV_BASIC";
      liveCaptureTrust = "LOW";
      screenReplayRisk = "UNKNOWN";
      syntheticRisk = "UNKNOWN";
      sceneAuthenticity = "NOT_ENOUGH_SIGNALS";
    }

    return {
      "trustLevel": trustLevel,
      "captureMode": mode,
      "score": score,
      "liveCaptureTrust": liveCaptureTrust,
      "screenReplayRisk": screenReplayRisk,
      "syntheticRisk": syntheticRisk,
      "sceneAuthenticity": sceneAuthenticity,
      "audioTrust": audioCaptured ? "RECORDED" : "NOT_RECORDED",
      "audioCaptured": audioCaptured,
      "accelerometerSamples": accSamples,
      "gyroscopeSamples": gyroSamples,
      "accelerometerMotionScore": accMotion,
      "gyroscopeMotionScore": gyroMotion,
      "continuity": continuity,
      "note":
          "Standard passive live-capture trust analysis. Device motion supports capture continuity but is not absolute proof against AI or screen replay.",
    };
  }
}
