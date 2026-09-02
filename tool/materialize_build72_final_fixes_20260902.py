from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one replacement target, found {count}")
    p.write_text(text.replace(old, new, 1))


def replace_between(path: str, start_marker: str, end_marker: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text()
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f"{path}: start marker not found: {start_marker!r}")
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"{path}: end marker not found: {end_marker!r}")
    p.write_text(text[:start] + replacement + text[end:])


# ---------------------------------------------------------------------------
# 1) VIDEO REALITY: short geometry-backed REALITY + long semantic REALITY
#    must be able to override isolated active-illumination false positives.
# ---------------------------------------------------------------------------
replace_once(
    "lib/hcv_display_risk_fusion.dart",
    """    return predictedClass.startsWith('REALITY_') &&
        allFramesReality &&
        strongScreenFrameCount == 0 &&
        mediumScreenFrameCount == 0 &&
        averageFrameScore <= 20.0 &&
        maxFrameScore <= 30 &&
        screenProbability <= 0.30;
  }

  static bool _isCredibleRealityMl(
""",
    """    return predictedClass.startsWith('REALITY_') &&
        allFramesReality &&
        strongScreenFrameCount == 0 &&
        mediumScreenFrameCount == 0 &&
        averageFrameScore <= 20.0 &&
        maxFrameScore <= 30 &&
        screenProbability <= 0.30;
  }

  static bool hasShortGeometricSemanticRealityAcrossVideoFrames(
    Map<String, dynamic>? ml,
  ) {
    if (ml == null) return false;
    final predictedClass = ml['predictedClass']?.toString() ?? '';
    final framesAnalyzed = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final strongScreenFrameCount =
        (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;
    final mediumScreenFrameCount =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;
    final screenProbability =
        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;
    final rawFrames = ml['videoFrameAnalyses'];
    if (framesAnalyzed < 2 ||
        framesAnalyzed > 3 ||
        rawFrames is! List ||
        rawFrames.length != framesAnalyzed) {
      return false;
    }
    final allFramesReality = rawFrames.every(
      (frame) =>
          frame is Map &&
          (frame['predictedClass']?.toString() ?? '').startsWith('REALITY_'),
    );

    return predictedClass.startsWith('REALITY_') &&
        allFramesReality &&
        strongScreenFrameCount == 0 &&
        mediumScreenFrameCount == 0 &&
        averageFrameScore <= 20.0 &&
        maxFrameScore <= 30 &&
        screenProbability <= 0.30;
  }

  static bool _isCredibleRealityMl(
""",
)

replace_once(
    "lib/hcv_display_risk_fusion.dart",
    """    final mlSemanticRealityPersistence =
        hasPersistentSemanticRealityAcrossVideoFrames(ml);
    final mlDualRegionPhotoEvidence = hasSpatialScreenCorroboration(ml);
""",
    """    final mlSemanticRealityPersistence =
        hasPersistentSemanticRealityAcrossVideoFrames(ml);
    final mlShortGeometricSemanticReality =
        hasShortGeometricSemanticRealityAcrossVideoFrames(ml);
    final mlDualRegionPhotoEvidence = hasSpatialScreenCorroboration(ml);
""",
)

replace_once(
    "lib/hcv_display_risk_fusion.dart",
    """    final semanticMultiFrameRealityWithoutDisplayCorroboration =
        !liveCaptureOnly &&
            mlSemanticRealityPersistence &&
            !rawActiveDisplayEvidence &&
            !activeDisplayEvidence &&
            liveSignals['confirmedDisplayTrace'] != true &&
            liveSignals['periodicLightTrace'] != true &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate &&
            !mlStrong;
    final geometryRealityWithIndependentNonDisplay =
""",
    """    final semanticMultiFrameRealityWithoutDisplayCorroboration =
        !liveCaptureOnly &&
            mlSemanticRealityPersistence &&
            !liveTemporal &&
            !activeTemporalPhysicalProof &&
            !planarTemporalPhysicalProof &&
            !activePlanarTemporal &&
            liveSignals['confirmedDisplayTrace'] != true &&
            liveSignals['periodicLightTrace'] != true &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate &&
            !mlStrong;
    final shortGeometricSemanticRealityAgreement =
        !liveCaptureOnly &&
            geometrySceneClass == 'REALITY' &&
            !reflectedRealityEvidence &&
            mlShortGeometricSemanticReality &&
            liveSignals['confirmedDisplayTrace'] != true &&
            liveSignals['periodicLightTrace'] != true &&
            !passiveStructuralEvidence &&
            !passiveStrong &&
            !passiveModerate &&
            !mlStrong;
    final geometryRealityWithIndependentNonDisplay =
""",
)

replace_once(
    "lib/hcv_display_risk_fusion.dart",
    """    } else if (semanticMultiFrameRealityWithoutDisplayCorroboration) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.remove('ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add(
        'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
      );
    } else if (geometryRealityWithIndependentNonDisplay) {
""",
    """    } else if (semanticMultiFrameRealityWithoutDisplayCorroboration) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.remove('ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add(
        'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
      );
    } else if (shortGeometricSemanticRealityAgreement) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      strongSources.remove('PHYSICAL_DISPLAY_COMBINATION');
      reasons.remove('PLANAR_GEOMETRY_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.remove('ACTIVE_ILLUMINATION_AND_TEMPORAL_BANDS_CONFIRMED');
      reasons.add('SHORT_VIDEO_GEOMETRIC_AND_SEMANTIC_REALITY_AGREE');
    } else if (geometryRealityWithIndependentNonDisplay) {
""",
)

# The camera wrapper must preserve both explicit final REALITY decisions.
replace_once(
    "lib/camera_page.dart",
    """          normalResult.reasons.contains(
            'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
          ));
""",
    """          normalResult.reasons.contains(
            'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
          ) ||
          normalResult.reasons.contains(
            'SHORT_VIDEO_GEOMETRIC_AND_SEMANTIC_REALITY_AGREE',
          ));
""",
)

# ---------------------------------------------------------------------------
# 2) VIDEO MP4 FINALIZATION: prevent duplicate stop calls and do not copy/
#    analyze the camera file until its size has been stable for several polls.
# ---------------------------------------------------------------------------
replace_once(
    "lib/camera_page.dart",
    """  bool ready = false;
  bool recording = false;

  bool photoMode = false;
""",
    """  bool ready = false;
  bool recording = false;
  bool _videoFinalizeInProgress = false;

  bool photoMode = false;
""",
)

replace_between(
    "lib/camera_page.dart",
    "  Future<void> stop() async {",
    "\n  Future<void> takePhoto() async {",
    """  Future<void> _waitForFinalizedVideoContainer(String path) async {
    final file = File(path);
    const pollInterval = Duration(milliseconds: 250);
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    int? lastSize;
    var stableReads = 0;

    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await file.exists()) {
          final size = await file.length();
          if (size > 1024 && lastSize == size) {
            stableReads++;
            if (stableReads >= 3) return;
          } else {
            lastSize = size;
            stableReads = 0;
          }
        }
      } catch (_) {
        stableReads = 0;
      }
      await Future.delayed(pollInterval);
    }

    throw StateError('VIDEO_CONTAINER_NOT_FINALIZED');
  }

  Future<void> stop() async {
    if (controller == null || _videoFinalizeInProgress) return;
    _videoFinalizeInProgress = true;

    try {
      final file = await controller!.stopVideoRecording();

      try {
        lastLiveSignals = await liveSignals.stopAndBuildSummary();
      } catch (_) {
        lastLiveSignals = null;
      }

      await _waitForFinalizedVideoContainer(file.path);

      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
      final captureLocation = pendingVideoLocation;
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;

      setState(() {
        recording = false;
        status = _c('processingVideo');
      });

      await processVideo(
        file.path,
        capturedAt: capturedAt,
        captureLocation: captureLocation,
      );
    } catch (e) {
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;
      pendingLiveScreenProbe = null;
      try {
        lastLiveSignals = await liveSignals.stopAndBuildSummary();
      } catch (_) {
        lastLiveSignals = null;
      }
      if (mounted) {
        setState(() {
          recording = false;
          status = '${_c('stopError')}: $e';
        });
      }
    } finally {
      _videoFinalizeInProgress = false;
    }
  }
""",
)

replace_between(
    "lib/camera_page.dart",
    "  Future<String> saveVideoToDownloadsTemporary(String sourcePath) async {",
    "\n  Future<String> savePhotoToDocuments(String sourcePath) async {",
    """  Future<String> saveVideoToDownloadsTemporary(String sourcePath) async {
    final dir = await _downloadsDirectory();

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Recorded video source not found', sourcePath);
    }
    final sourceSize = await sourceFile.length();
    if (sourceSize <= 1024) {
      throw StateError('VIDEO_CONTAINER_TOO_SMALL');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final savedPath = p.join(dir.path, 'hcv_video_$timestamp.mp4');
    final savedFile = await sourceFile.copy(savedPath);
    final copiedSize = await savedFile.length();
    if (copiedSize != sourceSize) {
      try {
        await savedFile.delete();
      } catch (_) {}
      throw StateError('VIDEO_CONTAINER_CHANGED_DURING_COPY');
    }

    return savedFile.path;
  }
""",
)

replace_once(
    "lib/camera_page.dart",
    """                      GestureDetector(
                        onTap: !ready
                            ? null
                            : () async {
""",
    """                      GestureDetector(
                        onTap: !ready || _videoFinalizeInProgress
                            ? null
                            : () async {
""",
)

# ---------------------------------------------------------------------------
# 3) VERIFY UI: "Nessun indizio display" must never be swallowed by the
#    generic contains("display") branch and shown as "Possibile schermo".
# ---------------------------------------------------------------------------
replace_once(
    "lib/registry_verify_page.dart",
    """    if (axis == 'scene' &&
        (value.contains('forte rischio') || value.contains('display')))
      return _v('screenRisk');
    if (axis == 'scene' && value.contains('conclusiva'))
      return _v('sceneUncertain');
    if (axis == 'scene' && value.contains('nessun'))
      return _v('noScreenEvidence');
""",
    """    if (axis == 'scene' && value.contains('nessun'))
      return _v('noScreenEvidence');
    if (axis == 'scene' && value.contains('conclusiva'))
      return _v('sceneUncertain');
    if (axis == 'scene' && value.contains('forte rischio'))
      return _v('screenRisk');
""",
)

# ---------------------------------------------------------------------------
# Regression tests based on the physical build72 samples and the stop-path bug.
# ---------------------------------------------------------------------------
Path("test/build72_video_reality_and_container_regression_test.dart").write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> _passive({int score = 75, bool structural = false}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'screenReplayRiskScore': score,
      'signals': {
        'structuralDisplayTrace': structural,
        'confirmedDisplayTrace': structural,
        'strongDisplayTrace': score >= 70,
      },
    };

Map<String, dynamic> _live({
  required String sceneClass,
  required String geometryClass,
  bool rawActive = false,
  bool activeDisplay = false,
  bool confirmedDisplay = false,
  bool periodicLight = false,
  bool planar = false,
  int score = 45,
  String decision = 'NON_CONCLUSIVE',
  double localFlicker = 0.10,
  double refreshBand = 0.05,
  double globalFlicker = 0.05,
  bool displayBand = false,
  bool horizontalBands = false,
}) => {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 5,
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 45,
      'screenReplayRiskScore': score,
      'displayRiskDecision': decision,
      'sceneClass': sceneClass,
      'reason': geometryClass == 'REALITY'
          ? 'ACTIVE_V5|MULTI_DEPTH_PARALLAX_DETECTED|NON_PLANAR_CAMERA_MOTION_RESPONSE'
          : 'ACTIVE_V5|GEOMETRY_RESPONSE_AMBIGUOUS',
      'videoEquivalentAvailable': false,
      'localTemporalFlickerScore': localFlicker,
      'refreshBandScore': refreshBand,
      'fineStripeScore': 0.08,
      'fineGridScore': 0.30,
      'moireFrequencyScore': 0.20,
      'persistentPatternScore': 0.20,
      'dynamicChallengeScore': 0.30,
      'globalFlickerScore': globalFlicker,
      'geometryChallenge': {
        'sceneClass': geometryClass,
        'realityEvidence': geometryClass == 'REALITY',
        'planarEvidence': planar,
      },
      'signals': {
        'rawActiveDisplayEvidence': rawActive,
        'activeIlluminationDisplayEvidence': activeDisplay,
        'reflectedRealityEvidence': false,
        'planarSceneEvidence': planar,
        'activeChallengeIndeterminate': false,
        'confirmedDisplayTrace': confirmedDisplay,
        'periodicLightTrace': periodicLight,
        'strongRefreshTrace': displayBand,
        'displayBandTrace': displayBand,
        'opticalStripeTrace': false,
        'opticalCorroboratedTrace': false,
        'moireFrequencyTrace': displayBand,
        'pairedFlickerTrace': displayBand,
        'horizontalRefreshBands': horizontalBands,
        'uncorroboratedDisplayPattern': !confirmedDisplay,
      },
    };

Map<String, dynamic> _ml({
  required String predictedClass,
  required double confidence,
  required double screenProbability,
  required int score,
  required int frames,
  required int strongFrames,
  required int mediumFrames,
  required double average,
  required int maxFrame,
  required List<String> frameClasses,
  int fullFrameRisk = 0,
  int contentAreaRisk = 0,
}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'screenReplayRiskScore': score,
      'displayRiskDecision': score >= 88
          ? 'STRONG_DISPLAY_RISK'
          : score >= 45
              ? 'NON_CONCLUSIVE'
              : 'NO_DISPLAY_EVIDENCE',
      'predictedClass': predictedClass,
      'predictedClassConfidence': confidence,
      'screenProbability': screenProbability,
      'framesAnalyzed': frames,
      'strongScreenFrameCount': strongFrames,
      'mediumScreenFrameCount': mediumFrames,
      'averageScreenReplayRiskScore': average,
      'maxFrameScreenReplayRiskScore': maxFrame,
      'signals': {
        'fullFrameRiskScore': fullFrameRisk,
        'contentAreaRiskScore': contentAreaRisk,
      },
      'videoFrameAnalyses': [
        for (final frameClass in frameClasses)
          {'predictedClass': frameClass},
      ],
    };

void main() {
  test('build72 E86 short REALITY resolves isolated active false positive', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'REALITY',
        geometryClass: 'REALITY',
        rawActive: true,
        activeDisplay: true,
        localFlicker: 0.34,
        refreshBand: 0.18,
        globalFlicker: 0.10,
        displayBand: true,
        horizontalBands: true,
      ),
      _passive(score: 75, structural: false),
      _ml(
        predictedClass: 'REALITY_PAPER',
        confidence: 0.5582,
        screenProbability: 0.2218,
        score: 22,
        frames: 2,
        strongFrames: 0,
        mediumFrames: 0,
        average: 18.5,
        maxFrame: 22,
        frameClasses: const ['REALITY_PAPER', 'REALITY_PAPER'],
      ),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
    expect(
      result.reasons,
      contains('SHORT_VIDEO_GEOMETRIC_AND_SEMANTIC_REALITY_AGREE'),
    );
  });

  test('build72 3E long unanimous REALITY ignores active-only false positive', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'UNKNOWN',
        rawActive: true,
        activeDisplay: true,
      ),
      _passive(score: 75, structural: false),
      _ml(
        predictedClass: 'REALITY_OUTDOOR',
        confidence: 0.567,
        screenProbability: 0.0986,
        score: 10,
        frames: 6,
        strongFrames: 0,
        mediumFrames: 0,
        average: 5.6667,
        maxFrame: 10,
        frameClasses: const [
          'REALITY_OUTDOOR',
          'REALITY_ROOM',
          'REALITY_PAPER',
          'REALITY_PAPER',
          'REALITY_ROOM',
          'REALITY_PAPER',
        ],
      ),
    ]);

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
    expect(
      result.reasons,
      contains(
        'MULTI_FRAME_SEMANTIC_REALITY_RESOLVES_UNCORROBORATED_DISPLAY_SIGNALS',
      ),
    );
  });

  test('persistent SCREEN remains strong even against REALITY geometry', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'REALITY',
        geometryClass: 'REALITY',
        score: 20,
        decision: 'NO_DISPLAY_EVIDENCE',
      ),
      _passive(score: 20, structural: false),
      _ml(
        predictedClass: 'SCREEN_MONITOR',
        confidence: 0.98,
        screenProbability: 0.9882,
        score: 99,
        frames: 4,
        strongFrames: 3,
        mediumFrames: 3,
        average: 95.25,
        maxFrame: 99,
        fullFrameRisk: 99,
        contentAreaRisk: 93,
        frameClasses: const [
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
          'SCREEN_MONITOR',
        ],
      ),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });

  test('confirmed live display evidence blocks semantic REALITY override', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'UNKNOWN',
        rawActive: true,
        activeDisplay: true,
        confirmedDisplay: true,
        periodicLight: true,
        score: 75,
        decision: 'STRONG_DISPLAY_RISK',
      ),
      _passive(score: 20, structural: false),
      _ml(
        predictedClass: 'REALITY_ROOM',
        confidence: 0.95,
        screenProbability: 0.05,
        score: 5,
        frames: 6,
        strongFrames: 0,
        mediumFrames: 0,
        average: 5,
        maxFrame: 8,
        frameClasses: const [
          'REALITY_ROOM',
          'REALITY_ROOM',
          'REALITY_ROOM',
          'REALITY_ROOM',
          'REALITY_ROOM',
          'REALITY_ROOM',
        ],
      ),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });

  test('short semantic REALITY does not override PLANAR geometry', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      _live(
        sceneClass: 'UNKNOWN',
        geometryClass: 'PLANAR',
        planar: true,
        rawActive: true,
        activeDisplay: true,
      ),
      _passive(score: 20, structural: false),
      _ml(
        predictedClass: 'REALITY_PAPER',
        confidence: 0.80,
        screenProbability: 0.10,
        score: 10,
        frames: 2,
        strongFrames: 0,
        mediumFrames: 0,
        average: 8,
        maxFrame: 10,
        frameClasses: const ['REALITY_PAPER', 'REALITY_PAPER'],
      ),
    ]);

    expect(result.decision, isNot('NO_DISPLAY_EVIDENCE'));
  });

  test('camera stop path serializes finalization before video processing', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains('bool _videoFinalizeInProgress = false;'));
    expect(
      source,
      contains('if (controller == null || _videoFinalizeInProgress) return;'),
    );
    expect(source, contains('_waitForFinalizedVideoContainer(file.path)'));
    expect(source, contains('stableReads >= 3'));
    expect(source, contains('Duration(seconds: 6)'));
    expect(source, contains('copiedSize != sourceSize'));
    expect(source, contains('!ready || _videoFinalizeInProgress'));
  });
}
''')

Path("test/build72_verification_scene_copy_contract_test.dart").write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no-display scene state is mapped before screen-risk state', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    const noScreen = "if (axis == 'scene' && value.contains('nessun'))";
    const uncertain = "if (axis == 'scene' && value.contains('conclusiva'))";
    const risk = "if (axis == 'scene' && value.contains('forte rischio'))";

    final noScreenIndex = source.indexOf(noScreen);
    final uncertainIndex = source.indexOf(uncertain);
    final riskIndex = source.indexOf(risk);

    expect(noScreenIndex, greaterThanOrEqualTo(0));
    expect(uncertainIndex, greaterThan(noScreenIndex));
    expect(riskIndex, greaterThan(uncertainIndex));
    expect(
      source,
      isNot(contains("value.contains('forte rischio') || value.contains('display')")),
    );
  });
}
''')

print("build72 final fixes materialized")
