from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Text certificate page: close the keyboard and queue Registry failures.
# ---------------------------------------------------------------------------
text_path = Path('lib/text_cert_page.dart')
text = text_path.read_text(encoding='utf-8')

text = replace_once(
    text,
    """  @override
  void initState() {
    super.initState();
    status = _t('textWritePrompt');
  }
""",
    """  @override
  void initState() {
    super.initState();
    status = _t('textWritePrompt');
    Future.microtask(() async {
      try {
        await registry.retryPendingUploads();
      } catch (_) {}
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }
""",
    'text keyboard helper and retry',
)

text = replace_once(
    text,
    """  Future<void> createTextCertificate() async {
    final text = controller.text.trim();
""",
    """  Future<void> createTextCertificate() async {
    _dismissKeyboard();
    final text = controller.text.trim();
""",
    'dismiss keyboard on certify',
)

text = replace_once(
    text,
    """        } catch (e) {
          setState(() {
            registryStatus = 'Registry offline/non raggiungibile: $e';
          });
        }
""",
    """        } catch (e) {
          try {
            await registry.enqueueCertificateFile(finalHcvPath);
          } catch (_) {}
          if (mounted) {
            setState(() {
              registryStatus =
                  'Registry non disponibile: certificato conservato e accodato per il nuovo invio.';
            });
          }
        }
""",
    'queue text certificate upload failure',
)

text = replace_once(
    text,
    """  Future<void> openPublishedTextVerification() async {
    await Navigator.push(
""",
    """  Future<void> openPublishedTextVerification() async {
    _dismissKeyboard();
    await Navigator.push(
""",
    'dismiss keyboard before text verification route',
)

text_path.write_text(text, encoding='utf-8')


# ---------------------------------------------------------------------------
# Published-text verification: close keyboard and recover a missing Registry
# certificate from the creator device's persistent signed local copy.
# ---------------------------------------------------------------------------
verify_path = Path('lib/text_social_verify_page.dart')
verify = verify_path.read_text(encoding='utf-8')

verify = replace_once(
    verify,
    """  bool get _it => widget.languageCode.toLowerCase().startsWith('it');
  String _label(String it, String en) => _it ? it : en;
""",
    """  bool get _it => widget.languageCode.toLowerCase().startsWith('it');
  String _label(String it, String en) => _it ? it : en;

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  Future<File?> _findLocalTextCertificate(String hcvId) async {
    final directory = await HCVTextArtifactStore.outputDirectory();
    if (!await directory.exists()) return null;
    final normalizedId = hcvId.toUpperCase();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.hcv')) {
        continue;
      }
      if (!p.basename(entity.path).toUpperCase().contains(normalizedId)) {
        continue;
      }
      if (!await _verifier.verifyFile(entity.path)) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map<String, dynamic>) continue;
        final meta = decoded['meta'];
        final localId = meta is Map
            ? HCVTextIntegrity.extractHcvId(meta['hcvId']?.toString() ?? '')
            : null;
        if (localId == normalizedId) return entity;
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> _recoverLocalCertificate(String hcvId) async {
    final localFile = await _findLocalTextCertificate(hcvId);
    if (localFile == null) return null;
    final decoded = jsonDecode(await localFile.readAsString());
    if (decoded is! Map<String, dynamic>) return null;

    try {
      await _registry.uploadCertificateFile(localFile.path);
      _source = _label(
        'Dispositivo locale + Registry ripristinato',
        'Local device + Registry restored',
      );
    } catch (_) {
      try {
        await _registry.enqueueCertificateFile(localFile.path);
      } catch (_) {}
      _source = _label(
        'Copia firmata sul dispositivo; nuovo invio accodato',
        'Signed local copy; re-upload queued',
      );
    }
    return decoded;
  }

  Future<void> _applyCertificate({
    required Map<String, dynamic> certificate,
    required String published,
    required String source,
  }) async {
    final rawCertificate = jsonEncode(certificate);
    final signatureValid = await _verifyCertificateRaw(rawCertificate);
    if (!signatureValid) {
      if (!mounted) return;
      setState(() {
        _signatureValid = false;
        _status = _label(
          'Il certificato recuperato non supera la verifica crittografica.',
          'The retrieved certificate failed cryptographic verification.',
        );
        _source = source;
      });
      return;
    }
    final match = HCVTextIntegrity.comparePublishedText(
      publishedText: published,
      certificate: certificate,
    );
    if (!mounted) return;
    setState(() {
      _signatureValid = true;
      _match = match;
      _source = source;
      _status = _statusFor(match.kind);
    });
  }
""",
    'text local recovery helpers',
)

verify = replace_once(
    verify,
    """  Future<void> _verifyRegistryText() async {
    if (_busy) return;
""",
    """  Future<void> _verifyRegistryText() async {
    if (_busy) return;
    _dismissKeyboard();
""",
    'dismiss keyboard on Registry verification',
)

old_registry_block = """      final certificate = await _registry.fetchCertificate(id);
      final rawCertificate = jsonEncode(certificate);
      final signatureValid = await _verifyCertificateRaw(rawCertificate);
      if (!signatureValid) {
        setState(() {
          _signatureValid = false;
          _status = _label(
            'Il certificato recuperato non supera la verifica crittografica.',
            'The retrieved certificate failed cryptographic verification.',
          );
          _source = 'Registry';
        });
        return;
      }
      final match = HCVTextIntegrity.comparePublishedText(
        publishedText: published,
        certificate: certificate,
      );
      setState(() {
        _signatureValid = true;
        _match = match;
        _source = 'Registry';
        _status = _statusFor(match.kind);
      });
    } on HCVRegistryException catch (error) {
      setState(() {
        _status = error.kind == HCVRegistryFailureKind.notFound
            ? _label(
                'Certificato non presente nel Registry.',
                'Certificate is not present in the Registry.',
              )
            : '${_label('Registry non disponibile', 'Registry unavailable')}: ${error.message}';
        _source = 'Registry';
      });
"""
new_registry_block = """      final certificate = await _registry.fetchCertificate(id);
      await _applyCertificate(
        certificate: certificate,
        published: published,
        source: 'Registry',
      );
    } on HCVRegistryException catch (error) {
      if (error.kind == HCVRegistryFailureKind.notFound) {
        final localCertificate = await _recoverLocalCertificate(id);
        if (localCertificate != null) {
          await _applyCertificate(
            certificate: localCertificate,
            published: published,
            source: _source ?? _label('Copia locale firmata', 'Signed local copy'),
          );
          return;
        }
      }
      if (mounted) {
        setState(() {
          _status = error.kind == HCVRegistryFailureKind.notFound
              ? _label(
                  'Certificato non presente nel Registry e nessuna copia locale firmata trovata.',
                  'Certificate is not in the Registry and no signed local copy was found.',
                )
              : '${_label('Registry non disponibile', 'Registry unavailable')}: ${error.message}';
          _source = 'Registry';
        });
      }
"""
verify = replace_once(
    verify,
    old_registry_block,
    new_registry_block,
    'Registry 404 local recovery',
)

verify = replace_once(
    verify,
    """  Future<void> _verifyTextPackage() async {
    if (_busy) return;
""",
    """  Future<void> _verifyTextPackage() async {
    if (_busy) return;
    _dismissKeyboard();
""",
    'dismiss keyboard before file picker',
)

verify_path.write_text(verify, encoding='utf-8')


# ---------------------------------------------------------------------------
# Camera: do not alter analysis, evidence, signatures, claims, hashes or video.
# In PHOTO mode only, the first shutter press performs the existing probe and
# arms the shot. PROSEGUI returns to the live preview. The second shutter press
# takes the photo using the exact same signed pre-capture probe.
# ---------------------------------------------------------------------------
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text(encoding='utf-8')

camera = replace_once(
    camera,
    """  Map<String, dynamic>? pendingLiveScreenProbe;
  HCVCaptureLocation? pendingVideoLocation;
  HCVCaptureLocation? _lastCaptureLocation;
  DateTime? pendingVideoCapturedAt;
""",
    """  Map<String, dynamic>? pendingLiveScreenProbe;
  HCVCaptureLocation? pendingVideoLocation;
  HCVCaptureLocation? _lastCaptureLocation;
  DateTime? pendingVideoCapturedAt;
  Map<String, dynamic>? _armedPhotoScreenProbe;
  HCVCaptureLocation? _armedPhotoLocation;
  DateTime? _armedPhotoExpiresAt;
  int? _armedPhotoCameraIndex;
  double? _armedPhotoZoom;
""",
    'photo armed state',
)

camera = replace_once(
    camera,
    """  Future<void> takePhoto() async {
    if (controller == null) return;

    final captureLocation = await _locationForCapture();
    if (_printCoordinates && captureLocation == null) return;

    try {
      setState(() {
        status = _physicalProbeStatus;
      });

      final liveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
      await _showCaptureReadyMessage();
      await _settleCameraAfterLiveProbe();

      setState(() {
        status = 'SCATTO FOTO...';
      });
""",
    """  Future<void> takePhoto() async {
    if (controller == null) return;

    final now = DateTime.now();
    final armedProbe = _armedPhotoScreenProbe;
    final armedUntil = _armedPhotoExpiresAt;
    final armedIsValid = armedProbe != null &&
        armedUntil != null &&
        now.isBefore(armedUntil) &&
        _armedPhotoCameraIndex == selectedCameraIndex &&
        _armedPhotoZoom != null &&
        (currentZoom - _armedPhotoZoom!).abs() < 0.01;

    HCVCaptureLocation? captureLocation;
    if (armedIsValid) {
      captureLocation = _armedPhotoLocation;
    } else {
      _armedPhotoScreenProbe = null;
      _armedPhotoLocation = null;
      _armedPhotoExpiresAt = null;
      _armedPhotoCameraIndex = null;
      _armedPhotoZoom = null;
      captureLocation = await _locationForCapture();
      if (_printCoordinates && captureLocation == null) return;
    }

    try {
      late final Map<String, dynamic> liveScreenProbe;
      if (armedIsValid) {
        liveScreenProbe = armedProbe;
        _armedPhotoScreenProbe = null;
        _armedPhotoLocation = null;
        _armedPhotoExpiresAt = null;
        _armedPhotoCameraIndex = null;
        _armedPhotoZoom = null;
      } else {
        setState(() {
          status = _physicalProbeStatus;
        });
        liveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();
        _armedPhotoScreenProbe = liveScreenProbe;
        _armedPhotoLocation = captureLocation;
        _armedPhotoExpiresAt = DateTime.now().add(const Duration(seconds: 15));
        _armedPhotoCameraIndex = selectedCameraIndex;
        _armedPhotoZoom = currentZoom;
        await _showCaptureReadyMessage();
        if (!mounted) return;
        setState(() {
          status = widget.languageCode.toLowerCase().startsWith('it')
              ? 'INQUADRA E PREMI IL PULSANTE DI SCATTO'
              : 'COMPOSE AND PRESS THE SHUTTER BUTTON';
        });
        return;
      }

      await _settleCameraAfterLiveProbe();

      setState(() {
        status = 'SCATTO FOTO...';
      });
""",
    'photo two-step arming without chain changes',
)

camera_path.write_text(camera, encoding='utf-8')
print('Keyboard dismissal, text Registry recovery and photo-only shutter arming applied')
