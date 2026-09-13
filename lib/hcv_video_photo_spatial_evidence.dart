class HCVVideoPhotoSpatialEvidence {
  const HCVVideoPhotoSpatialEvidence._();

  static const String type = 'SIGILLUM_VIDEO_PHOTO_SPATIAL_EVIDENCE_V1';

  static Map<String, dynamic> analyze(List<Map<String, dynamic>> rawAnalyses) {
    final frames = rawAnalyses
        .where((frame) => frame['analysisStatus'] != 'NOT_ANALYZED')
        .map(Map<String, dynamic>.from)
        .toList();

    frames.sort((a, b) {
      final ai = (a['videoFrameIndex'] as num?)?.toInt();
      final bi = (b['videoFrameIndex'] as num?)?.toInt();
      if (ai != null && bi != null) return ai.compareTo(bi);
      final at = (a['approxVideoSecond'] as num?)?.toDouble() ?? 0.0;
      final bt = (b['approxVideoSecond'] as num?)?.toDouble() ?? 0.0;
      return at.compareTo(bt);
    });

    if (frames.isEmpty) {
      return const <String, dynamic>{
        'type': type,
        'analysisStatus': 'NOT_ANALYZED',
        'framesAnalyzed': 0,
        'sceneContinuity': 'UNKNOWN',
        'sceneTransitionDetected': false,
        'stableFullFrameScreenCorroboration': false,
        'stableRealityCorroboration': false,
      };
    }

    var screenSemanticFrameCount = 0;
    var realitySemanticFrameCount = 0;
    var unknownSemanticFrameCount = 0;
    var highProbabilityScreenFrameCount = 0;
    var fullFrame90ScreenFrameCount = 0;
    var content75ScreenFrameCount = 0;
    var content85ScreenFrameCount = 0;
    var spatiallySupportedScreenFrameCount = 0;
    var strictPhotoSpatialFrameCount = 0;
    var transitionCount = 0;

    final screenProbabilities = <double>[];
    final fullFrameScores = <num>[];
    final contentAreaScores = <num>[];
    final riskScores = <num>[];
    final allScreenProbabilities = <double>[];
    final summaries = <Map<String, dynamic>>[];

    String? previousKnownFamily;

    for (final frame in frames) {
      final predictedClass = frame['predictedClass']?.toString() ?? '';
      final family = _semanticFamily(predictedClass);
      final probability =
          (frame['screenProbability'] as num?)?.toDouble() ?? 0.0;
      final confidence =
          (frame['predictedClassConfidence'] as num?)?.toDouble() ?? 0.0;
      final risk =
          (frame['screenReplayRiskScore'] as num?)?.toInt() ??
          (probability * 100).round();
      final rawSignals = frame['signals'];
      final signals = rawSignals is Map
          ? Map<String, dynamic>.from(rawSignals)
          : const <String, dynamic>{};
      final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
      final contentArea =
          (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;

      allScreenProbabilities.add(probability);
      riskScores.add(risk);

      if (family == 'SCREEN') {
        screenSemanticFrameCount++;
        screenProbabilities.add(probability);
        fullFrameScores.add(fullFrame);
        contentAreaScores.add(contentArea);
        if (probability >= 0.90) highProbabilityScreenFrameCount++;
        if (fullFrame >= 90) fullFrame90ScreenFrameCount++;
        if (contentArea >= 75) content75ScreenFrameCount++;
        if (contentArea >= 85) content85ScreenFrameCount++;
        if (probability >= 0.90 && fullFrame >= 90 && contentArea >= 75) {
          spatiallySupportedScreenFrameCount++;
        }
        if (probability >= 0.80 &&
            fullFrame >= 90 &&
            contentArea >= 85 &&
            (confidence == 0.0 || confidence >= 0.75)) {
          strictPhotoSpatialFrameCount++;
        }
      } else if (family == 'REALITY') {
        realitySemanticFrameCount++;
      } else {
        unknownSemanticFrameCount++;
      }

      if (family != 'UNKNOWN') {
        if (previousKnownFamily != null && previousKnownFamily != family) {
          transitionCount++;
        }
        previousKnownFamily = family;
      }

      summaries.add(<String, dynamic>{
        'videoFrameIndex': frame['videoFrameIndex'],
        'approxVideoSecond': frame['approxVideoSecond'],
        'semanticFamily': family,
        'predictedClass': predictedClass,
        'screenProbability': _round(probability),
        'predictedClassConfidence': _round(confidence),
        'screenReplayRiskScore': risk,
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      });
    }

    final frameCount = frames.length;
    final averageRisk = _average(riskScores);
    final medianScreenProbability = _median(screenProbabilities);
    final medianFullFrame = _median(fullFrameScores);
    final medianContentArea = _median(contentAreaScores);
    final maxScreenProbability = allScreenProbabilities.reduce(
      (a, b) => a > b ? a : b,
    );
    final maxRisk = riskScores
        .map((value) => value.toInt())
        .reduce((a, b) => a > b ? a : b);

    final stableScreenSequence =
        frameCount >= 3 &&
        screenSemanticFrameCount == frameCount &&
        highProbabilityScreenFrameCount == frameCount &&
        transitionCount == 0;
    final stableFullFrameScreenCorroboration =
        stableScreenSequence &&
        fullFrame90ScreenFrameCount >= 2 &&
        spatiallySupportedScreenFrameCount >= 2 &&
        (medianFullFrame ?? 0.0) >= 90.0 &&
        (medianContentArea ?? 0.0) >= 75.0 &&
        (averageRisk ?? 0.0) >= 90.0;
    final stableRealityCorroboration =
        frameCount >= 3 &&
        realitySemanticFrameCount == frameCount &&
        transitionCount == 0 &&
        maxScreenProbability <= 0.35 &&
        maxRisk <= 35;

    final sceneContinuity = stableScreenSequence
        ? 'STABLE_SCREEN'
        : stableRealityCorroboration
        ? 'STABLE_REALITY'
        : transitionCount > 0
        ? 'TRANSITION'
        : screenSemanticFrameCount > 0 && realitySemanticFrameCount > 0
        ? 'MIXED'
        : 'UNKNOWN';

    return <String, dynamic>{
      'type': type,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frameCount,
      'screenSemanticFrameCount': screenSemanticFrameCount,
      'realitySemanticFrameCount': realitySemanticFrameCount,
      'unknownSemanticFrameCount': unknownSemanticFrameCount,
      'highProbabilityScreenFrameCount': highProbabilityScreenFrameCount,
      'fullFrame90ScreenFrameCount': fullFrame90ScreenFrameCount,
      'content75ScreenFrameCount': content75ScreenFrameCount,
      'content85ScreenFrameCount': content85ScreenFrameCount,
      'spatiallySupportedScreenFrameCount': spatiallySupportedScreenFrameCount,
      'strictPhotoSpatialFrameCount': strictPhotoSpatialFrameCount,
      'medianScreenProbability': _nullableRound(medianScreenProbability),
      'medianFullFrameRiskScore': _nullableRound(medianFullFrame),
      'medianContentAreaRiskScore': _nullableRound(medianContentArea),
      'averageScreenReplayRiskScore': _nullableRound(averageRisk),
      'maxScreenProbability': _round(maxScreenProbability),
      'maxScreenReplayRiskScore': maxRisk,
      'sceneContinuity': sceneContinuity,
      'sceneTransitionDetected': transitionCount > 0,
      'semanticTransitionCount': transitionCount,
      'stableScreenSequence': stableScreenSequence,
      'stableFullFrameScreenCorroboration': stableFullFrameScreenCorroboration,
      'stableRealityCorroboration': stableRealityCorroboration,
      'frameSequence': summaries,
      'note': 'Spatial PHOTO-like diagnostics aggregated across chronologically ordered video ML frames. This is corroboration, not independent proof.',
    };
  }

  static String _semanticFamily(String predictedClass) {
    if (predictedClass.startsWith('SCREEN_')) return 'SCREEN';
    if (predictedClass.startsWith('REALITY_')) return 'REALITY';
    return 'UNKNOWN';
  }

  static double? _median(List<num> values) {
    if (values.isEmpty) return null;
    final sorted = values.map((value) => value.toDouble()).toList()..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  static double? _average(List<num> values) {
    if (values.isEmpty) return null;
    return values.fold<double>(0.0, (sum, value) => sum + value.toDouble()) /
        values.length;
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(6));

  static double? _nullableRound(double? value) =>
      value == null ? null : _round(value);
}
