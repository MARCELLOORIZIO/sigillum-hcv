from pathlib import Path
import re

CAMERA = Path('lib/camera_page.dart')
source = CAMERA.read_text(encoding='utf-8')
original = source


def require_replace(old: str, new: str, label: str) -> None:
    global source
    if old not in source:
        raise SystemExit(f'Missing expected source block: {label}')
    source = source.replace(old, new, 1)


def require_regex(pattern: str, replacement: str, label: str) -> None:
    global source
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'Expected exactly one regex match for {label}, got {count}')
    source = updated


require_replace(
    "import 'hcv_live_screen_probe.dart';\n",
    "import 'hcv_temporal_capture_probe.dart';\n",
    'replace live probe import with temporal capture probe',
)

for line in (
    '  Map<String, dynamic>? _armedPhotoScreenProbe;\n',
    '  HCVCaptureLocation? _armedPhotoLocation;\n',
    '  DateTime? _armedPhotoExpiresAt;\n',
    '  int? _armedPhotoCameraIndex;\n',
    '  double? _armedPhotoZoom;\n',
    '  bool _videoArmed = false;\n',
    '  DateTime? _videoArmExpiresAt;\n',
    '  int? _videoArmCameraIndex;\n',
    '  double? _videoArmZoom;\n',
    '  bool _parallaxRetryRequired = false;\n',
):
    if line not in source:
        raise SystemExit(f'Missing obsolete state field: {line.strip()}')
    source = source.replace(line, '', 1)

require_regex(
    r"  String get _physicalProbeStatus => _c\('physicalProbe'\);\n\n"
    r"  bool _hasRequiredParallax\(Map<String, dynamic> probe\) \{.*?"
    r"\n  Future<void> _toggleCoordinateStamp\(\) async \{",
    "  Future<void> _toggleCoordinateStamp() async {",
    'remove manual parallax/proceed UI helpers',
)

# Remove arming resets from camera switches and PHOTO/VIDEO mode switches. The
# main start()/takePhoto() bodies are replaced below, so any remaining reset is
# an obsolete UI-state reference rather than capture logic.
for assignment in (
    '_videoArmed = false;',
    '_videoArmExpiresAt = null;',
    '_videoArmCameraIndex = null;',
    '_videoArmZoom = null;',
):
    pattern = rf"^\s*{re.escape(assignment)}\n"
    source = re.sub(pattern, '', source, flags=re.M)

require_regex(
    r"  Future<Map<String, dynamic>> _analyzeLiveScreenProbeWithoutFlash\(\{.*?"
    r"\n  Future<void> _settleCameraAfterLiveProbe\(\) async \{",
    "  Future<void> _settleCameraAfterLiveProbe() async {",
    'remove active illumination/parallax camera probe',
)

new_start = r'''  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) return;

    pendingLiveScreenProbe = null;
    pendingVideoLocation = captureLocation;
    lastLiveSignals = null;

    setState(() {
      recording = true;
      status = _c('starting');
      result = null;
      videoPath = null;
      hcvPath = null;
      packagePath = null;
      hcvId = null;
      verificationUrl = null;
      registryStatus = null;
    });

    try {
      // VIDEO starts on the user's first REC tap. There is no disposable
      // pre-capture clip and no parallax/geometry gate; display evidence comes
      // from the actual recorded video during post-capture analysis.
      await _settleCameraAfterLiveProbe();
      await controller!.startVideoRecording();
      pendingVideoCapturedAt = DateTime.now();

      try {
        await liveSignals.start();
      } catch (_) {
        lastLiveSignals = null;
      }

      setState(() => status = _c('recording'));
    } catch (e) {
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;
      pendingLiveScreenProbe = null;
      setState(() {
        recording = false;
        status = '${_c('startError')}: $e';
      });
    }
  }
'''

require_regex(
    r"  Future<void> start\(\) async \{.*?\n  \}\n\n"
    r"  Future<void> _waitForFinalizedVideoContainer",
    new_start + "\n  Future<void> _waitForFinalizedVideoContainer",
    'replace two-step video arming with immediate recording',
)

photo_helpers_and_prefix = r'''  Map<String, dynamic> _photoTemporalV2Unavailable(
    String reason, {
    Object? error,
  }) {
    return {
      'type': 'SIGILLUM_PHOTO_TEMPORAL_VIDEO_PROBE_V2',
      'analysisStatus': 'NOT_ANALYZED',
      'captureDurationMs':
          HCVTemporalCaptureProbe.defaultDuration.inMilliseconds,
      'temporaryVideoDeletedAfterAnalysis': true,
      'reason': reason,
      if (error != null) 'error': error.toString(),
    };
  }

  Map<String, dynamic> _buildPhotoTemporalV2LiveProbe(
    Map<String, dynamic> temporalProbe,
  ) {
    final opticalRaw = temporalProbe['screenReplayAnalysis'];
    final mlRaw = temporalProbe['mlScreenReplayAnalysis'];
    final optical = opticalRaw is Map
        ? Map<String, dynamic>.from(opticalRaw)
        : null;
    final ml = mlRaw is Map ? Map<String, dynamic>.from(mlRaw) : null;
    final analyzed = temporalProbe['analysisStatus'] == 'ANALYZED' &&
        (optical != null || ml != null);

    final temporalRisk = analyzed
        ? combineVideoDisplayRiskFromCaptureEvidence([optical, ml])
        : null;
    final opticalFrames = (optical?['framesAnalyzed'] as num?)?.toInt() ?? 0;
    final mlFrames = (ml?['framesAnalyzed'] as num?)?.toInt() ?? 0;

    return {
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'activeProbeVersion': 6,
      'analysisStatus': analyzed ? 'ANALYZED' : 'NOT_ANALYZED',
      'framesAnalyzed': opticalFrames > mlFrames ? opticalFrames : mlFrames,
      'screenReplayRisk': temporalRisk?.risk ?? 'UNKNOWN',
      'screenReplayRiskScore': temporalRisk?.score,
      'displayRiskDecision': temporalRisk?.decision ?? 'NOT_ANALYZED',
      'sceneClass': 'UNKNOWN',
      'reason': 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_NO_PARALLAX',
      'geometryChallenge': const {
        'sceneClass': 'UNKNOWN',
        'realityEvidence': false,
        'planarEvidence': false,
        'reasons': ['PHOTO_TEMPORAL_V2_NO_PARALLAX'],
      },
      'signals': {
        'photoTemporalVideoAnalyzed': analyzed,
        'photoTemporalVideoDeletedAfterAnalysis':
            temporalProbe['temporaryVideoDeletedAfterAnalysis'] == true,
        'rawActiveDisplayEvidence': false,
        'activeIlluminationDisplayEvidence': false,
        'reflectedRealityEvidence': false,
        'planarSceneEvidence': false,
        'geometryChallengeCompleted': false,
        'activeChallengeIndeterminate': false,
      },
      'photoTemporalVideoProbe': temporalProbe,
      'photoDecisionMethod': 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT',
      'videoEquivalentAvailable': analyzed && temporalRisk != null,
      if (temporalRisk != null)
        'videoEquivalentDisplayRisk': temporalRisk.toJson(),
      'note':
          'Photo Temporal V2 uses a disposable 2.4 s clip immediately before automatic still capture. Manual parallax is not used.',
    };
  }

  Future<void> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) return;

    const temporalProbeEngine = HCVTemporalCaptureProbe();
    HCVTemporalCaptureClip? temporalClip;
    Map<String, dynamic>? temporalProbe;

    try {
      // One user tap starts the technical clip and automatically finishes with
      // the actual still. No PROSEGUI step and no 15-second scene gap remain.
      setState(() {
        status = _c('takingPhoto');
        result = null;
      });

      try {
        temporalClip = await temporalProbeEngine.capture(
          controller!,
          duration: HCVTemporalCaptureProbe.defaultDuration,
        );
      } catch (e) {
        temporalProbe = _photoTemporalV2Unavailable(
          'PHOTO_TEMPORAL_CAPTURE_FAILED',
          error: e,
        );
      }

      await _settleCameraAfterLiveProbe();

      late final XFile file;
      try {
        file = await controller!.takePicture();
      } catch (_) {
        if (temporalClip != null) {
          await temporalProbeEngine.discard(temporalClip.path);
        }
        rethrow;
      }
      final capturedAt = DateTime.now();

      final savedPhotoPath = await savePhotoToDocuments(file.path);

      if (temporalClip != null) {
        setState(() {
          status = _c('analyzingScreen');
        });
        temporalProbe =
            await temporalProbeEngine.analyzeCapturedClip(temporalClip);
        temporalClip = null;
      }
      temporalProbe ??= _photoTemporalV2Unavailable(
        'PHOTO_TEMPORAL_NOT_AVAILABLE',
      );
      final liveScreenProbe = _buildPhotoTemporalV2LiveProbe(temporalProbe);

      final engine = HCVEngine();'''

require_regex(
    r"  Future<void> takePhoto\(\) async \{.*?"
    r"      final engine = HCVEngine\(\);",
    photo_helpers_and_prefix,
    'replace two-step photo arm with pre-shot 2.4s temporal capture',
)

old_photo_combiner = '''  final mlFirst = HCVDisplayRiskFusion.mlFirstPhotoDecision(
    _mlAnalysisFromAnalyses(analyses),
  );
  final legacy = _combinePhotoDisplayRiskLegacy(analyses);
  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
  }
  return legacy;
'''
new_photo_combiner = '''  final mlFirst = HCVDisplayRiskFusion.mlFirstPhotoDecision(
    _mlAnalysisFromAnalyses(analyses),
  );
  final legacy = _combinePhotoDisplayRiskLegacy(analyses);
  final liveProbe = _liveProbeFromAnalyses(analyses);
  final isTemporalV2 =
      liveProbe?['photoDecisionMethod'] == 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT';

  // A strong multi-frame/temporal DISPLAY result from the clip captured
  // immediately before the automatic still must not be erased by one semantic
  // still-image REALITY false negative (the C8FF failure mode).
  if (isTemporalV2 && legacy.decision == 'STRONG_DISPLAY_RISK') {
    return legacy;
  }

  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
  }
  return legacy;
'''
require_replace(
    old_photo_combiner,
    new_photo_combiner,
    'protect strong Temporal V2 evidence from still ML reality override',
)

require_replace(
    '          color: _parallaxRetryRequired ? Colors.redAccent : Colors.white,\n',
    '          color: Colors.white,\n',
    'remove parallax-specific status coloring',
)

# The camera capture path must no longer contain any manual arming/parallax
# state or calls. Legacy classifier files stay in the repository for unit tests
# and historical compatibility, but CameraPage no longer invokes them.
for forbidden in (
    '_armedPhotoScreenProbe',
    '_armedPhotoExpiresAt',
    '_armedPhotoCameraIndex',
    '_armedPhotoZoom',
    '_videoArmed',
    '_videoArmExpiresAt',
    '_videoArmCameraIndex',
    '_videoArmZoom',
    '_parallaxRetryRequired',
    '_analyzeLiveScreenProbeWithoutFlash',
    '_showCaptureReadyMessage',
    "_c('physicalProbe')",
    "_c('parallaxRequired')",
):
    if forbidden in source:
        raise SystemExit(f'Obsolete capture-flow token still present: {forbidden}')

if "HCVTemporalCaptureProbe.defaultDuration" not in source:
    raise SystemExit('Temporal V2 capture duration is not wired into CameraPage')
if "PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT" not in source:
    raise SystemExit('Temporal V2 decision method marker missing')
if "await controller!.startVideoRecording();" not in source:
    raise SystemExit('Immediate native video recording call missing')

if source == original:
    raise SystemExit('No camera changes were produced')

CAMERA.write_text(source, encoding='utf-8')
print('camera_page.dart patched for PHOTO Temporal V2 / VIDEO no-parallax flow')
