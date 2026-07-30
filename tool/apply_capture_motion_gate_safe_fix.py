from pathlib import Path
import re


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


# Restore the monitor/scene classifier exactly to its pre-UX-change shape.
classifier_path = Path('lib/hcv_scene_geometry_classifier.dart')
classifier = classifier_path.read_text()
classifier = classifier.replace(
    "\n  bool get movementSufficient =>\n      matchedRegions >= 5 && motionMagnitude >= 0.16 && flowReliability >= 0.46;\n",
    "",
    1,
)
classifier = classifier.replace(
    "        'movementSufficient': movementSufficient,\n",
    "",
    1,
)
if 'bool get movementSufficient' in classifier or "'movementSufficient': movementSufficient" in classifier:
    raise RuntimeError('Unable to restore original geometry classifier')
classifier_path.write_text(classifier)


# Restore the original live monitor probe. The UX gate must not inject or
# override geometry inside monitor detection.
core_path = Path('lib/hcv_live_screen_probe_core.dart')
core = core_path.read_text()
core, removed = re.subn(
    r"  Future<HCVSceneGeometryClassification> waitForSufficientMovement\(.*?\n  \}\n\n  Future<Map<String, dynamic>> analyzePreview\(",
    "  Future<Map<String, dynamic>> analyzePreview(",
    core,
    count=1,
    flags=re.S,
)
if removed != 1:
    raise RuntimeError(f'Unable to remove separate movement probe: {removed}')
core = core.replace(
    "    HCVSceneGeometryClassification? geometryOverride,\n",
    "",
    1,
)
core = replace_once(
    core,
    """    final geometry = geometryOverride ??
        _analyzeGeometry(<_FrameStats>[
          ...baselineFrames,
          ...recoveryFrames,
        ]);""",
    """    final geometry = _analyzeGeometry(<_FrameStats>[
      ...baselineFrames,
      ...recoveryFrames,
    ]);""",
    'original live geometry analysis',
)
core = core.replace(
    "        'geometryMovementSufficient': geometry.movementSufficient,\n",
    "",
    1,
)
for forbidden in ('waitForSufficientMovement', 'geometryOverride', 'geometryMovementSufficient'):
    if forbidden in core:
        raise RuntimeError(f'Live monitor probe still contains UX override: {forbidden}')
core_path.write_text(core)


camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()
camera = camera.replace("import 'hcv_scene_geometry_classifier.dart';\n", "", 1)

# Remove the redundant lower-screen instruction and the intermediate message.
camera, count = re.subn(
    r"\n  String get _physicalProbeCompletingStatus =>.*?\n  String get _physicalProbeReadyStatus =>",
    "\n  String get _physicalProbeReadyStatus =>",
    camera,
    count=1,
    flags=re.S,
)
if count != 1:
    raise RuntimeError('Unable to remove completing status')
camera, count = re.subn(
    r"\n  String get _preparedCaptureActionLabel =>.*?;\n\n  @override",
    "\n\n  @override",
    camera,
    count=1,
    flags=re.S,
)
if count != 1:
    raise RuntimeError('Unable to remove lower action label')

camera = replace_once(
    camera,
    """  Future<Map<String, dynamic>> _analyzeLiveScreenProbeWithoutFlash({
    HCVSceneGeometryClassification? geometryOverride,
  }) async {""",
    """  Future<Map<String, dynamic>> _analyzeLiveScreenProbeWithoutFlash() async {""",
    'camera original probe signature',
)
camera = replace_once(
    camera,
    """      final analysis = await HCVLiveScreenProbe().analyzePreview(
        camera,
        restoreZoomLevel: currentZoom,
        geometryOverride: geometryOverride,
      );""",
    """      final analysis = await HCVLiveScreenProbe().analyzePreview(
        camera,
        restoreZoomLevel: currentZoom,
      );""",
    'camera original probe call',
)

prepare_pattern = (
    r"  Future<bool> _prepareCaptureProbe\(\{required bool photo\}\) async \{"
    r".*?"
    r"\n  \}\n\n  Future<void> _settleCameraAfterLiveProbe"
)
prepare_replacement = '''  Future<bool> _prepareCaptureProbe({required bool photo}) async {
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
      // Use the complete, original monitor probe unchanged. The movement gate
      // only reads its geometry result and never replaces detector evidence.
      final analysis = await _analyzeLiveScreenProbeWithoutFlash();
      await _settleCameraAfterLiveProbe();

      final rawGeometry = analysis['geometryChallenge'];
      final geometry = rawGeometry is Map
          ? Map<String, dynamic>.from(rawGeometry)
          : <String, dynamic>{};
      final matchedRegions = (geometry['matchedRegions'] as num?)?.toInt() ?? 0;
      final motionMagnitude =
          (geometry['motionMagnitude'] as num?)?.toDouble() ?? 0.0;
      final flowReliability =
          (geometry['flowReliability'] as num?)?.toDouble() ?? 0.0;
      final movementSufficient = matchedRegions >= 5 &&
          motionMagnitude >= 0.16 &&
          flowReliability >= 0.46;

      if (!movementSufficient) {
        if (mounted) {
          setState(() {
            status = _physicalProbeInsufficientStatus;
          });
        }
        return false;
      }

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

  Future<void> _settleCameraAfterLiveProbe'''
camera, count = re.subn(
    prepare_pattern,
    prepare_replacement,
    camera,
    count=1,
    flags=re.S,
)
if count != 1:
    raise RuntimeError(f'Unable to replace capture preparation: {count}')

# The only probe instruction remains in the upper status badge.
lower_status_old = '''                      Text(
                        _captureProbeRunning
                            ? _physicalProbeStatus
                            : recording
                                ? _t('recording')
                                : _captureProbeReady
                                    ? _preparedCaptureActionLabel
                                    : photoMode
                                        ? _t('photoMode')
                                        : _t('videoMode'),'''
lower_status_new = '''                      Text(
                        recording
                            ? _t('recording')
                            : photoMode
                                ? _t('photoMode')
                                : _t('videoMode'),'''
camera = replace_once(
    camera,
    lower_status_old,
    lower_status_new,
    'remove duplicate lower probe message',
)

for forbidden in (
    "import 'hcv_scene_geometry_classifier.dart';",
    'geometryOverride:',
    '_physicalProbeCompletingStatus',
    '_preparedCaptureActionLabel',
    'waitForSufficientMovement',
):
    if forbidden in camera:
        raise RuntimeError(f'Camera still contains unsafe detector integration: {forbidden}')

camera_path.write_text(camera)


Path('test/capture_motion_gate_contract_test.dart').write_text(
    '''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capture movement gate without detector changes', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final probe = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    final geometry =
        File('lib/hcv_scene_geometry_classifier.dart').readAsStringSync();

    test('monitor probe remains the original implementation', () {
      expect(probe, isNot(contains('waitForSufficientMovement')));
      expect(probe, isNot(contains('geometryOverride')));
      expect(probe, contains('final geometry = _analyzeGeometry(<_FrameStats>['));
      expect(geometry, isNot(contains('movementSufficient')));
    });

    test('movement gate only reads the original probe result', () {
      expect(camera, contains('final analysis = await _analyzeLiveScreenProbeWithoutFlash();'));
      expect(camera, contains("final rawGeometry = analysis['geometryChallenge'];"));
      expect(camera, contains('matchedRegions >= 5'));
      expect(camera, contains('motionMagnitude >= 0.16'));
      expect(camera, contains('flowReliability >= 0.46'));
      expect(camera, isNot(contains('geometryOverride')));
    });

    test('insufficient movement never captures and sufficient movement needs a second tap', () {
      expect(camera, contains('_captureProbeMode != \'photo\''));
      expect(camera, contains('_captureProbeMode != \'video\''));
      expect(camera, contains('MOVIMENTO NON SUFFICIENTE. NESSUNO SCATTO ESEGUITO'));
      expect(camera, contains('MOVIMENTO SUFFICIENTE. RIPORTA IL TELEFONO'));
    });

    test('probe instruction appears only in the upper status badge', () {
      expect(camera, contains('child: _statusBadge()'));
      expect(camera, isNot(contains('_preparedCaptureActionLabel')));
      expect(camera, isNot(contains('_captureProbeRunning\n                            ? _physicalProbeStatus')));
    });
  });
}
'''
)

print('Restored original monitor detector and kept only a camera-page movement gate')
