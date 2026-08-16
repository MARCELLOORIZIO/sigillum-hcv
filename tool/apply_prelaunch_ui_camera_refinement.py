from pathlib import Path
import re


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Commercial account UX only: make password recovery reactive so that after
# the user types the emailed code the CTA becomes REIMPOSTA PASSWORD. Also
# close/save the iOS AutoFill context after a successful password reset.
# ---------------------------------------------------------------------------
gate_path = Path('lib/commercial_gate.dart')
gate = gate_path.read_text(encoding='utf-8')

forgot_code_old = """          TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(
                  labelText: 'Codice ricevuto (lascia vuoto per inviarlo)',
                  border: OutlineInputBorder())),
"""
forgot_code_new = """          TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'Codice ricevuto (lascia vuoto per inviarlo)',
                  border: OutlineInputBorder())),
"""
gate = replace_once(
    gate,
    forgot_code_old,
    forgot_code_new,
    'reactive password recovery code field',
)

reset_success_old = """        if (!mounted) return;
        setState(() {
          _forgotMode = false;
          _password.text = _newPassword.text;
          _code.clear();
          _newPassword.clear();
          _message = 'Password aggiornata. Ora puoi accedere.';
        });
"""
reset_success_new = """        if (!mounted) return;
        final updatedPassword = _newPassword.text;
        TextInput.finishAutofillContext(shouldSave: true);
        setState(() {
          _forgotMode = false;
          _password.text = updatedPassword;
          _code.clear();
          _newPassword.clear();
          _message = 'Password aggiornata. Ora puoi accedere.';
        });
"""
gate = replace_once(
    gate,
    reset_success_old,
    reset_success_new,
    'save updated password in AutoFill context',
)

for token in [
    "onChanged: (_) => setState(() {}),",
    "final updatedPassword = _newPassword.text;",
    "TextInput.finishAutofillContext(shouldSave: true);",
    "'REIMPOSTA PASSWORD'",
]:
    if token not in gate:
        raise RuntimeError(f'password recovery UX token missing: {token}')

gate_path.write_text(gate, encoding='utf-8')


# ---------------------------------------------------------------------------
# Camera interaction refinement ONLY.
# This intentionally does not change HCVEngine, display-risk analysis,
# evidence, hashes, signatures, claims, Registry payloads or verifier logic.
# It only caps the user zoom control at 10x, enlarges the existing PROSEGUI
# CTA, and separates VIDEO probe/arming from the explicit start-recording tap.
# ---------------------------------------------------------------------------
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text(encoding='utf-8')

# Device zoom can be very large on iOS. Earlier build-time patches can leave
# one or more initialization sites, so cap every remaining raw max-zoom read
# instead of assuming a fixed number of anchors.
zoom_assignment = "      maxZoom = await controller!.getMaxZoomLevel();\n"
zoom_replacement = """      final deviceMaxZoom = await controller!.getMaxZoomLevel();
      maxZoom = deviceMaxZoom.clamp(minZoom, 10.0).toDouble();
      currentZoom = currentZoom.clamp(minZoom, maxZoom).toDouble();
      await controller!.setZoomLevel(currentZoom);
"""
raw_zoom_count = camera.count(zoom_assignment)
if raw_zoom_count == 0 and 'deviceMaxZoom.clamp(minZoom, 10.0)' not in camera:
    raise RuntimeError('zoom max assignment anchor missing')
if raw_zoom_count:
    camera = camera.replace(zoom_assignment, zoom_replacement)
if zoom_assignment in camera:
    raise RuntimeError('uncapped camera max zoom remains')

# Video arming state is adjacent to the already-isolated photo arming state.
video_state_old = """  int? _armedPhotoCameraIndex;
  double? _armedPhotoZoom;
"""
video_state_new = """  int? _armedPhotoCameraIndex;
  double? _armedPhotoZoom;
  bool _videoArmed = false;
  DateTime? _videoArmExpiresAt;
  int? _videoArmCameraIndex;
  double? _videoArmZoom;
"""
camera = replace_once(
    camera,
    video_state_old,
    video_state_new,
    'video arming state',
)

# Make the existing confirmation CTA an obvious primary action.
proceed_old = """          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              italian ? 'ORA PUOI PROCEDERE' : 'PROCEED NOW',
            ),
          ),
"""
proceed_new = """          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(230, 58),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              italian ? 'ORA PUOI PROCEDERE' : 'PROCEED NOW',
            ),
          ),
"""
camera = replace_once(
    camera,
    proceed_old,
    proceed_new,
    'larger proceed CTA',
)

# Replace only the VIDEO start-control method. The same pre-capture probe and
# location are preserved and consumed by the second explicit REC tap.
start_pattern = re.compile(
    r"  Future<void> start\(\) async \{.*?\n  \}\n\n  Future<void> stop\(\) async \{",
    re.S,
)
start_replacement = r'''  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final now = DateTime.now();
    final armedIsValid = _videoArmed &&
        pendingLiveScreenProbe != null &&
        _videoArmExpiresAt != null &&
        now.isBefore(_videoArmExpiresAt!) &&
        _videoArmCameraIndex == selectedCameraIndex &&
        _videoArmZoom != null &&
        (currentZoom - _videoArmZoom!).abs() < 0.01;

    if (!armedIsValid) {
      _videoArmed = false;
      _videoArmExpiresAt = null;
      _videoArmCameraIndex = null;
      _videoArmZoom = null;
      pendingLiveScreenProbe = null;
      pendingVideoLocation = null;

      final captureLocation = await _locationForCapture();
      if (_printCoordinates && captureLocation == null) return;

      setState(() {
        status = _physicalProbeStatus;
        result = null;
        videoPath = null;
        hcvPath = null;
        packagePath = null;
        hcvId = null;
        verificationUrl = null;
        registryStatus = null;
        recording = false;
      });

      try {
        pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
        pendingVideoLocation = captureLocation;
        _videoArmed = true;
        _videoArmExpiresAt = DateTime.now().add(const Duration(seconds: 15));
        _videoArmCameraIndex = selectedCameraIndex;
        _videoArmZoom = currentZoom;
        await _showCaptureReadyMessage();
        if (!mounted) return;
        setState(() {
          status = widget.languageCode.toLowerCase().startsWith('it')
              ? 'PRONTO — PREMI REGISTRA PER INIZIARE'
              : 'READY — PRESS RECORD TO START';
          recording = false;
        });
      } catch (e) {
        pendingLiveScreenProbe = null;
        pendingVideoLocation = null;
        _videoArmed = false;
        _videoArmExpiresAt = null;
        _videoArmCameraIndex = null;
        _videoArmZoom = null;
        if (mounted) {
          setState(() {
            recording = false;
            status = 'ERROR START: $e';
          });
        }
      }
      return;
    }

    _videoArmed = false;
    _videoArmExpiresAt = null;
    _videoArmCameraIndex = null;
    _videoArmZoom = null;

    setState(() {
      recording = true;
      status = 'STARTING...';
    });

    try {
      await controller!.startVideoRecording();
      pendingVideoCapturedAt = DateTime.now();

      try {
        await liveSignals.start();
      } catch (_) {
        lastLiveSignals = null;
      }

      setState(() => status = 'RECORDING...');
    } catch (e) {
      pendingVideoCapturedAt = null;
      pendingVideoLocation = null;
      pendingLiveScreenProbe = null;
      setState(() {
        recording = false;
        status = 'ERROR START: $e';
      });
    }
  }

  Future<void> stop() async {'''
camera, start_count = start_pattern.subn(start_replacement, camera, count=1)
if start_count != 1 and 'PRONTO — PREMI REGISTRA PER INIZIARE' not in camera:
    raise RuntimeError('video two-step start method anchor missing')

# Switching camera invalidates any pending armed video evidence.
switch_old = """  Future<void> switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    selectedCameraIndex = selectedCameraIndex == 0 ? 1 : 0;
"""
switch_new = """  Future<void> switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    _videoArmed = false;
    _videoArmExpiresAt = null;
    _videoArmCameraIndex = null;
    _videoArmZoom = null;
    pendingLiveScreenProbe = null;
    pendingVideoLocation = null;

    selectedCameraIndex = selectedCameraIndex == 0 ? 1 : 0;
"""
camera = replace_once(
    camera,
    switch_old,
    switch_new,
    'invalidate video arm on camera switch',
)

# Entering PHOTO mode also invalidates any pending VIDEO arm.
photo_select_old = """                            onSelected: (_) {
                              setState(() {
                                photoMode = true;
                              });
                            },
"""
photo_select_new = """                            onSelected: (_) {
                              _videoArmed = false;
                              _videoArmExpiresAt = null;
                              _videoArmCameraIndex = null;
                              _videoArmZoom = null;
                              pendingLiveScreenProbe = null;
                              pendingVideoLocation = null;
                              setState(() {
                                photoMode = true;
                              });
                            },
"""
camera = replace_once(
    camera,
    photo_select_old,
    photo_select_new,
    'invalidate video arm on photo selection',
)

required_camera_tokens = [
    'deviceMaxZoom.clamp(minZoom, 10.0)',
    'minimumSize: const Size(230, 58)',
    'PRONTO — PREMI REGISTRA PER INIZIARE',
    'bool _videoArmed = false;',
    'pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();',
    'await controller!.startVideoRecording();',
]
for token in required_camera_tokens:
    if token not in camera:
        raise RuntimeError(f'camera UX token missing: {token}')

for forbidden in [
    'HCVDisplayRiskFusion.combine =',
    'HCVEngine().',
    'verifyFile =',
]:
    if forbidden in camera:
        raise RuntimeError(f'unexpected engine mutation marker: {forbidden}')

camera_path.write_text(camera, encoding='utf-8')
print('Prelaunch password, zoom, proceed and explicit video REC UX refinement applied')
