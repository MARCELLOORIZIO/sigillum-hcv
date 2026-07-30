from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return source.replace(old, new, 1)


camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text()

camera = replace_once(
    camera,
    """HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  return HCVDisplayRiskFusion.combine(analyses, liveCaptureOnly: true);
}

class CameraPage extends StatefulWidget {""",
    """HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  return HCVDisplayRiskFusion.combine(analyses, liveCaptureOnly: true);
}

HCVDisplayRiskResult combineVideoDisplayRiskWithPreCaptureEvidence(
  Map<String, dynamic>? liveScreenProbe,
  Map<String, dynamic>? screenReplayAnalysis,
  Map<String, dynamic>? mlScreenReplayAnalysis,
) {
  final analyses = <Map<String, dynamic>?>[liveScreenProbe];
  final temporalProbe = liveScreenProbe?['photoTemporalVideoProbe'];
  if (temporalProbe is Map) {
    final temporalOptical = temporalProbe['screenReplayAnalysis'];
    if (temporalOptical is Map) {
      analyses.add(Map<String, dynamic>.from(temporalOptical));
    }
    final temporalMl = temporalProbe['mlScreenReplayAnalysis'];
    if (temporalMl is Map) {
      analyses.add(Map<String, dynamic>.from(temporalMl));
    }
  }
  analyses.add(screenReplayAnalysis);
  analyses.add(mlScreenReplayAnalysis);
  return HCVDisplayRiskFusion.combine(analyses);
}

class CameraPage extends StatefulWidget {""",
    'video pre-capture evidence helper',
)

camera = replace_once(
    camera,
    """  Map<String, dynamic>? pendingLiveScreenProbe;
  DateTime? pendingVideoCapturedAt;

  bool ready = false;""",
    """  Map<String, dynamic>? pendingLiveScreenProbe;
  DateTime? pendingVideoCapturedAt;
  bool _captureProbeRunning = false;
  bool _captureProbeReady = false;
  String? _captureProbeMode;

  bool ready = false;""",
    'camera probe state',
)

camera = replace_once(
    camera,
    """  String get _physicalProbeStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'
          : 'MOVE THE PHONE SLIGHTLY SIDEWAYS...';

  @override""",
    """  String get _physicalProbeStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'MUOVI LEGGERMENTE IL TELEFONO LATERALMENTE...'
          : 'MOVE THE PHONE SLIGHTLY SIDEWAYS...';

  String get _physicalProbeReadyStatus =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'VERIFICA COMPLETATA. RIPORTA IL TELEFONO SULL’INQUADRATURA. ORA PUOI PROCEDERE: TOCCA DI NUOVO.'
          : 'VERIFICATION COMPLETE. RETURN TO YOUR COMPOSITION. YOU CAN NOW PROCEED: TAP AGAIN.';

  @override""",
    'camera ready message',
)

camera = replace_once(
    camera,
    """    if (!mounted) return;

    setState(() {});
  }

  Future<void> toggleFlash() async {""",
    """    if (!mounted) return;

    setState(() {
      _clearPreparedCaptureProbe();
      status = 'READY';
    });
  }

  Future<void> toggleFlash() async {""",
    'switch camera invalidates prepared probe',
)

camera = replace_once(
    camera,
    """    await controller!.setFlashMode(currentFlashMode);

    setState(() {});
  }

  Future<Map<String, dynamic>> _analyzeLiveScreenProbeWithoutFlash() async {""",
    """    await controller!.setFlashMode(currentFlashMode);

    setState(() {
      _clearPreparedCaptureProbe();
      status = 'READY';
    });
  }

  Future<Map<String, dynamic>> _analyzeLiveScreenProbeWithoutFlash() async {""",
    'flash invalidates prepared probe',
)

camera = replace_once(
    camera,
    """  Future<void> _settleCameraAfterLiveProbe() async {""",
    """  void _clearPreparedCaptureProbe() {
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
      final analysis = await _analyzeLiveScreenProbeWithoutFlash();
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

  Future<void> _settleCameraAfterLiveProbe() async {""",
    'two-step original probe preparation',
)

camera = replace_once(
    camera,
    """      setState(() {
        currentZoom = safeZoom;
      });""",
    """      setState(() {
        currentZoom = safeZoom;
        _clearPreparedCaptureProbe();
        status = 'READY';
      });""",
    'zoom invalidates prepared probe',
)

old_start = """  Future<void> start() async {
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

      await controller!.startVideoRecording();"""
new_start = """  Future<void> start() async {
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
        status = 'READY';
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
      await controller!.startVideoRecording();"""
camera = replace_once(camera, old_start, new_start, 'video second tap flow')

old_photo = """  Future<void> takePhoto() async {
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

      final file = await controller!.takePicture();"""
new_photo = """  Future<void> takePhoto() async {
    if (controller == null) return;

    if (!_captureProbeReady || _captureProbeMode != 'photo') {
      await _prepareCaptureProbe(photo: true);
      return;
    }

    final liveScreenProbe = pendingLiveScreenProbe;
    if (liveScreenProbe == null) {
      setState(() {
        _clearPreparedCaptureProbe();
        status = 'READY';
      });
      return;
    }

    try {
      setState(() {
        pendingLiveScreenProbe = null;
        _captureProbeReady = false;
        _captureProbeMode = null;
        status = 'SCATTO FOTO...';
      });

      final file = await controller!.takePicture();"""
camera = replace_once(camera, old_photo, new_photo, 'photo second tap flow')

camera = replace_once(
    camera,
    """    final displayRisk = HCVDisplayRiskFusion.combine(screenReplayAnalyses);""",
    """    final displayRisk = combineVideoDisplayRiskWithPreCaptureEvidence(
      liveScreenProbe,
      screenReplayAnalysis,
      mlScreenReplayAnalysis,
    );""",
    'video uses pre-capture temporal evidence',
)

camera = replace_once(
    camera,
    """    final ok = controller != null && controller!.value.isInitialized;

    return Scaffold(""",
    """    final ok = controller != null && controller!.value.isInitialized;
    final captureReadyForCurrentMode = _captureProbeReady &&
        _captureProbeMode == (photoMode ? 'photo' : 'video');

    return Scaffold(""",
    'camera ready UI state',
)

camera = replace_once(
    camera,
    """                            onSelected: (_) {
                              setState(() {
                                photoMode = false;
                              });
                            },""",
    """                            onSelected: (_) {
                              setState(() {
                                photoMode = false;
                                _clearPreparedCaptureProbe();
                                status = 'READY';
                              });
                            },""",
    'video mode invalidates prepared probe',
)

camera = replace_once(
    camera,
    """                            onSelected: (_) {
                              setState(() {
                                photoMode = true;
                              });
                            },""",
    """                            onSelected: (_) {
                              setState(() {
                                photoMode = true;
                                _clearPreparedCaptureProbe();
                                status = 'READY';
                              });
                            },""",
    'photo mode invalidates prepared probe',
)

camera = replace_once(
    camera,
    """                        onTap: !ready
                            ? null
                            : () async {""",
    """                        onTap: !ready || _captureProbeRunning
                            ? null
                            : () async {""",
    'disable capture while probe runs',
)

camera = replace_once(
    camera,
    """                            color: recording ? Colors.red : Colors.white,""",
    """                            color: recording
                                ? Colors.red
                                : captureReadyForCurrentMode
                                    ? Colors.green
                                    : Colors.white,""",
    'green ready camera button',
)

camera = replace_once(
    camera,
    """                                : Icon(
                                    photoMode
                                        ? Icons.camera_alt
                                        : Icons.videocam,
                                    color: Colors.black,
                                    size: 34,
                                  ),""",
    """                                : Icon(
                                    captureReadyForCurrentMode
                                        ? Icons.check_rounded
                                        : photoMode
                                            ? Icons.camera_alt
                                            : Icons.videocam,
                                    color: Colors.black,
                                    size: 34,
                                  ),""",
    'camera ready check icon',
)

# Reset any prepared evidence when returning from a completed result.
camera = camera.replace(
    """                                recording = false;
                              });""",
    """                                recording = false;
                                _clearPreparedCaptureProbe();
                              });""",
)

camera_path.write_text(camera)


account_path = Path('lib/account_page.dart')
account = account_path.read_text()

account = replace_once(
    account,
    """import 'package:flutter/material.dart';""",
    """import 'dart:async';

import 'package:flutter/material.dart';""",
    'account timer import',
)

account = replace_once(
    account,
    """  bool _obscurePassword = true;
  String? _error;""",
    """  bool _obscurePassword = true;
  String? _error;
  String? _successfulAction;
  Timer? _successTimer;""",
    'account success state',
)

account = replace_once(
    account,
    """  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }""",
    """  void dispose() {
    _successTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }""",
    'cancel account success timer',
)

account = replace_once(
    account,
    """      _passwordController.clear();
      _showMessage(_t('registered'));""",
    """      _passwordController.clear();
      _markActionSuccessful('register');
      _showMessage(_t('registered'));""",
    'register success feedback',
)

account = replace_once(
    account,
    """      _passwordController.clear();
      _showMessage(_t('loggedIn'));""",
    """      _passwordController.clear();
      _markActionSuccessful('login');
      _showMessage(_t('loggedIn'));""",
    'login success feedback',
)

account = replace_once(
    account,
    """      if (mounted) setState(() => _identity = identity);
      _showMessage(_t('saved'));""",
    """      if (mounted) setState(() => _identity = identity);
      _markActionSuccessful('save');
      _showMessage(_t('saved'));""",
    'profile success feedback',
)

account = replace_once(
    account,
    """      await _auth.changePassword(
        currentPassword: values[0],
        newPassword: values[1],
      );
      _showMessage(_t('passwordChanged'));""",
    """      await _auth.changePassword(
        currentPassword: values[0],
        newPassword: values[1],
      );
      _markActionSuccessful('password');
      _showMessage(_t('passwordChanged'));""",
    'password success feedback',
)

account = replace_once(
    account,
    """      await showDialog<void>(
        context: context,""",
    """      await showDialog<void>(
        context: context,""",
    'devices dialog anchor',
)
account = replace_once(
    account,
    """      );
    });
  }

  Future<void> _deleteAccount() async {""",
    """      );
      _markActionSuccessful('devices');
    });
  }

  Future<void> _deleteAccount() async {""",
    'devices success feedback',
)

account = replace_once(
    account,
    """  void _showMessage(String message) {""",
    """  void _markActionSuccessful(String action) {
    _successTimer?.cancel();
    if (!mounted) return;
    setState(() => _successfulAction = action);
    _successTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _successfulAction == action) {
        setState(() => _successfulAction = null);
      }
    });
  }

  bool _actionSucceeded(String action) => _successfulAction == action;

  ButtonStyle? _filledSuccessStyle(String action) {
    if (!_actionSucceeded(action)) return null;
    return FilledButton.styleFrom(
      backgroundColor: SigillumTheme.verified,
      foregroundColor: SigillumTheme.ivory,
    );
  }

  ButtonStyle? _outlinedSuccessStyle(String action) {
    if (!_actionSucceeded(action)) return null;
    return OutlinedButton.styleFrom(
      backgroundColor: SigillumTheme.verified,
      foregroundColor: SigillumTheme.ivory,
      side: const BorderSide(color: SigillumTheme.verified),
    );
  }

  IconData _successIcon(String action, IconData normal) =>
      _actionSucceeded(action) ? Icons.check_circle_rounded : normal;

  void _showMessage(String message) {""",
    'account success helpers',
)

account = replace_once(
    account,
    """              FilledButton.icon(
                onPressed: _busy ? null : _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: Text(_t('save')),
              ),""",
    """              FilledButton.icon(
                onPressed: _busy ? null : _saveProfile,
                style: _filledSuccessStyle('save'),
                icon: Icon(_successIcon('save', Icons.save_outlined)),
                label: Text(_t('save')),
              ),""",
    'save button feedback',
)

account = replace_once(
    account,
    """                        await _loadAccount();
                      },
                icon: const Icon(Icons.badge_outlined),""",
    """                        await _loadAccount();
                        _markActionSuccessful('identity');
                      },
                style: _outlinedSuccessStyle('identity'),
                icon: Icon(
                  _successIcon('identity', Icons.badge_outlined),
                ),""",
    'identity button feedback',
)

account = replace_once(
    account,
    """      FilledButton.icon(
        onPressed: _busy ? null : _register,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_t('createAccount')),
      ),""",
    """      FilledButton.icon(
        onPressed: _busy ? null : _register,
        style: _filledSuccessStyle('register'),
        icon: Icon(
          _successIcon('register', Icons.person_add_alt_1_rounded),
        ),
        label: Text(_t('createAccount')),
      ),""",
    'register button feedback',
)

account = replace_once(
    account,
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _login,
        icon: const Icon(Icons.login_rounded),
        label: Text(_t('login')),
      ),""",
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _login,
        style: _outlinedSuccessStyle('login'),
        icon: Icon(_successIcon('login', Icons.login_rounded)),
        label: Text(_t('login')),
      ),""",
    'login button feedback',
)

account = replace_once(
    account,
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _showDevices,
        icon: const Icon(Icons.devices_rounded),
        label: Text(_t('devices')),
      ),""",
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _showDevices,
        style: _outlinedSuccessStyle('devices'),
        icon: Icon(_successIcon('devices', Icons.devices_rounded)),
        label: Text(_t('devices')),
      ),""",
    'devices button feedback',
)

account = replace_once(
    account,
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _changePassword,
        icon: const Icon(Icons.password_rounded),
        label: Text(_t('changePassword')),
      ),""",
    """      OutlinedButton.icon(
        onPressed: _busy ? null : _changePassword,
        style: _outlinedSuccessStyle('password'),
        icon: Icon(_successIcon('password', Icons.password_rounded)),
        label: Text(_t('changePassword')),
      ),""",
    'password button feedback',
)

account_path.write_text(account)


Path('test/camera_ready_video_evidence_contract_test.dart').write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('camera readiness and video evidence', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final probe = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    final geometry =
        File('lib/hcv_scene_geometry_classifier.dart').readAsStringSync();

    test('the original monitor detector remains untouched', () {
      expect(probe, isNot(contains('waitForSufficientMovement')));
      expect(probe, isNot(contains('geometryOverride')));
      expect(geometry, isNot(contains('movementSufficient')));
    });

    test('capture waits for a second tap after the original full probe', () {
      expect(camera, contains('_physicalProbeReadyStatus'));
      expect(camera, contains('await _prepareCaptureProbe(photo: true)'));
      expect(camera, contains('await _prepareCaptureProbe(photo: false)'));
      expect(
        camera,
        contains('final analysis = await _analyzeLiveScreenProbeWithoutFlash();'),
      );
      expect(camera, contains("_captureProbeMode != 'photo'"));
      expect(camera, contains("_captureProbeMode != 'video'"));
    });

    test('video includes the same pre-capture temporal evidence used by photo', () {
      expect(camera, contains('combineVideoDisplayRiskWithPreCaptureEvidence'));
      expect(camera, contains("liveScreenProbe?['photoTemporalVideoProbe']"));
      expect(camera, contains("temporalProbe['screenReplayAnalysis']"));
      expect(camera, contains("temporalProbe['mlScreenReplayAnalysis']"));
    });

    test('instruction remains in the upper status badge only', () {
      expect(camera, contains('child: _statusBadge()'));
      expect(camera, isNot(contains('_preparedCaptureActionLabel')));
    });
  });
}
""")

account_test_path = Path('test/account_page_contract_test.dart')
account_test = account_test_path.read_text()
account_test = replace_once(
    account_test,
    """    test('session token uses native secure storage on iOS and Android', () {""",
    """    test('successful account actions turn their buttons green', () {
      expect(account, contains('_markActionSuccessful'));
      expect(account, contains('_filledSuccessStyle'));
      expect(account, contains('_outlinedSuccessStyle'));
      expect(account, contains('SigillumTheme.verified'));
      expect(account, contains('Icons.check_circle_rounded'));
    });

    test('session token uses native secure storage on iOS and Android', () {""",
    'account success feedback contract',
)
account_test_path.write_text(account_test)
