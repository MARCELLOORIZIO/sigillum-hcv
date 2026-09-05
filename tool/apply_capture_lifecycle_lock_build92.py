from pathlib import Path
import re
import textwrap

CAMERA = Path('lib/camera_page.dart')
LIFECYCLE = Path('lib/hcv_capture_lifecycle.dart')
TEST = Path('test/camera_capture_lifecycle_contract_test.dart')

text = CAMERA.read_text(encoding='utf-8')
original = text


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text = text.replace(old, new, 1)


def replace_between(start: str, end: str, replacement: str, label: str) -> None:
    global text
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f'{label}: start marker not found')
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f'{label}: end marker not found')
    text = text[:start_index] + replacement + text[end_index:]


replace_once(
    "import 'camera_ui_extended_copy.dart';\n",
    "import 'camera_ui_extended_copy.dart';\nimport 'hcv_capture_lifecycle.dart';\n",
    'lifecycle import',
)

replace_once(
    """  bool ready = false;
  bool recording = false;
  bool _videoFinalizeInProgress = false;

  bool photoMode = false;
""",
    """  bool ready = false;
  HCVCaptureLifecycle _captureLifecycle = HCVCaptureLifecycle.idle;

  bool get recording =>
      _captureLifecycle == HCVCaptureLifecycle.recording;
  bool get _captureInteractionLocked =>
      _captureLifecycle.interactionLocked;
  bool get _captureButtonEnabled =>
      ready && _captureLifecycle.captureButtonEnabled;

  bool photoMode = false;
""",
    'capture state',
)

replace_once(
    """  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  String _c(String key) => CameraUiExtendedCopy.t(widget.languageCode, key);

""",
    """  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  String _c(String key) => CameraUiExtendedCopy.t(widget.languageCode, key);

  void _setCaptureLifecycle(HCVCaptureLifecycle next) {
    if (_captureLifecycle == next) return;
    if (!mounted) {
      _captureLifecycle = next;
      return;
    }
    setState(() => _captureLifecycle = next);
  }

  void _setPhotoMode(bool value) {
    if (_captureInteractionLocked || photoMode == value) return;
    pendingLiveScreenProbe = null;
    pendingTemporalFrequencyProbe = null;
    pendingVideoLocation = null;
    setState(() => photoMode = value);
  }

""",
    'lifecycle helpers',
)

replace_once(
    """  Future<void> _toggleCoordinateStamp() async {
    if (_locationBusy) return;
""",
    """  Future<void> _toggleCoordinateStamp() async {
    if (_captureInteractionLocked || _locationBusy) return;
""",
    'GPS logic guard',
)

replace_once(
    """  Future<void> switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;
""",
    """  Future<void> switchCamera() async {
    if (_captureInteractionLocked) return;
    if (cameras == null || cameras!.length < 2) return;
""",
    'camera switch logic guard',
)

replace_once(
    """  Future<void> toggleFlash() async {
    if (controller == null) return;
""",
    """  Future<void> toggleFlash() async {
    if (_captureInteractionLocked) return;
    if (controller == null) return;
""",
    'flash logic guard',
)

replace_once(
    """    final description = available[selectedCameraIndex];
    final savedZoom = currentZoom;
    final savedFlash = currentFlashMode;
    Map<String, dynamic> probe;
""",
    """    final description = available[selectedCameraIndex];
    final savedZoom = currentZoom;
    final savedFlash = currentFlashMode;
    var restoredFlashStateBeforeCapture = 'NOT_ATTEMPTED';
    Map<String, dynamic> probe;
""",
    'HFR flash metadata state',
)

replace_once(
    """      try {
        await replacement.setFlashMode(savedFlash);
      } catch (_) {}

      // The native HFR probe locks the physical lens for temporal stability.
""",
    """      try {
        await replacement.setFlashMode(savedFlash);
        restoredFlashStateBeforeCapture =
            savedFlash == FlashMode.torch ? 'torch' : 'off';
      } catch (error) {
        restoredFlashStateBeforeCapture = 'RESTORE_FAILED';
        throw StateError('USER_FLASH_RESTORE_AFTER_NATIVE_PROBE_FAILED: $error');
      }

      // The native HFR probe locks the physical lens for temporal stability.
""",
    'HFR flash restore enforcement',
)

replace_once(
    """    return probe;
  }

  Future<void> _settleCameraAfterLiveProbe() async {
""",
    """    probe = <String, dynamic>{
      ...probe,
      'requestedFlashStateBeforeProbe':
          savedFlash == FlashMode.torch ? 'torch' : 'off',
      'actualTorchStateDuringProbe': 'NOT_VERIFIED_NATIVE_SESSION',
      'restoredFlashStateBeforeCapture': restoredFlashStateBeforeCapture,
      if (savedFlash == FlashMode.torch) ...{
        'captureLightingComparable': false,
        'nonComparableReason':
            'USER_TORCH_ACTIVE_NATIVE_HFR_LIGHTING_NOT_VERIFIED',
        'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
      },
    };
    return probe;
  }

  Future<void> _settleCameraAfterLiveProbe() async {
""",
    'HFR torch non-comparability metadata',
)

replace_once(
    """  Future<void> setZoom(double zoom) async {
    if (controller == null || !controller!.value.isInitialized) return;
""",
    """  Future<void> setZoom(double zoom) async {
    if (_captureInteractionLocked) return;
    if (controller == null || !controller!.value.isInitialized) return;
""",
    'zoom logic guard',
)

new_start = """  Future<void> start() async {
    if (_captureLifecycle != HCVCaptureLifecycle.idle) return;
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    // The first tap owns the capture synchronously, before location/HFR awaits.
    _setCaptureLifecycle(HCVCaptureLifecycle.preparingVideo);

    try {
      final captureLocation = await _locationForCapture();
      if (_printCoordinates && captureLocation == null) {
        _setCaptureLifecycle(HCVCaptureLifecycle.idle);
        return;
      }

      pendingLiveScreenProbe = null;
      pendingTemporalFrequencyProbe = null;
      pendingVideoLocation = captureLocation;
      lastLiveSignals = null;

      if (mounted) {
        setState(() {
          status = _c('starting');
          result = null;
          videoPath = null;
          hcvPath = null;
          packagePath = null;
          hcvId = null;
          verificationUrl = null;
          registryStatus = null;
        });
      }

      // BUILD 80 remains the decision baseline. The V2 physical probe runs in
      // its own native AVCaptureSession while Flutter camera is released.
      pendingTemporalFrequencyProbe =
          await _captureTemporalFrequencyNativeIsolated();

      await _settleCameraAfterLiveProbe();
      final activeController = controller;
      if (activeController == null || !activeController.value.isInitialized) {
        throw StateError('CAMERA_NOT_READY_AFTER_NATIVE_PROBE');
      }
      await activeController.startVideoRecording();
      pendingVideoCapturedAt = DateTime.now();

      // Recording has physically started: only STOP may remain interactive.
      _setCaptureLifecycle(HCVCaptureLifecycle.recording);
      if (mounted) setState(() => status = _c('recording'));

      try {
        await liveSignals.start();
      } catch (_) {
        lastLiveSignals = null;
      }
    } catch (e) {
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;
      pendingLiveScreenProbe = null;
      pendingTemporalFrequencyProbe = null;
      _setCaptureLifecycle(HCVCaptureLifecycle.idle);
      if (mounted) {
        setState(() {
          status = '${_c('startError')}: $e';
        });
      }
    }
  }

"""
replace_between(
    '  Future<void> start() async {\n',
    '  Future<void> _waitForFinalizedVideoContainer(String path) async {\n',
    new_start,
    'start lifecycle',
)

new_stop = """  Future<void> stop() async {
    if (_captureLifecycle != HCVCaptureLifecycle.recording) return;
    if (controller == null) return;

    // First STOP tap wins synchronously; every other action is locked now.
    _setCaptureLifecycle(HCVCaptureLifecycle.finalizingVideo);

    try {
      final file = await controller!.stopVideoRecording();

      try {
        lastLiveSignals = await liveSignals.stopAndBuildSummary();
      } catch (_) {
        lastLiveSignals = null;
      }

      await _waitForFinalizedVideoContainer(file.path);

      pendingTemporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(
        'VIDEO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',
      );

      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();
      final captureLocation = pendingVideoLocation;
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;

      _setCaptureLifecycle(HCVCaptureLifecycle.processingVideo);
      if (mounted) setState(() => status = _c('processingVideo'));

      await processVideo(
        file.path,
        capturedAt: capturedAt,
        captureLocation: captureLocation,
      );
    } catch (e) {
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;
      pendingLiveScreenProbe = null;
      pendingTemporalFrequencyProbe = null;
      try {
        lastLiveSignals = await liveSignals.stopAndBuildSummary();
      } catch (_) {
        lastLiveSignals = null;
      }
      _setCaptureLifecycle(HCVCaptureLifecycle.idle);
      if (mounted) {
        setState(() {
          status = '${_c('stopError')}: $e';
        });
      }
    }
  }

"""
replace_between(
    '  Future<void> stop() async {\n',
    '  Map<String, dynamic> _photoTemporalV2Unavailable(\n',
    new_stop,
    'stop lifecycle',
)

replace_once(
    """  Future<void> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) return;

    const temporalProbeEngine = HCVTemporalCaptureProbe();
""",
    """  Future<void> takePhoto() async {
    if (_captureLifecycle != HCVCaptureLifecycle.idle) return;
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    // Lock before coordinates, HFR handoff, temporal clip or still capture.
    _setCaptureLifecycle(HCVCaptureLifecycle.capturingPhoto);

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) {
      _setCaptureLifecycle(HCVCaptureLifecycle.idle);
      return;
    }

    const temporalProbeEngine = HCVTemporalCaptureProbe();
""",
    'photo lifecycle prologue',
)

replace_once(
    """      if (currentFlashMode != FlashMode.off &&
          controller!.value.isInitialized) {
        try {
          await controller!.setFlashMode(currentFlashMode);
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (_) {}
      }
""",
    """      if (currentFlashMode != FlashMode.off &&
          controller!.value.isInitialized) {
        try {
          await controller!.setFlashMode(currentFlashMode);
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (error) {
          throw StateError('USER_FLASH_RESTORE_BEFORE_PHOTO_FAILED: $error');
        }
      }
""",
    'photo user torch restore enforcement',
)

replace_once(
    """      final capturedAt = DateTime.now();

      final savedPhotoPath = await savePhotoToDocuments(file.path);
""",
    """      final capturedAt = DateTime.now();
      _setCaptureLifecycle(HCVCaptureLifecycle.processingPhoto);

      final savedPhotoPath = await savePhotoToDocuments(file.path);
""",
    'photo processing transition',
)

replace_once(
    """        createdContentKind = 'photo';

        recording = false;
      });
      if (ok) {
""",
    """        createdContentKind = 'photo';
      });
      // Local media/HCV/HCVPACK are complete. Network publication is separate.
      _setCaptureLifecycle(HCVCaptureLifecycle.idle);
      if (ok) {
""",
    'photo unlock after local artifacts',
)

replace_once(
    """    } catch (e) {
      if (temporalClip != null) {
        await temporalProbeEngine.discard(temporalClip.path);
      }
      setState(() {
        status = '${_c('photoError')}: $e';
      });
    }
  }

  Future<Directory> _downloadsDirectory() async {
""",
    """    } catch (e) {
      if (temporalClip != null) {
        await temporalProbeEngine.discard(temporalClip.path);
      }
      _setCaptureLifecycle(HCVCaptureLifecycle.idle);
      if (mounted) {
        setState(() {
          status = '${_c('photoError')}: $e';
        });
      }
    }
  }

  Future<Directory> _downloadsDirectory() async {
""",
    'photo error unlock',
)

replace_once(
    """    setState(() {
      recording = false;
      videoPath = savedVideoPath;
      hcvPath = hcv;
      packagePath = pack;
      hcvId = detectedId;
      verificationUrl = detectedUrl;
      createdContentKind = 'video';
      result = ok ? 'VALID' : 'INVALID';
      status = _c('done');
    });

    if (ok) {
""",
    """    setState(() {
      videoPath = savedVideoPath;
      hcvPath = hcv;
      packagePath = pack;
      hcvId = detectedId;
      verificationUrl = detectedUrl;
      createdContentKind = 'video';
      result = ok ? 'VALID' : 'INVALID';
      status = _c('done');
    });

    // Unlock as soon as the essential local artifacts are coherent. Registry
    // publication may continue/retry without holding the camera lifecycle.
    if (_captureLifecycle == HCVCaptureLifecycle.processingVideo) {
      _setCaptureLifecycle(HCVCaptureLifecycle.idle);
    }

    if (ok) {
""",
    'video unlock after local artifacts',
)

# Remove the two legacy result-screen assignments. Recording is now derived
# exclusively from HCVCaptureLifecycle.
text, removed_recording_false = re.subn(
    r'^\s{32}recording = false;\n',
    '',
    text,
    flags=re.MULTILINE,
)
if removed_recording_false != 2:
    raise SystemExit(
        'result-screen recording assignments: expected 2, '
        f'found {removed_recording_false}'
    )

replace_once(
    """      onPressed: () => setZoom(value),
""",
    """      onPressed: _captureInteractionLocked ? null : () => setZoom(value),
""",
    'zoom preset UI guard',
)

replace_once(
    """    return Scaffold(
      backgroundColor: Colors.black,
""",
    """    return PopScope(
      canPop: !_captureInteractionLocked,
      child: Scaffold(
        backgroundColor: Colors.black,
""",
    'PopScope wrapper',
)

replace_once(
    """        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
""",
    """        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _captureInteractionLocked
              ? null
              : () {
                  Navigator.of(context).pop();
                },
        ),
""",
    'AppBar back guard',
)

replace_once(
    """            onPressed: _locationBusy ? null : _toggleCoordinateStamp,
""",
    """            onPressed: _captureInteractionLocked || _locationBusy
                ? null
                : _toggleCoordinateStamp,
""",
    'GPS UI guard',
)

replace_once(
    """            onPressed: toggleFlash,
""",
    """            onPressed: _captureInteractionLocked ? null : toggleFlash,
""",
    'flash UI guard',
)

replace_once(
    """            onPressed: switchCamera,
""",
    """            onPressed: _captureInteractionLocked ? null : switchCamera,
""",
    'camera switch UI guard',
)

replace_once(
    """                          onChanged: (value) async {
                            await setZoom(value);
                          },
""",
    """                          onChanged: _captureInteractionLocked
                              ? null
                              : (value) async {
                                  await setZoom(value);
                                },
""",
    'zoom slider UI guard',
)

replace_once(
    """                            onSelected: (_) {
                              setState(() {
                                photoMode = false;
                              });
                            },
""",
    """                            onSelected: _captureInteractionLocked
                                ? null
                                : (_) => _setPhotoMode(false),
""",
    'video mode UI guard',
)

replace_once(
    """                            onSelected: (_) {
                              pendingLiveScreenProbe = null;
                              pendingVideoLocation = null;
                              setState(() {
                                photoMode = true;
                              });
                            },
""",
    """                            onSelected: _captureInteractionLocked
                                ? null
                                : (_) => _setPhotoMode(true),
""",
    'photo mode UI guard',
)

replace_once(
    """                        onTap: !ready || _videoFinalizeInProgress
                            ? null
                            : () async {
                                if (photoMode) {
                                  await takePhoto();
                                  return;
                                }

                                if (recording) {
                                  await stop();
                                  return;
                                }

                                await start();
                              },
""",
    """                        onTap: !_captureButtonEnabled
                            ? null
                            : () async {
                                if (_captureLifecycle ==
                                    HCVCaptureLifecycle.recording) {
                                  await stop();
                                  return;
                                }
                                if (photoMode) {
                                  await takePhoto();
                                  return;
                                }
                                await start();
                              },
""",
    'capture button lifecycle guard',
)

replace_once(
    """        ],
      ),
    );
  }
}
""",
    """        ],
      ),
      ),
    );
  }
}
""",
    'PopScope close',
)

if '_videoFinalizeInProgress' in text:
    raise SystemExit('legacy _videoFinalizeInProgress still present')
if re.search(r'\brecording\s*=\s*(true|false)', text):
    raise SystemExit('legacy recording assignment still present')

CAMERA.write_text(text, encoding='utf-8')

LIFECYCLE.write_text(
    textwrap.dedent(
        """\
        enum HCVCaptureLifecycle {
          idle,
          preparingVideo,
          recording,
          finalizingVideo,
          processingVideo,
          capturingPhoto,
          processingPhoto,
        }

        extension HCVCaptureLifecyclePolicy on HCVCaptureLifecycle {
          bool get interactionLocked => this != HCVCaptureLifecycle.idle;

          bool get captureButtonEnabled =>
              this == HCVCaptureLifecycle.idle ||
              this == HCVCaptureLifecycle.recording;

          bool get captureSettingsMutable => this == HCVCaptureLifecycle.idle;

          bool get canStopRecording => this == HCVCaptureLifecycle.recording;
        }
        """
    ),
    encoding='utf-8',
)

TEST.write_text(
    textwrap.dedent(
        """\
        import 'dart:io';

        import 'package:flutter_test/flutter_test.dart';
        import 'package:sigillum_iphone/hcv_capture_lifecycle.dart';

        void main() {
          test('capture lifecycle has one interaction policy', () {
            expect(HCVCaptureLifecycle.idle.interactionLocked, isFalse);
            expect(HCVCaptureLifecycle.idle.captureButtonEnabled, isTrue);
            expect(HCVCaptureLifecycle.idle.captureSettingsMutable, isTrue);
            expect(HCVCaptureLifecycle.idle.canStopRecording, isFalse);

            expect(HCVCaptureLifecycle.recording.interactionLocked, isTrue);
            expect(HCVCaptureLifecycle.recording.captureButtonEnabled, isTrue);
            expect(HCVCaptureLifecycle.recording.captureSettingsMutable, isFalse);
            expect(HCVCaptureLifecycle.recording.canStopRecording, isTrue);

            for (final state in <HCVCaptureLifecycle>[
              HCVCaptureLifecycle.preparingVideo,
              HCVCaptureLifecycle.finalizingVideo,
              HCVCaptureLifecycle.processingVideo,
              HCVCaptureLifecycle.capturingPhoto,
              HCVCaptureLifecycle.processingPhoto,
            ]) {
              expect(state.interactionLocked, isTrue, reason: state.name);
              expect(state.captureButtonEnabled, isFalse, reason: state.name);
              expect(state.captureSettingsMutable, isFalse, reason: state.name);
              expect(state.canStopRecording, isFalse, reason: state.name);
            }
          });

          test('camera source enforces lifecycle before first async capture work', () {
            final source = File('lib/camera_page.dart').readAsStringSync();

            expect(source, contains('PopScope('));
            expect(source, contains('canPop: !_captureInteractionLocked'));
            expect(source, isNot(contains('_videoFinalizeInProgress')));
            expect(source, isNot(matches(RegExp(r'\\brecording\\s*=\\s*(true|false)'))));

            final start = source.indexOf('Future<void> start() async');
            final preparing = source.indexOf(
              '_setCaptureLifecycle(HCVCaptureLifecycle.preparingVideo);',
              start,
            );
            final startLocation = source.indexOf(
              'final captureLocation = await _locationForCapture();',
              start,
            );
            expect(preparing, greaterThan(start));
            expect(startLocation, greaterThan(preparing));

            final stop = source.indexOf('Future<void> stop() async');
            final finalizing = source.indexOf(
              '_setCaptureLifecycle(HCVCaptureLifecycle.finalizingVideo);',
              stop,
            );
            final stopRecording = source.indexOf(
              'await controller!.stopVideoRecording();',
              stop,
            );
            expect(finalizing, greaterThan(stop));
            expect(stopRecording, greaterThan(finalizing));

            final photo = source.indexOf('Future<void> takePhoto() async');
            final capturingPhoto = source.indexOf(
              '_setCaptureLifecycle(HCVCaptureLifecycle.capturingPhoto);',
              photo,
            );
            final photoLocation = source.indexOf(
              'final captureLocation = await _locationForCapture();',
              photo,
            );
            expect(capturingPhoto, greaterThan(photo));
            expect(photoLocation, greaterThan(capturingPhoto));
          });

          test('capture controls and torch handoff are guarded', () {
            final source = File('lib/camera_page.dart').readAsStringSync();

            expect(
              source,
              contains('if (_captureInteractionLocked || _locationBusy) return;'),
            );
            expect(source, contains('Future<void> switchCamera() async {\n    if (_captureInteractionLocked) return;'));
            expect(source, contains('Future<void> toggleFlash() async {\n    if (_captureInteractionLocked) return;'));
            expect(source, contains('Future<void> setZoom(double zoom) async {\n    if (_captureInteractionLocked) return;'));
            expect(source, contains('onPressed: _captureInteractionLocked ? null : toggleFlash'));
            expect(source, contains('onPressed: _captureInteractionLocked ? null : switchCamera'));
            expect(source, contains("'actualTorchStateDuringProbe': 'NOT_VERIFIED_NATIVE_SESSION'"));
            expect(source, contains("'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL'"));
            expect(source, contains('USER_FLASH_RESTORE_AFTER_NATIVE_PROBE_FAILED'));
            expect(source, contains('USER_FLASH_RESTORE_BEFORE_PHOTO_FAILED'));
          });
        }
        """
    ),
    encoding='utf-8',
)

if text == original:
    raise SystemExit('camera_page.dart was not modified')

print('BUILD92 capture lifecycle patch applied')
print(f'camera bytes: {len(original)} -> {len(text)}')
print(f'created: {LIFECYCLE}')
print(f'created: {TEST}')
