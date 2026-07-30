from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


# Expose one canonical definition of sufficient camera movement.
classifier_path = Path('lib/hcv_scene_geometry_classifier.dart')
classifier = classifier_path.read_text()
classifier = replace_once(
    classifier,
    '''  final int matchedRegions;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {''',
    '''  final int matchedRegions;
  final List<String> reasons;

  bool get movementSufficient =>
      matchedRegions >= 5 && motionMagnitude >= 0.16 && flowReliability >= 0.46;

  Map<String, dynamic> toJson() => {''',
    'geometry movement getter',
)
classifier = replace_once(
    classifier,
    '''        'matchedRegions': matchedRegions,
        'reasons': reasons,''',
    '''        'matchedRegions': matchedRegions,
        'movementSufficient': movementSufficient,
        'reasons': reasons,''',
    'geometry movement serialization',
)
classifier_path.write_text(classifier)


# Add a lightweight, blocking motion gate and allow the full optical probe to
# reuse the geometry already collected while the user moved the phone.
core_path = Path('lib/hcv_live_screen_probe_core.dart')
core = core_path.read_text()
core = replace_once(
    core,
    '''class HCVLiveScreenProbe {
  Future<Map<String, dynamic>> analyzePreview(
    CameraController controller, {
    Duration duration = const Duration(milliseconds: 3000),
    int maxFrames = 45,
    double? restoreZoomLevel,
    bool useOpticalProbeZoom = true,
  }) async {''',
    '''class HCVLiveScreenProbe {
  Future<HCVSceneGeometryClassification> waitForSufficientMovement(
    CameraController controller, {
    Duration timeout = const Duration(seconds: 12),
    double? restoreZoomLevel,
    FlashMode restoreFlashMode = FlashMode.off,
  }) async {
    HCVSceneGeometryClassification emptyGeometry() =>
        HCVSceneGeometryClassifier.classify(
          motionMagnitude: 0,
          flowReliability: 0,
          directionCoherence: 0,
          depthDispersion: 0,
          planarCoherence: 0,
          matchedRegions: 0,
        );

    if (!controller.value.isInitialized ||
        controller.value.isRecordingVideo ||
        controller.value.isStreamingImages) {
      return emptyGeometry();
    }

    final frames = <_FrameStats>[];
    var processing = false;
    var geometry = emptyGeometry();

    try {
      await controller.setFlashMode(FlashMode.off);
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));

      await controller.startImageStream((image) {
        if (processing) return;
        processing = true;
        try {
          final stats = _readFrameStats(image, 0);
          if (stats != null) {
            frames.add(stats);
            if (frames.length > 36) frames.removeAt(0);
          }
        } finally {
          processing = false;
        }
      });

      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (frames.length >= 4) {
          geometry = _analyzeGeometry(frames);
          if (geometry.movementSufficient) break;
        }
        await Future.delayed(const Duration(milliseconds: 80));
      }
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        if (restoreZoomLevel != null && controller.value.isInitialized) {
          await controller.setZoomLevel(restoreZoomLevel);
        }
      } catch (_) {}
      try {
        if (controller.value.isInitialized) {
          await controller.setFlashMode(restoreFlashMode);
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
    }

    return geometry;
  }

  Future<Map<String, dynamic>> analyzePreview(
    CameraController controller, {
    Duration duration = const Duration(milliseconds: 3000),
    int maxFrames = 45,
    double? restoreZoomLevel,
    bool useOpticalProbeZoom = true,
    HCVSceneGeometryClassification? geometryOverride,
  }) async {''',
    'live probe movement gate',
)
core = replace_once(
    core,
    '''    final geometry = _analyzeGeometry(<_FrameStats>[
      ...baselineFrames,
      ...recoveryFrames,
    ]);''',
    '''    final geometry = geometryOverride ??
        _analyzeGeometry(<_FrameStats>[
          ...baselineFrames,
          ...recoveryFrames,
        ]);''',
    'geometry override',
)
core = replace_once(
    core,
    '''        'geometryChallengeCompleted': geometry.sceneClass != 'UNKNOWN',
        'activeChallengeIndeterminate': indeterminate,''',
    '''        'geometryChallengeCompleted': geometry.sceneClass != 'UNKNOWN',
        'geometryMovementSufficient': geometry.movementSufficient,
        'activeChallengeIndeterminate': indeterminate,''',
    'movement signal',
)
core_path.write_text(core)


camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()
camera = replace_once(
    camera,
    "import 'hcv_live_screen_probe.dart';\n",
    "import 'hcv_live_screen_probe.dart';\nimport 'hcv_scene_geometry_classifier.dart';\n",
    'camera geometry import',
)
camera = replace_once(
    camera,
    '''  Map<String, dynamic>? pendingLiveScreenProbe;
  DateTime? pendingVideoCapturedAt;''',
    '''  Map<String, dynamic>? pendingLiveScreenProbe;
  DateTime? pendingVideoCapturedAt;
  bool _captureProbeRunning = false;
  bool _captureProbeReady = false;
  String? _captureProbeMode;''',
    'camera probe state',
)
camera = replace_once(
    camera,
    '''  String get _physicalProbeStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'
          : 'MOVE THE PHONE SLIGHTLY SIDEWAYS...';''',
    '''  String get _physicalProbeStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'
          : 'MOVE THE PHONE SLIGHTLY SIDEWAYS...';

  String get _physicalProbeCompletingStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MOVIMENTO SUFFICIENTE. COMPLETAMENTO VERIFICA...'
          : 'MOVEMENT SUFFICIENT. COMPLETING VERIFICATION...';

  String get _physicalProbeReadyStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MOVIMENTO SUFFICIENTE. RIPORTA IL TELEFONO SULL’INQUADRATURA: ORA PUOI PROCEDERE. TOCCA DI NUOVO.'
          : 'MOVEMENT SUFFICIENT. RETURN TO YOUR COMPOSITION: YOU CAN NOW PROCEED. TAP AGAIN.';

  String get _physicalProbeInsufficientStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MOVIMENTO NON SUFFICIENTE. NESSUNO SCATTO ESEGUITO. MUOVI IL TELEFONO LATERALMENTE E TOCCA PER RIPROVARE.'
          : 'MOVEMENT NOT SUFFICIENT. NOTHING WAS CAPTURED. MOVE SIDEWAYS AND TAP TO TRY AGAIN.';

  String get _preparedCaptureActionLabel =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'RIPOSIZIONA E TOCCA PER PROCEDERE'
          : 'RECOMPOSE AND TAP TO PROCEED';''',
    'camera probe messages',
)
camera = replace_once(
    camera,
    '''  Future<Map<String, dynamic>> _analyzeLiveScreenProbeWithoutFlash() async {''',
    '''  Future<Map<String, dynamic>> _analyzeLiveScreenProbeWithoutFlash({
    HCVSceneGeometryClassification? geometryOverride,
  }) async {''',
    'camera probe signature',
)
camera = replace_once(
    camera,
    '''      final analysis = await HCVLiveScreenProbe().analyzePreview(
        camera,
        restoreZoomLevel: currentZoom,
      );''',
    '''      final analysis = await HCVLiveScreenProbe().analyzePreview(
        camera,
        restoreZoomLevel: currentZoom,
        geometryOverride: geometryOverride,
      );''',
    'camera geometry override pass-through',
)
camera = replace_once(
    camera,
    '''  Future<void> _settleCameraAfterLiveProbe() async {''',
    '''  void _clearPreparedCaptureProbe() {
    pendingLiveScreenProbe = null;
    _captureProbeReady = false;
    _captureProbeMode = null;
  }

  Future<bool> _prepareCaptureProbe({required bool photo}) async {
    final camera = controller;
    if (camera == null || !camera.value.isInitialized || _captureProbeRunning) {
      return false;
    }

    final mode = photo ? 'photo' : 'video';
    setState(() {
      _captureProbeRunning = true;
      _clearPreparedCaptureProbe();
      status = _physicalProbeStatus;
      result = null;
      videoPath = null;
      hcvPath = null;
      packagePath = null;
      hcvId = null;
      verificationUrl = null;
      registryStatus = null;
    });

    try {
      final movement = await HCVLiveScreenProbe().waitForSufficientMovement(
        camera,
        restoreZoomLevel: currentZoom,
        restoreFlashMode: currentFlashMode,
      );

      if (!movement.movementSufficient) {
        if (mounted) {
          setState(() {
            status = _physicalProbeInsufficientStatus;
          });
        }
        return false;
      }

      if (mounted) {
        setState(() {
          status = _physicalProbeCompletingStatus;
        });
      }

      final analysis = await _analyzeLiveScreenProbeWithoutFlash(
        geometryOverride: movement,
      );
      await _settleCameraAfterLiveProbe();

      if (!mounted) return false;
      setState(() {
        pendingLiveScreenProbe = analysis;
        _captureProbeReady = true;
        _captureProbeMode = mode;
        status = _physicalProbeReadyStatus;
      });
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _clearPreparedCaptureProbe();
          status = 'PROBE ERROR: $error';
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _captureProbeRunning = false;
        });
      }
    }
  }

  Future<void> _settleCameraAfterLiveProbe() async {''',
    'camera capture preparation',
)

old_start = '''  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    setState(() {
      status = _physicalProbeStatus;
      result = null;
      videoPath = null;
      hcvPath = null;
      packagePath = null;
      hcvId = null;
      verificationUrl = null;
      registryStatus = null;
    });

    try {
      pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();

      setState(() {
        recording = true;
        status = 'STARTING...';
      });

      await controller!.startVideoRecording();'''
new_start = '''  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    if (!_captureProbeReady || _captureProbeMode != 'video') {
      await _prepareCaptureProbe(photo: false);
      return;
    }

    final preparedProbe = pendingLiveScreenProbe;
    if (preparedProbe == null) {
      setState(() {
        _clearPreparedCaptureProbe();
        status = _physicalProbeInsufficientStatus;
      });
      return;
    }

    setState(() {
      _captureProbeReady = false;
      _captureProbeMode = null;
      recording = true;
      status = 'STARTING...';
    });

    try {
      pendingLiveScreenProbe = preparedProbe;
      await controller!.startVideoRecording();'''
camera = replace_once(camera, old_start, new_start, 'video two-step gate')

old_photo = '''  Future<void> takePhoto() async {
    if (controller == null) return;

    try {
      setState(() {
        status = _physicalProbeStatus;
      });

      final liveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
      await _settleCameraAfterLiveProbe();

      setState(() {
        status = 'SCATTO FOTO...';
      });

      final file = await controller!.takePicture();'''
new_photo = '''  Future<void> takePhoto() async {
    if (controller == null) return;

    if (!_captureProbeReady || _captureProbeMode != 'photo') {
      await _prepareCaptureProbe(photo: true);
      return;
    }

    final liveScreenProbe = pendingLiveScreenProbe;
    if (liveScreenProbe == null) {
      setState(() {
        _clearPreparedCaptureProbe();
        status = _physicalProbeInsufficientStatus;
      });
      return;
    }

    setState(() {
      pendingLiveScreenProbe = null;
      _captureProbeReady = false;
      _captureProbeMode = null;
      status = 'SCATTO FOTO...';
    });

    try {
      await _settleCameraAfterLiveProbe();
      final file = await controller!.takePicture();'''
camera = replace_once(camera, old_photo, new_photo, 'photo two-step gate')

camera = replace_once(
    camera,
    '''    setState(() {
      selectedCameraIndex = selectedCameraIndex;
    });''',
    '''    setState(() {
      _clearPreparedCaptureProbe();
      status = 'READY';
    });''',
    'switch camera invalidates probe',
) if '''    setState(() {
      selectedCameraIndex = selectedCameraIndex;
    });''' in camera else camera

# The actual switch-camera source ends with an empty setState.
camera = replace_once(
    camera,
    '''    setState(() {});
  }

  Future<void> toggleFlash() async {''',
    '''    setState(() {
      _clearPreparedCaptureProbe();
      status = 'READY';
    });
  }

  Future<void> toggleFlash() async {''',
    'switch camera ready reset',
)
camera = replace_once(
    camera,
    '''      setState(() {
        currentZoom = safeZoom;
      });''',
    '''      setState(() {
        currentZoom = safeZoom;
        _clearPreparedCaptureProbe();
        status = 'READY';
      });''',
    'zoom invalidates probe',
)
camera = camera.replace(
    '''                              setState(() {
                                photoMode = false;
                              });''',
    '''                              if (_captureProbeRunning || recording) return;
                              setState(() {
                                photoMode = false;
                                _clearPreparedCaptureProbe();
                                status = 'READY';
                              });''',
    1,
)
camera = camera.replace(
    '''                              setState(() {
                                photoMode = true;
                              });''',
    '''                              if (_captureProbeRunning || recording) return;
                              setState(() {
                                photoMode = true;
                                _clearPreparedCaptureProbe();
                                status = 'READY';
                              });''',
    1,
)
camera = replace_once(
    camera,
    '''                          onChanged: (value) async {
                            await setZoom(value);
                          },''',
    '''                          onChanged: _captureProbeRunning
                              ? null
                              : (value) async {
                                  await setZoom(value);
                                },''',
    'disable zoom while probing',
)
camera = replace_once(
    camera,
    '''                        onTap: !ready
                            ? null
                            : () async {''',
    '''                        onTap: !ready || _captureProbeRunning
                            ? null
                            : () async {''',
    'disable capture while probing',
)
camera = replace_once(
    camera,
    '''                            color: recording ? Colors.red : Colors.white,''',
    '''                            color: recording
                                ? Colors.red
                                : _captureProbeReady
                                    ? Colors.green
                                    : Colors.white,''',
    'prepared shutter color',
)
camera = replace_once(
    camera,
    '''                                : Icon(
                                    photoMode
                                        ? Icons.camera_alt
                                        : Icons.videocam,
                                    color: Colors.black,
                                    size: 34,
                                  ),''',
    '''                                : Icon(
                                    _captureProbeReady
                                        ? Icons.check_rounded
                                        : photoMode
                                            ? Icons.camera_alt
                                            : Icons.videocam,
                                    color: _captureProbeReady
                                        ? Colors.white
                                        : Colors.black,
                                    size: 34,
                                  ),''',
    'prepared shutter icon',
)
camera = replace_once(
    camera,
    '''                        recording
                            ? _t('recording')
                            : photoMode
                                ? _t('photoMode')
                                : _t('videoMode'),''',
    '''                        _captureProbeRunning
                            ? _physicalProbeStatus
                            : recording
                                ? _t('recording')
                                : _captureProbeReady
                                    ? _preparedCaptureActionLabel
                                    : photoMode
                                        ? _t('photoMode')
                                        : _t('videoMode'),''',
    'prepared action label',
)
camera_path.write_text(camera)


test_path = Path('test/capture_motion_gate_contract_test.dart')
test_path.write_text('''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capture movement gate', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final probe = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    final geometry =
        File('lib/hcv_scene_geometry_classifier.dart').readAsStringSync();

    test('uses the same movement thresholds as geometry classification', () {
      expect(geometry, contains('bool get movementSufficient'));
      expect(geometry, contains('matchedRegions >= 5'));
      expect(geometry, contains('motionMagnitude >= 0.16'));
      expect(geometry, contains('flowReliability >= 0.46'));
    });

    test('waits for sufficient movement before completing the optical probe', () {
      expect(probe, contains('waitForSufficientMovement'));
      expect(probe, contains('if (geometry.movementSufficient) break'));
      expect(probe, contains('HCVSceneGeometryClassification? geometryOverride'));
      expect(probe, contains('geometryOverride ??'));
    });

    test('photo and video require a second user gesture after probe readiness', () {
      expect(camera, contains("_captureProbeMode != 'photo'"));
      expect(camera, contains("_captureProbeMode != 'video'"));
      expect(camera, contains('await _prepareCaptureProbe(photo: true)'));
      expect(camera, contains('await _prepareCaptureProbe(photo: false)'));
      expect(camera, contains('MOVIMENTO SUFFICIENTE. RIPORTA IL TELEFONO'));
      expect(camera, contains('MOVIMENTO NON SUFFICIENTE. NESSUNO SCATTO ESEGUITO'));
    });

    test('prepared state is visible and capture is disabled during sampling', () {
      expect(camera, contains('!ready || _captureProbeRunning'));
      expect(camera, contains('Icons.check_rounded'));
      expect(camera, contains('_preparedCaptureActionLabel'));
    });
  });
}
''')

instruction_test = Path('test/physical_probe_user_instruction_test.dart')
instruction = instruction_test.read_text()
instruction = replace_once(
    instruction,
    '''    expect(source, contains('MOVE THE PHONE SLIGHTLY SIDEWAYS'));
''',
    '''    expect(source, contains('MOVE THE PHONE SLIGHTLY SIDEWAYS'));
    expect(source, contains('MOVIMENTO SUFFICIENTE. RIPORTA IL TELEFONO'));
    expect(source, contains('MOVIMENTO NON SUFFICIENTE. NESSUNO SCATTO ESEGUITO'));
''',
    'physical probe UX test',
)
instruction_test.write_text(instruction)

print('Strict capture movement gate and re-composition confirmation installed')
