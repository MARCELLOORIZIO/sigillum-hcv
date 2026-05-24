class HCVTrustAnalyzer {
  static Map<String, dynamic> analyze({
    required Map<String, dynamic>? liveSignals,
    bool audioCaptured = false,
    String captureMode = "field",
  }) {
    final mode = captureMode == "studio" ? "studio" : "field";

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

    int score = 0;

    if (accSamples >= 20) score += 20;
    if (gyroSamples >= 20) score += 20;
    if (continuity == "RECORDED") score += 20;
    if (audioCaptured) score += 10;

    if (mode == "studio") {
      score += 20;
      if (accMotion > 0.05 || gyroMotion > 0.02) score += 10;
      if (accMotion > 0.5 || gyroMotion > 0.1) score += 10;
    } else {
      if (accMotion > 0.5) score += 20;
      if (gyroMotion > 0.1) score += 20;
    }

    if (score > 100) score = 100;

    String trustLevel;
    String liveCaptureTrust;
    String screenReplayRisk;
    String syntheticRisk;
    String sceneAuthenticity;

    if (score >= 80) {
      trustLevel = mode == "studio" ? "HCV_STUDIO_LIVE" : "HCV_LIVE";
      liveCaptureTrust = mode == "studio" ? "STUDIO_HIGH" : "HIGH";
      screenReplayRisk = "REDUCED";
      syntheticRisk = "REDUCED";
      sceneAuthenticity = mode == "studio"
          ? "STUDIO_LIVE_CAPTURE_SUPPORTED"
          : "LIVE_CAPTURE_SUPPORTED";
    } else if (score >= 40) {
      trustLevel =
          mode == "studio" ? "HCV_STUDIO_PARTIAL_LIVE" : "HCV_PARTIAL_LIVE";
      liveCaptureTrust = mode == "studio" ? "STUDIO_MEDIUM" : "MEDIUM";
      screenReplayRisk = "PARTIALLY_REDUCED";
      syntheticRisk = "PARTIALLY_REDUCED";
      sceneAuthenticity = mode == "studio"
          ? "STUDIO_PARTIAL_LIVE_SIGNALS"
          : "PARTIAL_LIVE_SIGNALS";
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
          mode == "studio"
              ? "Studio mode allows a static camera. It is passive live-capture support, not absolute proof against AI or screen replay."
              : "Field mode expects natural device motion. This is passive live-capture trust analysis, not absolute proof against AI.",
    };
  }
}
