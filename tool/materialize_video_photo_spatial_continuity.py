from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one match in {path}: found {count}")
    path.write_text(text.replace(old, new, 1))


helper = r'''class HCVVideoPhotoSpatialEvidence {
  const HCVVideoPhotoSpatialEvidence._();

  static const String type = 'SIGILLUM_VIDEO_PHOTO_SPATIAL_EVIDENCE_V1';

  static Map<String, dynamic> analyze(
    List<Map<String, dynamic>> rawAnalyses,
  ) {
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
      final risk = (frame['screenReplayRiskScore'] as num?)?.toInt() ??
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

    final stableScreenSequence = frameCount >= 3 &&
        screenSemanticFrameCount == frameCount &&
        highProbabilityScreenFrameCount == frameCount &&
        transitionCount == 0;
    final stableFullFrameScreenCorroboration = stableScreenSequence &&
        fullFrame90ScreenFrameCount >= 2 &&
        spatiallySupportedScreenFrameCount >= 2 &&
        (medianFullFrame ?? 0.0) >= 90.0 &&
        (medianContentArea ?? 0.0) >= 75.0 &&
        (averageRisk ?? 0.0) >= 90.0;
    final stableRealityCorroboration = frameCount >= 3 &&
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
      'spatiallySupportedScreenFrameCount':
          spatiallySupportedScreenFrameCount,
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
      'stableFullFrameScreenCorroboration':
          stableFullFrameScreenCorroboration,
      'stableRealityCorroboration': stableRealityCorroboration,
      'frameSequence': summaries,
      'note':
          'Spatial PHOTO-like diagnostics aggregated across chronologically ordered video ML frames. This is corroboration, not independent proof.',
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

  static double _round(double value) =>
      double.parse(value.toStringAsFixed(6));

  static double? _nullableRound(double? value) =>
      value == null ? null : _round(value);
}
'''

helper_path = ROOT / 'lib/hcv_video_photo_spatial_evidence.dart'
helper_path.write_text(helper)

classifier_path = ROOT / 'lib/hcv_ml_screen_replay_classifier.dart'
replace_once(
    classifier_path,
    "import 'hcv_ml_model_store.dart';\nimport 'sigillum_edition.dart';",
    "import 'hcv_ml_model_store.dart';\nimport 'hcv_video_photo_spatial_evidence.dart';\nimport 'sigillum_edition.dart';",
)
replace_once(
    classifier_path,
    "      analyses.sort((a, b) {\n",
    "      final videoPhotoSpatialEvidence =\n          HCVVideoPhotoSpatialEvidence.analyze(analyses);\n\n      analyses.sort((a, b) {\n",
)
replace_once(
    classifier_path,
    "      worst['videoFrameAnalyses'] = analyses.take(12).toList();\n      return worst;",
    "      worst['videoFrameAnalyses'] = analyses.take(12).toList();\n      worst['videoPhotoSpatialEvidence'] = videoPhotoSpatialEvidence;\n      return worst;",
)

fusion_path = ROOT / 'lib/hcv_display_risk_fusion.dart'
replace_once(
    fusion_path,
    "    final narrowThreeFrameFullFrameRecoveryV109 =\n        v3Analyzed &&\n        !mixedScene &&\n        !physicalDisplay &&\n        temporalFrames == 3 &&\n        highAnyScreenFrames == 3 &&\n        highFullFrameScreenFrames == 0 &&\n        recoveredFullFrameScreenFrames >= 2 &&\n        _hasExactlyThreeHighProbabilityScreenSemanticFramesV109(temporalMl) &&\n        mlStrongScreenFrames == 3 &&\n        mlAverageScreenRisk >= 90.0 &&\n        base.decision == 'STRONG_DISPLAY_RISK' &&\n        base.reasons.contains(\n          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',\n        ) &&\n        base.reasons.contains('ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION');\n\n    final screenPresentButNotFullFrame =",
    "    final narrowThreeFrameFullFrameRecoveryV109 =\n        v3Analyzed &&\n        !mixedScene &&\n        !physicalDisplay &&\n        temporalFrames == 3 &&\n        highAnyScreenFrames == 3 &&\n        highFullFrameScreenFrames == 0 &&\n        recoveredFullFrameScreenFrames >= 2 &&\n        _hasExactlyThreeHighProbabilityScreenSemanticFramesV109(temporalMl) &&\n        mlStrongScreenFrames == 3 &&\n        mlAverageScreenRisk >= 90.0 &&\n        base.decision == 'STRONG_DISPLAY_RISK' &&\n        base.reasons.contains(\n          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',\n        ) &&\n        base.reasons.contains('ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION');\n    final videoPhotoSpatialFullFrameCorroboration =\n        v3Analyzed &&\n        !mixedScene &&\n        !physicalDisplay &&\n        temporalFrames >= 3 &&\n        _hasStableVideoPhotoSpatialFullFrameCorroboration(temporalMl) &&\n        base.decision == 'STRONG_DISPLAY_RISK' &&\n        base.reasons.contains(\n          'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',\n        ) &&\n        base.reasons.contains('ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION');\n\n    final screenPresentButNotFullFrame =",
)
replace_once(
    fusion_path,
    "        !narrowThreeFrameFullFrameRecoveryV109 &&\n        temporalFrames >= 2 &&",
    "        !narrowThreeFrameFullFrameRecoveryV109 &&\n        !videoPhotoSpatialFullFrameCorroboration &&\n        temporalFrames >= 2 &&",
)
replace_once(
    fusion_path,
    "    final persistentVisualDisplay =\n        strictPersistentVisualDisplay || narrowThreeFrameFullFrameRecoveryV109;",
    "    final persistentVisualDisplay =\n        strictPersistentVisualDisplay ||\n        narrowThreeFrameFullFrameRecoveryV109 ||\n        videoPhotoSpatialFullFrameCorroboration;",
)
replace_once(
    fusion_path,
    "      if (persistentVisualDisplay) {\n        evidenceSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');\n        strongSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');\n        if (narrowThreeFrameFullFrameRecoveryV109) {\n          reasons.add('THREE_HIGH_PROBABILITY_SCREEN_SEMANTIC_FRAMES');\n          reasons.add('TWO_FULL_FRAME_SCREEN_SAMPLES_WITH_CONTENT_SUPPORT_75');\n          reasons.add('ML_THREE_FRAME_FULL_FRAME_SCREEN_RECOVERY_V109');\n        } else {\n          reasons.add('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES');\n        }\n      }",
    "      if (persistentVisualDisplay) {\n        evidenceSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');\n        strongSources.add('FULL_FRAME_TEMPORAL_SCREEN_PERSISTENCE');\n        if (strictPersistentVisualDisplay) {\n          reasons.add('TWO_HIGH_FULL_FRAME_SCREEN_TEMPORAL_SAMPLES');\n        }\n        if (narrowThreeFrameFullFrameRecoveryV109) {\n          reasons.add('THREE_HIGH_PROBABILITY_SCREEN_SEMANTIC_FRAMES');\n          reasons.add('TWO_FULL_FRAME_SCREEN_SAMPLES_WITH_CONTENT_SUPPORT_75');\n          reasons.add('ML_THREE_FRAME_FULL_FRAME_SCREEN_RECOVERY_V109');\n        }\n        if (videoPhotoSpatialFullFrameCorroboration) {\n          evidenceSources.add('VIDEO_PHOTO_SPATIAL_CORROBORATION');\n          strongSources.add('VIDEO_PHOTO_SPATIAL_CORROBORATION');\n          reasons.add('VIDEO_PHOTO_SPATIAL_STABLE_SCREEN_SEQUENCE');\n          reasons.add('VIDEO_PHOTO_SPATIAL_FULL_FRAME_CORROBORATION');\n        }\n      }",
)
replace_once(
    fusion_path,
    "  static bool _isCompleteStrictNegativeHfr(Map<String, dynamic>? probe) {",
    "  static bool _hasStableVideoPhotoSpatialFullFrameCorroboration(\n    Map<String, dynamic>? ml,\n  ) {\n    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;\n    final raw = ml['videoPhotoSpatialEvidence'];\n    if (raw is! Map) return false;\n    final evidence = Map<String, dynamic>.from(raw);\n    return evidence['type'] ==\n            'SIGILLUM_VIDEO_PHOTO_SPATIAL_EVIDENCE_V1' &&\n        evidence['analysisStatus'] == 'ANALYZED' &&\n        evidence['stableScreenSequence'] == true &&\n        evidence['stableFullFrameScreenCorroboration'] == true &&\n        evidence['sceneTransitionDetected'] != true;\n  }\n\n  static bool _isCompleteStrictNegativeHfr(Map<String, dynamic>? probe) {",
)

helper_test = r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_video_photo_spatial_evidence.dart';

Map<String, dynamic> _frame({
  required int index,
  required String predictedClass,
  required double screenProbability,
  required int fullFrame,
  required int contentArea,
  double confidence = 0.95,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'videoFrameIndex': index,
      'approxVideoSecond': index.toDouble(),
      'predictedClass': predictedClass,
      'predictedClassConfidence': confidence,
      'screenProbability': screenProbability,
      'screenReplayRiskScore': (screenProbability * 100).round(),
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

void main() {
  test('HCV-4A2F-like frames form stable PHOTO-like full-frame evidence', () {
    final evidence = HCVVideoPhotoSpatialEvidence.analyze(<Map<String, dynamic>>[
      _frame(
        index: 0,
        predictedClass: 'SCREEN_MONITOR',
        screenProbability: 0.9578,
        fullFrame: 96,
        contentArea: 75,
      ),
      _frame(
        index: 1,
        predictedClass: 'SCREEN_MONITOR',
        screenProbability: 0.9225,
        fullFrame: 92,
        contentArea: 76,
      ),
      _frame(
        index: 2,
        predictedClass: 'SCREEN_MONITOR',
        screenProbability: 0.9179,
        fullFrame: 92,
        contentArea: 59,
      ),
    ]);

    expect(evidence['sceneContinuity'], 'STABLE_SCREEN');
    expect(evidence['sceneTransitionDetected'], false);
    expect(evidence['spatiallySupportedScreenFrameCount'], 2);
    expect(evidence['strictPhotoSpatialFrameCount'], 0);
    expect(evidence['medianFullFrameRiskScore'], 92.0);
    expect(evidence['medianContentAreaRiskScore'], 75.0);
    expect(evidence['stableFullFrameScreenCorroboration'], true);
  });

  test('archive-60-like sequence remains stable despite one strict PHOTO frame', () {
    final evidence = HCVVideoPhotoSpatialEvidence.analyze(<Map<String, dynamic>>[
      _frame(
        index: 0,
        predictedClass: 'SCREEN_MONITOR',
        screenProbability: 0.9903,
        fullFrame: 99,
        contentArea: 82,
      ),
      _frame(
        index: 1,
        predictedClass: 'SCREEN_MONITOR',
        screenProbability: 0.9787,
        fullFrame: 98,
        contentArea: 81,
      ),
      _frame(
        index: 2,
        predictedClass: 'SCREEN_MONITOR',
        screenProbability: 0.9819,
        fullFrame: 98,
        contentArea: 89,
      ),
    ]);

    expect(evidence['strictPhotoSpatialFrameCount'], 1);
    expect(evidence['stableFullFrameScreenCorroboration'], true);
    expect(evidence['medianContentAreaRiskScore'], 82.0);
  });

  test('chronology is reconstructed from videoFrameIndex before transition analysis', () {
    final evidence = HCVVideoPhotoSpatialEvidence.analyze(<Map<String, dynamic>>[
      _frame(
        index: 2,
        predictedClass: 'REALITY_ROOM',
        screenProbability: 0.03,
        fullFrame: 5,
        contentArea: 7,
      ),
      _frame(
        index: 0,
        predictedClass: 'SCREEN_MONITOR',
        screenProbability: 0.94,
        fullFrame: 94,
        contentArea: 80,
      ),
      _frame(
        index: 1,
        predictedClass: 'REALITY_ROOM',
        screenProbability: 0.05,
        fullFrame: 8,
        contentArea: 10,
      ),
    ]);

    final sequence = (evidence['frameSequence'] as List)
        .map((item) => (item as Map)['semanticFamily'])
        .toList();
    expect(sequence, <String>['SCREEN', 'REALITY', 'REALITY']);
    expect(evidence['sceneContinuity'], 'TRANSITION');
    expect(evidence['sceneTransitionDetected'], true);
    expect(evidence['stableFullFrameScreenCorroboration'], false);
  });

  test('stable all-reality sequence is recorded without display corroboration', () {
    final evidence = HCVVideoPhotoSpatialEvidence.analyze(<Map<String, dynamic>>[
      for (var i = 0; i < 4; i++)
        _frame(
          index: i,
          predictedClass: 'REALITY_ROOM',
          screenProbability: 0.08 + i * 0.01,
          fullFrame: 10,
          contentArea: 12,
        ),
    ]);

    expect(evidence['sceneContinuity'], 'STABLE_REALITY');
    expect(evidence['stableRealityCorroboration'], true);
    expect(evidence['stableFullFrameScreenCorroboration'], false);
  });
}
'''
(ROOT / 'test/video_photo_spatial_evidence_test.dart').write_text(helper_test)

fusion_test = r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_video_photo_spatial_evidence.dart';

Map<String, dynamic> _frame({
  required int index,
  required String predictedClass,
  required double probability,
  required int fullFrame,
  required int contentArea,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'videoFrameIndex': index,
      'approxVideoSecond': index.toDouble(),
      'predictedClass': predictedClass,
      'predictedClassConfidence': 0.95,
      'screenProbability': probability,
      'screenReplayRiskScore': (probability * 100).round(),
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

Map<String, dynamic> _ml(
  List<Map<String, dynamic>> frames, {
  bool includePhotoSpatial = true,
}) {
  final scores = frames
      .map((frame) => (frame['screenReplayRiskScore'] as num).toInt())
      .toList();
  final strong = scores.where((score) => score >= 92).length;
  final medium = scores.where((score) => score >= 88).length;
  final average = scores.reduce((a, b) => a + b) / scores.length;
  final maxScore = scores.reduce((a, b) => a > b ? a : b);
  final result = <String, dynamic>{
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': maxScore,
    'predictedClass': 'SCREEN_MONITOR',
    'predictedClassConfidence': 0.95,
    'screenProbability': 0.96,
    'framesAnalyzed': frames.length,
    'strongScreenFrameCount': strong,
    'mediumScreenFrameCount': medium,
    'averageScreenReplayRiskScore': average,
    'maxFrameScreenReplayRiskScore': maxScore,
    'signals': const <String, dynamic>{
      'fullFrameRiskScore': 96,
      'contentAreaRiskScore': 82,
    },
    'videoFrameAnalyses': frames,
  };
  if (includePhotoSpatial) {
    result['videoPhotoSpatialEvidence'] =
        HCVVideoPhotoSpatialEvidence.analyze(frames);
  }
  return result;
}

Map<String, dynamic> _quietV32({bool mixed = false}) => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'fullFrameReality': false,
        'positivePhysicalRealityEvidence': false,
        'mixedSceneDetected': mixed,
        'allNineCellsSameDisplayFamily': false,
        'displayLikeCellCount': mixed ? 4 : 0,
        'spatialFamilyCellCount': mixed ? 4 : 0,
        'harmonicAwareSpatialFamilyCellCount': mixed ? 4 : 0,
        'rowTimeFamilyCellCount': mixed ? 4 : 0,
      },
    };

HCVDisplayRiskResult _strongBase() => const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 96,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['ML_SCREEN_CLASS'],
      strongSources: <String>['ML_SCREEN_CLASS'],
      reasons: <String>[
        'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
        'ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION',
      ],
    );

HCVDisplayRiskResult _resolve(Map<String, dynamic> ml, {bool mixed = false}) =>
    HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: _strongBase(),
      passiveOptical: null,
      ml: ml,
      temporalFrequencyProbe: _quietV32(mixed: mixed),
    );

void main() {
  test('four-frame stable PHOTO-like sequence prevents false full-frame veto', () {
    final frames = <Map<String, dynamic>>[
      _frame(index: 0, predictedClass: 'SCREEN_MONITOR', probability: 0.96, fullFrame: 96, contentArea: 82),
      _frame(index: 1, predictedClass: 'SCREEN_MONITOR', probability: 0.95, fullFrame: 95, contentArea: 80),
      _frame(index: 2, predictedClass: 'SCREEN_MONITOR', probability: 0.94, fullFrame: 94, contentArea: 77),
      _frame(index: 3, predictedClass: 'SCREEN_MONITOR', probability: 0.93, fullFrame: 93, contentArea: 60),
    ];

    final result = _resolve(_ml(frames));
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.evidenceSources, contains('VIDEO_PHOTO_SPATIAL_CORROBORATION'));
    expect(result.reasons, contains('VIDEO_PHOTO_SPATIAL_STABLE_SCREEN_SEQUENCE'));
    expect(result.reasons, contains('VIDEO_PHOTO_SPATIAL_FULL_FRAME_CORROBORATION'));
    expect(result.reasons, isNot(contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE')));
  });

  test('absence of the new evidence preserves BUILD109 behavior', () {
    final frames = <Map<String, dynamic>>[
      _frame(index: 0, predictedClass: 'SCREEN_MONITOR', probability: 0.96, fullFrame: 96, contentArea: 82),
      _frame(index: 1, predictedClass: 'SCREEN_MONITOR', probability: 0.95, fullFrame: 95, contentArea: 80),
      _frame(index: 2, predictedClass: 'SCREEN_MONITOR', probability: 0.94, fullFrame: 94, contentArea: 77),
      _frame(index: 3, predictedClass: 'SCREEN_MONITOR', probability: 0.93, fullFrame: 93, contentArea: 60),
    ];

    final result = _resolve(_ml(frames, includePhotoSpatial: false));
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('SCREEN_PRESENT_BUT_NOT_FULL_FRAME_REAL_SCENE'));
    expect(result.evidenceSources, isNot(contains('VIDEO_PHOTO_SPATIAL_CORROBORATION')));
  });

  test('SCREEN to REALITY transition can never activate PHOTO-like promotion', () {
    final frames = <Map<String, dynamic>>[
      _frame(index: 0, predictedClass: 'SCREEN_MONITOR', probability: 0.96, fullFrame: 96, contentArea: 82),
      _frame(index: 1, predictedClass: 'REALITY_ROOM', probability: 0.05, fullFrame: 8, contentArea: 10),
      _frame(index: 2, predictedClass: 'REALITY_ROOM', probability: 0.03, fullFrame: 6, contentArea: 8),
      _frame(index: 3, predictedClass: 'SCREEN_MONITOR', probability: 0.94, fullFrame: 94, contentArea: 80),
    ];
    final ml = _ml(frames);
    final evidence = ml['videoPhotoSpatialEvidence'] as Map;
    expect(evidence['sceneTransitionDetected'], true);
    expect(evidence['stableFullFrameScreenCorroboration'], false);

    final result = _resolve(ml);
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    expect(result.evidenceSources, isNot(contains('VIDEO_PHOTO_SPATIAL_CORROBORATION')));
  });

  test('mixed-scene HFR veto remains absolute', () {
    final frames = <Map<String, dynamic>>[
      for (var i = 0; i < 4; i++)
        _frame(index: i, predictedClass: 'SCREEN_MONITOR', probability: 0.96, fullFrame: 96, contentArea: 82),
    ];

    final result = _resolve(_ml(frames), mixed: true);
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('HFR_V3_MIXED_REAL_SCENE'));
    expect(result.evidenceSources, isNot(contains('VIDEO_PHOTO_SPATIAL_CORROBORATION')));
  });
}
'''
(ROOT / 'test/video_photo_spatial_fusion_test.dart').write_text(fusion_test)

print('Materialized VIDEO PHOTO-like spatial continuity evidence and tests.')
