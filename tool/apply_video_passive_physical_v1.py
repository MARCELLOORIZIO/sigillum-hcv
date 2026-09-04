from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:140]!r}')
    if text.count(old) != 1:
        raise SystemExit(f'pattern not unique in {path}: {text.count(old)}')
    p.write_text(text.replace(old, new, 1))


# 1) Add FFprobe duration discovery so passive physical windows can be
# distributed from the beginning to the end of the actual recorded video.
replace_once(
    'lib/hcv_display_microtexture_probe.dart',
    "import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';\n",
    "import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';\n"
    "import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';\n",
)

passive_method = r'''  /// Passive physical verification of the actual user video.
  ///
  /// This never changes camera zoom, exposure, shutter or the recorded file.
  /// Native-resolution 3x3 temporal windows are sampled across the whole
  /// recording after REC stops, so the pre-REC active probe is complemented
  /// by evidence from the content that was actually certified.
  Future<Map<String, dynamic>> analyzeRecordedVideoPassive(
    String videoPath, {
    int maxWindows = 8,
  }) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      return {
        'type': 'SIGILLUM_VIDEO_PASSIVE_PHYSICAL_VERIFICATION_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'VIDEO_NOT_FOUND',
      };
    }

    double? durationSeconds;
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final information = await session.getMediaInformation();
      durationSeconds = double.tryParse(information?.getDuration() ?? '');
    } catch (_) {
      durationSeconds = null;
    }

    if (durationSeconds == null || durationSeconds <= 0) {
      return {
        'type': 'SIGILLUM_VIDEO_PASSIVE_PHYSICAL_VERIFICATION_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'VIDEO_DURATION_UNAVAILABLE',
        'recordedVideoAltered': false,
        'shutterChangedDuringRecordedVideo': false,
        'zoomChangedDuringRecordedVideo': false,
      };
    }

    final safeMaxWindows = max(1, maxWindows);
    final windowMs = _phaseDuration.inMilliseconds;
    final durationMs = max(1, (durationSeconds * 1000.0).round());
    final maxStartMs = max(0, durationMs - windowMs);
    final desiredWindows = durationSeconds <= 1.0
        ? 1
        : min(
            safeMaxWindows,
            max(2, (durationSeconds / 5.0).ceil() + 1),
          );
    final starts = <int>[];
    for (var i = 0; i < desiredWindows; i++) {
      final startMs = desiredWindows == 1
          ? 0
          : ((maxStartMs * i) / (desiredWindows - 1)).round();
      if (starts.isEmpty || starts.last != startMs) starts.add(startMs);
    }

    final root = Directory(
      p.join(
        (await getTemporaryDirectory()).path,
        'hcv_video_passive_physical_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    try {
      await root.create(recursive: true);
      final windows = <Map<String, dynamic>>[];
      for (var i = 0; i < starts.length; i++) {
        final startMs = starts[i];
        final endMs = min(durationMs, startMs + windowMs);
        if (endMs <= startMs) continue;
        final dir = Directory(p.join(root.path, 'window_$i'));
        await dir.create(recursive: true);
        final frames = await _extractFrames(
          videoPath,
          dir,
          startMs: startMs,
          endMs: endMs,
        );
        final metrics = _phaseMetrics(frames);
        if (metrics['analysisStatus'] == 'NOT_ANALYZED') continue;
        windows.add({
          'windowIndex': i,
          'startMs': startMs,
          'endMs': endMs,
          ...metrics,
        });
      }

      final meanAxis = windows
          .map(
            (window) =>
                (window['structuredTemporalAxisRatio'] as num?)?.toDouble(),
          )
          .whereType<double>()
          .toList();
      final minimumCells = windows
          .map(
            (window) =>
                (window['minimumCellStructuredTemporalAxisRatio'] as num?)
                    ?.toDouble(),
          )
          .whereType<double>()
          .toList();

      return {
        'type': 'SIGILLUM_VIDEO_PASSIVE_PHYSICAL_VERIFICATION_V1',
        'analysisStatus': windows.isEmpty ? 'NOT_ANALYZED' : 'ANALYZED',
        'decisionRole': 'PASSIVE_WHOLE_RECORDING_PHYSICAL_CORROBORATION',
        'scanMode': 'WHOLE_RECORDING_DISTRIBUTED_NATIVE_3X3',
        'durationSeconds': durationSeconds,
        'windowsRequested': starts.length,
        'windowsAnalyzed': windows.length,
        'firstWindowStartMs': starts.isEmpty ? null : starts.first,
        'lastWindowStartMs': starts.isEmpty ? null : starts.last,
        'timelineCoverageSpansRecording':
            starts.isNotEmpty && starts.first == 0 && starts.last == maxStartMs,
        'meanWindowStructuredTemporalAxisRatio': _mean(meanAxis),
        'minimumObservedCellStructuredTemporalAxisRatio': minimumCells.isEmpty
            ? null
            : minimumCells.reduce(min),
        'maximumObservedMinimumCellStructuredTemporalAxisRatio':
            minimumCells.isEmpty ? null : minimumCells.reduce(max),
        'windowResults': windows,
        'recordedVideoAltered': false,
        'shutterChangedDuringRecordedVideo': false,
        'zoomChangedDuringRecordedVideo': false,
        'spatialPolicy': const {
          'gridRows': 3,
          'gridColumns': 3,
          'requiredDisplayCoverageCells': 9,
          'allowedRealityEscapeCells': 0,
          'standaloneDecisionEnabled': false,
          'reason':
              'NORMAL_EXPOSURE_PASSIVE_METRICS_ARE_CORROBORATIVE_UNTIL_CALIBRATED',
        },
        'note':
            'Passive native-resolution 3x3 windows are distributed over the complete recorded timeline. No camera state is changed during REC.',
      };
    } catch (error) {
      return {
        'type': 'SIGILLUM_VIDEO_PASSIVE_PHYSICAL_VERIFICATION_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'PASSIVE_PHYSICAL_ANALYSIS_FAILED',
        'error': error.toString(),
        'recordedVideoAltered': false,
        'shutterChangedDuringRecordedVideo': false,
        'zoomChangedDuringRecordedVideo': false,
      };
    } finally {
      try {
        if (await root.exists()) await root.delete(recursive: true);
      } catch (_) {}
    }
  }

'''
replace_once(
    'lib/hcv_display_microtexture_probe.dart',
    '  Future<bool> discardCapture(Map<String, dynamic>? capture) async {',
    passive_method + '  Future<bool> discardCapture(Map<String, dynamic>? capture) async {',
)

# 2) Expose the passive whole-recording verifier through the temporal probe
# already used by camera_page. This analysis runs only after stopVideoRecording.
marker = '  /// Analyzes the unchanged BUILD 80 clip and, independently, the new shadow\n'
wrapper = r'''  Future<Map<String, dynamic>> analyzePassiveRecordedVideoPhysical(
    String videoPath,
  ) async {
    return const HCVDisplayMicrotextureShadowProbe()
        .analyzeRecordedVideoPassive(videoPath);
  }

'''
replace_once('lib/hcv_temporal_capture_probe.dart', marker, wrapper + marker)

# 3) Run passive physical verification on the exact saved user video and sign
# it into the HCV. It is corroborative only; active SHORT_1X remains the V1
# decision gate because normal-exposure passive thresholds are not calibrated.
replace_once(
    'lib/camera_page.dart',
    "    Map<String, dynamic>? mlScreenReplayAnalysis;\n\n    setState(() {\n",
    "    Map<String, dynamic>? mlScreenReplayAnalysis;\n"
    "    Map<String, dynamic>? passivePhysicalVideoVerification;\n\n"
    "    setState(() {\n",
)
replace_once(
    'lib/camera_page.dart',
    """    final trustAnalysis = HCVTrustAnalyzer.analyze(
      liveSignals: lastLiveSignals,
      audioCaptured: true,
    );
""",
    """    try {
      passivePhysicalVideoVerification =
          await const HCVTemporalCaptureProbe()
              .analyzePassiveRecordedVideoPhysical(savedVideoPath);
    } catch (e) {
      passivePhysicalVideoVerification = {
        'type': 'SIGILLUM_VIDEO_PASSIVE_PHYSICAL_VERIFICATION_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'VIDEO_PASSIVE_PHYSICAL_EXCEPTION',
        'error': e.toString(),
        'recordedVideoAltered': false,
        'shutterChangedDuringRecordedVideo': false,
        'zoomChangedDuringRecordedVideo': false,
      };
    }

    final trustAnalysis = HCVTrustAnalyzer.analyze(
      liveSignals: lastLiveSignals,
      audioCaptured: true,
    );
""",
)
replace_once(
    'lib/camera_page.dart',
    '      "physicalDisplayProbe": videoPhysicalDisplayProbe,\n'
    '      "aiProofLevel": "ACTIVE_PHYSICAL_PLUS_PASSIVE_LIVE_CAPTURE_V1",\n',
    '      "physicalDisplayProbe": videoPhysicalDisplayProbe,\n'
    '      "passivePhysicalVideoVerification": passivePhysicalVideoVerification,\n'
    '      "aiProofLevel": "ACTIVE_PHYSICAL_PLUS_PASSIVE_LIVE_CAPTURE_V1",\n',
)

print('VIDEO_PASSIVE_PHYSICAL_V1_PATCH_APPLIED')
