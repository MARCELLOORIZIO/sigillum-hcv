from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    source = p.read_text(encoding='utf-8')
    if old not in source:
        raise RuntimeError(f'anchor missing in {path}: {old[:120]!r}')
    source = source.replace(old, new, 1)
    p.write_text(source, encoding='utf-8')


# ---------------------------------------------------------------------------
# Creator entitlement revalidation: keep the SIGILLUM session, but never let
# an expired Creator entitlement keep opening/using certification surfaces.
# ---------------------------------------------------------------------------

replace_once(
    'lib/commercial_gate.dart',
    """  void _onSessionInvalidated() {
    _resetLoggedOutState();
  }

  Future<void> _logout() async {
""",
    """  void _onSessionInvalidated() {
    _resetLoggedOutState();
  }

  Future<void> _onSubscriptionInactive() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = _t('subscriptionInactive');
    });
    await _prepareBilling();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _stage = _GateStage.billing;
      _message = _t('subscriptionInactive');
    });
  }

  Future<void> _logout() async {
""",
)
replace_once(
    'lib/commercial_gate.dart',
    "return UserHomePage(onSessionInvalidated: _onSessionInvalidated);",
    """return UserHomePage(
        onSessionInvalidated: _onSessionInvalidated,
        onSubscriptionInactive: _onSubscriptionInactive,
      );""",
)

replace_once(
    'lib/user_home_page.dart',
    "import 'camera_page.dart';\n",
    "import 'camera_page.dart';\nimport 'commercial_account_service.dart';\n",
)
replace_once(
    'lib/user_home_page.dart',
    """class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key, this.onSessionInvalidated});

  final VoidCallback? onSessionInvalidated;
""",
    """class UserHomePage extends StatefulWidget {
  const UserHomePage({
    super.key,
    this.onSessionInvalidated,
    this.onSubscriptionInactive,
  });

  final VoidCallback? onSessionInvalidated;
  final Future<void> Function()? onSubscriptionInactive;
""",
)
replace_once(
    'lib/user_home_page.dart',
    "class _UserHomePageState extends State<UserHomePage> {",
    "class _UserHomePageState extends State<UserHomePage> with WidgetsBindingObserver {",
)
replace_once(
    'lib/user_home_page.dart',
    """  bool _sharedOpenScheduled = false;
  String languageCode = SigillumCopy.initialLanguageCode();
""",
    """  bool _sharedOpenScheduled = false;
  bool _entitlementCheckInFlight = false;
  final CommercialAccountService _account = const CommercialAccountService();
  String languageCode = SigillumCopy.initialLanguageCode();
""",
)
replace_once(
    'lib/user_home_page.dart',
    """  void initState() {
    super.initState();
    _intentChannel.setMethodCallHandler(_handleNativeIntent);
""",
    """  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _intentChannel.setMethodCallHandler(_handleNativeIntent);
""",
)
replace_once(
    'lib/user_home_page.dart',
    """  Future<void> _retryRegistryOutbox() async {
    try {
      await const HCVRegistryService().retryPendingUploads();
    } catch (_) {
      // La coda resta disponibile per il tentativo successivo.
    }
  }

  Future<void> _loadLanguage() async {
""",
    """  Future<void> _retryRegistryOutbox() async {
    try {
      final report = await const HCVRegistryService().retryPendingUploads();
      if (report.subscriptionInactivePaths.isNotEmpty) {
        await widget.onSubscriptionInactive?.call();
      }
    } catch (_) {
      // La coda resta disponibile per il tentativo successivo.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.microtask(() => _revalidateCreatorEntitlement(showError: false));
    }
  }

  Future<bool> _revalidateCreatorEntitlement({required bool showError}) async {
    if (_entitlementCheckInFlight) return false;
    _entitlementCheckInFlight = true;
    try {
      final billing = await _account.billingStatus();
      final status = billing['status']?.toString() ?? '';
      if (status == 'active' || status == 'grace') return true;
      await widget.onSubscriptionInactive?.call();
      return false;
    } catch (_) {
      if (showError && mounted) {
        final message = languageCode.toLowerCase().startsWith('it')
            ? 'Impossibile verificare ora l’abbonamento. Controlla la connessione e riprova.'
            : 'Unable to verify the subscription now. Check your connection and try again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    } finally {
      _entitlementCheckInFlight = false;
    }
  }

  Future<void> _openCreatorFeature(Widget Function() builder) async {
    final active = await _revalidateCreatorEntitlement(showError: true);
    if (!active || !mounted) return;
    _open(builder());
  }

  Future<void> _loadLanguage() async {
""",
)
replace_once(
    'lib/user_home_page.dart',
    """                      onPressed: () =>
                          _open(CameraPage(languageCode: languageCode)),
""",
    """                      onPressed: () => _openCreatorFeature(
                        () => CameraPage(
                          languageCode: languageCode,
                          onSubscriptionInactive: widget.onSubscriptionInactive,
                        ),
                      ),
""",
)
replace_once(
    'lib/user_home_page.dart',
    """                      onPressed: () =>
                          _open(TextCertPage(languageCode: languageCode)),
""",
    """                      onPressed: () => _openCreatorFeature(
                        () => TextCertPage(
                          languageCode: languageCode,
                          onSubscriptionInactive: widget.onSubscriptionInactive,
                        ),
                      ),
""",
)
# Insert observer cleanup immediately before the first build method in this state.
replace_once(
    'lib/user_home_page.dart',
    """  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
""",
    """  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
""",
)

# ---------------------------------------------------------------------------
# Registry: make 402 a first-class subscription state. Keep certificates in the
# persistent outbox, but do not mislabel the condition as a transient network
# wait and do not hammer the server with bounded retries.
# ---------------------------------------------------------------------------
replace_once(
    'lib/hcv_registry_service.dart',
    """  server,
  invalidCertificate,
  invalidResponse,
""",
    """  server,
  subscriptionInactive,
  invalidCertificate,
  invalidResponse,
""",
)
replace_once(
    'lib/hcv_registry_service.dart',
    """    required this.discarded,
    required this.uploadedPaths,
  });

  final int attempted;
  final int uploaded;
  final int pending;
  final int discarded;
  final Set<String> uploadedPaths;
""",
    """    required this.discarded,
    required this.uploadedPaths,
    required this.subscriptionInactivePaths,
  });

  final int attempted;
  final int uploaded;
  final int pending;
  final int discarded;
  final Set<String> uploadedPaths;
  final Set<String> subscriptionInactivePaths;
""",
)
replace_once(
    'lib/hcv_registry_service.dart',
    """      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HCVRegistryException(
          res.statusCode >= 500
              ? HCVRegistryFailureKind.server
              : HCVRegistryFailureKind.invalidResponse,
          'Registry upload error ${res.statusCode}: $body',
          statusCode: res.statusCode,
        );
      }
""",
    """      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HCVRegistryException(
          res.statusCode == 402
              ? HCVRegistryFailureKind.subscriptionInactive
              : res.statusCode >= 500
                  ? HCVRegistryFailureKind.server
                  : HCVRegistryFailureKind.invalidResponse,
          'Registry upload error ${res.statusCode}: $body',
          statusCode: res.statusCode,
        );
      }
""",
)
replace_once(
    'lib/hcv_registry_service.dart',
    """    final remaining = <Map<String, dynamic>>[];
    final uploadedPaths = <String>{};
    var attempted = 0;
""",
    """    final remaining = <Map<String, dynamic>>[];
    final uploadedPaths = <String>{};
    final subscriptionInactivePaths = <String>{};
    var attempted = 0;
""",
)
replace_once(
    'lib/hcv_registry_service.dart',
    """        } on HCVRegistryException catch (e) {
          lastRegistryError = e;
          if (e.kind == HCVRegistryFailureKind.invalidCertificate) {
""",
    """        } on HCVRegistryException catch (e) {
          lastRegistryError = e;
          if (e.kind == HCVRegistryFailureKind.subscriptionInactive) {
            subscriptionInactivePaths.add(path);
          }
          if (e.kind == HCVRegistryFailureKind.invalidCertificate) {
""",
)
replace_once(
    'lib/hcv_registry_service.dart',
    """      discarded: discarded,
      uploadedPaths: uploadedPaths,
    );
""",
    """      discarded: discarded,
      uploadedPaths: uploadedPaths,
      subscriptionInactivePaths: subscriptionInactivePaths,
    );
""",
)

# ---------------------------------------------------------------------------
# Camera: verify Creator entitlement at the actual capture boundary as well as
# at navigation time; route 402 Registry rejection back to the billing gate.
# ---------------------------------------------------------------------------
replace_once(
    'lib/camera_page.dart',
    "import 'hcv_engine.dart';\n",
    "import 'hcv_engine.dart';\nimport 'commercial_account_service.dart';\n",
)
replace_once(
    'lib/camera_page.dart',
    """  const CameraPage({
    super.key,
    this.initialPhotoMode = false,
    this.languageCode = 'it',
  });

  final bool initialPhotoMode;
  final String languageCode;
""",
    """  const CameraPage({
    super.key,
    this.initialPhotoMode = false,
    this.languageCode = 'it',
    this.onSubscriptionInactive,
  });

  final bool initialPhotoMode;
  final String languageCode;
  final Future<void> Function()? onSubscriptionInactive;
""",
)
replace_once(
    'lib/camera_page.dart',
    """  final verifier = HCVVerifier();
  final registry = const HCVRegistryService();
""",
    """  final verifier = HCVVerifier();
  final registry = const HCVRegistryService();
  final CommercialAccountService _account = const CommercialAccountService();
  bool _entitlementCheckInFlight = false;
  DateTime? _lastEntitlementCheckAt;
""",
)
replace_once(
    'lib/camera_page.dart',
    """  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  String _c(String key) => CameraUiExtendedCopy.t(widget.languageCode, key);

  Future<void> _toggleCoordinateStamp() async {
""",
    """  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  String _c(String key) => CameraUiExtendedCopy.t(widget.languageCode, key);

  Future<void> _handleSubscriptionInactive() async {
    if (mounted) {
      setState(() => registryStatus = _c('registrySubscriptionInactive'));
    }
    final callback = widget.onSubscriptionInactive;
    if (callback == null) return;
    await callback();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _ensureCreatorEntitlement() async {
    final lastCheck = _lastEntitlementCheckAt;
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck) < const Duration(minutes: 1)) {
      return true;
    }
    if (_entitlementCheckInFlight) return false;
    _entitlementCheckInFlight = true;
    try {
      final billing = await _account.billingStatus();
      final status = billing['status']?.toString() ?? '';
      if (status == 'active' || status == 'grace') {
        _lastEntitlementCheckAt = DateTime.now();
        return true;
      }
      await _handleSubscriptionInactive();
      return false;
    } catch (_) {
      if (mounted) {
        _showLocationMessage(_c('subscriptionCheckFailed'));
      }
      return false;
    } finally {
      _entitlementCheckInFlight = false;
    }
  }

  Future<void> _toggleCoordinateStamp() async {
""",
)
replace_once(
    'lib/camera_page.dart',
    """  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final captureLocation = await _locationForCapture();
""",
    """  Future<void> start() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;
    if (!await _ensureCreatorEntitlement()) return;

    final captureLocation = await _locationForCapture();
""",
)
replace_once(
    'lib/camera_page.dart',
    """  Future<void> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;

    final captureLocation = await _locationForCapture();
""",
    """  Future<void> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isRecordingVideo) return;
    if (!await _ensureCreatorEntitlement()) return;

    final captureLocation = await _locationForCapture();
""",
)
replace_once(
    'lib/camera_page.dart',
    """      final report = await registry.retryPendingUploads();
      final currentUploaded = report.uploadedPaths.contains(currentPath);
      setState(() {
        registryStatus = currentUploaded
            ? '${_c('registryOk')}: ${hcvId ?? _c('certificatePublished')}'
            : _c('registryPending');
      });
""",
    """      final report = await registry.retryPendingUploads();
      if (report.subscriptionInactivePaths.contains(currentPath)) {
        await _handleSubscriptionInactive();
        return;
      }
      final currentUploaded = report.uploadedPaths.contains(currentPath);
      if (!mounted) return;
      setState(() {
        registryStatus = currentUploaded
            ? '${_c('registryOk')}: ${hcvId ?? _c('certificatePublished')}'
            : _c('registryPending');
      });
""",
)
replace_once(
    'lib/camera_page.dart',
    """      final report = await registry.retryPendingUploads();
      if (!mounted || report.uploaded == 0) return;
      setState(() {
""",
    """      final report = await registry.retryPendingUploads();
      if (report.subscriptionInactivePaths.isNotEmpty) {
        await _handleSubscriptionInactive();
        return;
      }
      if (!mounted || report.uploaded == 0) return;
      setState(() {
""",
)

# ---------------------------------------------------------------------------
# Reflective/flat planar surfaces: ML remains a strong signal, but a flat,
# low-micro-variation scene cannot become STRONG solely from an ambiguous ML
# screen label. Independent optical/temporal evidence or a stringent ML
# spatial/multi-frame signature preserves true displays.
# ---------------------------------------------------------------------------
reflective_helpers = r'''
Iterable<Map<String, dynamic>> _walkDisplayEvidence(dynamic value) sync* {
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    yield map;
    for (final child in map.values) {
      yield* _walkDisplayEvidence(child);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* _walkDisplayEvidence(child);
    }
  }
}

bool _hasIndependentPhysicalDisplayEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  for (final root in analyses.whereType<Map<String, dynamic>>()) {
    for (final node in _walkDisplayEvidence(root)) {
      final rawSignals = node['signals'];
      if (rawSignals is! Map) continue;
      final signals = Map<String, dynamic>.from(rawSignals);
      if (signals['confirmedDisplayTrace'] == true ||
          signals['periodicLightTrace'] == true ||
          signals['opticalCorroboratedTrace'] == true ||
          signals['structuralDisplayTrace'] == true ||
          signals['strongDisplayTrace'] == true ||
          signals['localRefreshFlicker'] == true ||
          signals['horizontalRefreshBands'] == true ||
          signals['displayBandTrace'] == true ||
          signals['activeIlluminationDisplayEvidence'] == true) {
        return true;
      }
    }
  }
  return false;
}

bool _hasStringentMlDisplayEvidence(
  List<Map<String, dynamic>?> analyses,
) {
  for (final root in analyses.whereType<Map<String, dynamic>>()) {
    for (final node in _walkDisplayEvidence(root)) {
      if (node['type'] != 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1') continue;
      final frames = (node['framesAnalyzed'] as num?)?.toInt() ?? 0;
      if (frames <= 1) {
        if (HCVDisplayRiskFusion.hasSpatialScreenCorroboration(node)) {
          return true;
        }
      } else if (HCVDisplayRiskFusion.hasMultiFrameScreenConsistency(node) ||
          HCVDisplayRiskFusion.hasPersistentSemanticScreenAcrossVideoFrames(
            node,
          )) {
        return true;
      }
    }
  }
  return false;
}

bool _hasFlatLowVariationAmbiguity(
  List<Map<String, dynamic>?> analyses,
) {
  var flat = false;
  var lowVariation = false;
  for (final root in analyses.whereType<Map<String, dynamic>>()) {
    for (final node in _walkDisplayEvidence(root)) {
      final rawSignals = node['signals'];
      if (rawSignals is! Map) continue;
      final signals = Map<String, dynamic>.from(rawSignals);
      flat = flat || signals['flatSceneUniformity'] == true;
      lowVariation = lowVariation || signals['lowMicroVariation'] == true;
    }
  }
  return flat && lowVariation;
}

HCVDisplayRiskResult _guardReflectivePlanarStrongResult(
  HCVDisplayRiskResult result,
  List<Map<String, dynamic>?> analyses,
) {
  if (result.decision != 'STRONG_DISPLAY_RISK' ||
      !_hasFlatLowVariationAmbiguity(analyses)) {
    return result;
  }
  if (_hasIndependentPhysicalDisplayEvidence(analyses) ||
      _hasStringentMlDisplayEvidence(analyses)) {
    return result;
  }

  final evidenceSources = <String>{...result.evidenceSources}.toList()..sort();
  final reasons = <String>{
    ...result.reasons,
    'FLAT_REFLECTIVE_SCREEN_LIKE_CONTENT_WITHOUT_STRONG_DISPLAY_CORROBORATION',
  }.toList();
  return HCVDisplayRiskResult(
    risk: 'MEDIUM',
    score: result.score.clamp(40, 69).toInt(),
    decision: 'NON_CONCLUSIVE',
    analysisStatus: result.analysisStatus,
    evidenceSources: evidenceSources,
    strongSources: const [],
    reasons: reasons,
  );
}

'''
replace_once(
    'lib/camera_page.dart',
    "bool _hasLiveTemporalScreenCorroboration(Map<String, dynamic>? live) {",
    reflective_helpers + "bool _hasLiveTemporalScreenCorroboration(Map<String, dynamic>? live) {",
)
replace_once(
    'lib/camera_page.dart',
    """  if (isTemporalV2 && legacy.decision == 'STRONG_DISPLAY_RISK') {
    return legacy;
  }

  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
  }
  return legacy;
""",
    """  if (isTemporalV2 && legacy.decision == 'STRONG_DISPLAY_RISK') {
    return _guardReflectivePlanarStrongResult(legacy, analyses);
  }

  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    final merged = _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
    return _guardReflectivePlanarStrongResult(merged, analyses);
  }
  return _guardReflectivePlanarStrongResult(legacy, analyses);
""",
)
replace_once(
    'lib/camera_page.dart',
    """  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    return _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
  }
  return legacy;
}

HCVDisplayRiskResult _combineVideoDisplayRiskLegacy(
""",
    """  if (mlFirst != null &&
      (mlFirst.decision == 'STRONG_DISPLAY_RISK' ||
          !_hasHardDisplayCorroboration(analyses))) {
    final merged = _mergeMlPrimaryWithDiagnostics(mlFirst, legacy);
    return _guardReflectivePlanarStrongResult(merged, analyses);
  }
  return _guardReflectivePlanarStrongResult(legacy, analyses);
}

HCVDisplayRiskResult _combineVideoDisplayRiskLegacy(
""",
)

# ---------------------------------------------------------------------------
# Text certification: revalidate at creation time and distinguish 402 Registry
# rejection from connectivity. Preserve the local certificate/outbox.
# ---------------------------------------------------------------------------
replace_once(
    'lib/text_cert_page.dart',
    "import 'hcv_engine.dart';\n",
    "import 'hcv_engine.dart';\nimport 'commercial_account_service.dart';\n",
)
replace_once(
    'lib/text_cert_page.dart',
    """class TextCertPage extends StatefulWidget {
  const TextCertPage({super.key, this.languageCode = 'it'});

  final String languageCode;
""",
    """class TextCertPage extends StatefulWidget {
  const TextCertPage({
    super.key,
    this.languageCode = 'it',
    this.onSubscriptionInactive,
  });

  final String languageCode;
  final Future<void> Function()? onSubscriptionInactive;
""",
)
replace_once(
    'lib/text_cert_page.dart',
    """  final verifier = HCVVerifier();
  final registry = const HCVRegistryService();
""",
    """  final verifier = HCVVerifier();
  final registry = const HCVRegistryService();
  final CommercialAccountService _account = const CommercialAccountService();
""",
)
replace_once(
    'lib/text_cert_page.dart',
    """    Future.microtask(() async {
      try {
        await registry.retryPendingUploads();
      } catch (_) {}
    });
""",
    """    Future.microtask(() async {
      try {
        final report = await registry.retryPendingUploads();
        if (report.subscriptionInactivePaths.isNotEmpty) {
          await _routeToSubscription();
        }
      } catch (_) {}
    });
""",
)
replace_once(
    'lib/text_cert_page.dart',
    """  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  Future<Directory> _outputDirectory() async {
""",
    """  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  String get _subscriptionInactiveMessage =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'Abbonamento non attivo — rinnova per pubblicare nel Registry.'
          : 'Subscription inactive — renew to publish to the Registry.';

  String get _subscriptionCheckFailedMessage =>
      widget.languageCode.toLowerCase().startsWith('it')
          ? 'Impossibile verificare ora l’abbonamento. Controlla la connessione e riprova.'
          : 'Unable to verify the subscription now. Check your connection and try again.';

  Future<void> _routeToSubscription() async {
    if (mounted) setState(() => registryStatus = _subscriptionInactiveMessage);
    final callback = widget.onSubscriptionInactive;
    if (callback == null) return;
    await callback();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _ensureCreatorEntitlement() async {
    try {
      final billing = await _account.billingStatus();
      final status = billing['status']?.toString() ?? '';
      if (status == 'active' || status == 'grace') return true;
      await _routeToSubscription();
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_subscriptionCheckFailedMessage)),
        );
      }
      return false;
    }
  }

  Future<Directory> _outputDirectory() async {
""",
)
replace_once(
    'lib/text_cert_page.dart',
    """  Future<void> createTextCertificate() async {
    _dismissKeyboard();
    final text = controller.text.trim();
""",
    """  Future<void> createTextCertificate() async {
    _dismissKeyboard();
    if (!await _ensureCreatorEntitlement()) return;
    final text = controller.text.trim();
""",
)
replace_once(
    'lib/text_cert_page.dart',
    """        } catch (e) {
          try {
            await registry.enqueueCertificateFile(finalHcvPath);
          } catch (_) {}
          if (mounted) {
            setState(() {
              registryStatus = 'Registry non disponibile: certificato conservato e accodato per il nuovo invio.';
            });
          }
        }
""",
    """        } on HCVRegistryException catch (e) {
          try {
            await registry.enqueueCertificateFile(finalHcvPath);
          } catch (_) {}
          if (e.kind == HCVRegistryFailureKind.subscriptionInactive) {
            await _routeToSubscription();
          } else if (mounted) {
            setState(() {
              registryStatus = 'Registry non disponibile: certificato conservato e accodato per il nuovo invio.';
            });
          }
        } catch (_) {
          try {
            await registry.enqueueCertificateFile(finalHcvPath);
          } catch (_) {}
          if (mounted) {
            setState(() {
              registryStatus = 'Registry non disponibile: certificato conservato e accodato per il nuovo invio.';
            });
          }
        }
""",
)

# Localized camera copy for subscription-specific failures.
for code, anchor, additions in [
    ('it', "      'registryWaiting': 'in attesa',\n", "      'registryWaiting': 'in attesa',\n      'registrySubscriptionInactive':\n          'Abbonamento non attivo — rinnova per pubblicare nel Registry',\n      'subscriptionCheckFailed':\n          'Impossibile verificare ora l’abbonamento. Controlla la connessione e riprova.',\n"),
    ('en', "      'registryWaiting': 'pending',\n", "      'registryWaiting': 'pending',\n      'registrySubscriptionInactive':\n          'Subscription inactive — renew to publish to the Registry',\n      'subscriptionCheckFailed':\n          'Unable to verify the subscription now. Check your connection and try again.',\n"),
    ('es', "      'registryWaiting': 'pendientes',\n", "      'registryWaiting': 'pendientes',\n      'registrySubscriptionInactive':\n          'Suscripción inactiva — renueva para publicar en el Registry',\n      'subscriptionCheckFailed':\n          'No se puede verificar ahora la suscripción. Comprueba la conexión e inténtalo de nuevo.',\n"),
    ('ru', "      'registryWaiting': 'ожидает',\n", "      'registryWaiting': 'ожидает',\n      'registrySubscriptionInactive':\n          'Подписка неактивна — продлите её для публикации в Registry',\n      'subscriptionCheckFailed':\n          'Не удалось проверить подписку. Проверьте соединение и повторите попытку.',\n"),
]:
    replace_once('lib/camera_ui_copy.dart', anchor, additions)

# ---------------------------------------------------------------------------
# Regression contracts.
# ---------------------------------------------------------------------------
Path('test/creator_entitlement_revalidation_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Creator home revalidates on resume and before certification routes', () {
    final source = File('lib/user_home_page.dart').readAsStringSync();
    expect(source, contains('with WidgetsBindingObserver'));
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('await _account.billingStatus()'));
    expect(source, contains('_openCreatorFeature('));
    expect(source, contains('CameraPage('));
    expect(source, contains('TextCertPage('));
    expect(source, contains('onSubscriptionInactive: widget.onSubscriptionInactive'));
  });

  test('subscription expiry returns to billing without logging the account out', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final start = gate.indexOf('Future<void> _onSubscriptionInactive() async');
    final end = gate.indexOf('Future<void> _logout() async', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final section = gate.substring(start, end);
    expect(section, contains('_stage = _GateStage.billing'));
    expect(section, contains('await _prepareBilling()'));
    expect(section, isNot(contains('.logout()')));
    expect(section, isNot(contains('_resetLoggedOutState()')));
  });

  test('camera checks entitlement at photo and video capture boundaries', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final startVideo = camera.indexOf('Future<void> start() async');
    final stopVideo = camera.indexOf('Future<void> stop() async', startVideo);
    final photo = camera.indexOf('Future<void> takePhoto() async');
    expect(camera.substring(startVideo, stopVideo),
        contains('if (!await _ensureCreatorEntitlement()) return;'));
    expect(camera.substring(photo),
        contains('if (!await _ensureCreatorEntitlement()) return;'));
  });

  test('text certification checks entitlement at creation boundary', () {
    final text = File('lib/text_cert_page.dart').readAsStringSync();
    final create = text.indexOf('Future<void> createTextCertificate() async');
    expect(create, greaterThanOrEqualTo(0));
    expect(text.substring(create),
        contains('if (!await _ensureCreatorEntitlement()) return;'));
  });
}
''', encoding='utf-8')

Path('test/registry_subscription_expiry_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Registry 402 is a non-retryable subscription state retained in outbox', () {
    final source = File('lib/hcv_registry_service.dart').readAsStringSync();
    expect(source, contains('subscriptionInactive,'));
    expect(source, contains('res.statusCode == 402'));
    expect(source, contains('HCVRegistryFailureKind.subscriptionInactive'));
    expect(source, contains('subscriptionInactivePaths.add(path)'));
    expect(source, contains('subscriptionInactivePaths: subscriptionInactivePaths'));

    final retryGetter = source.substring(
      source.indexOf('bool get isRetryable'),
      source.indexOf('@override', source.indexOf('bool get isRetryable')),
    );
    expect(retryGetter, isNot(contains('subscriptionInactive')));
  });

  test('camera and text route subscription Registry rejection to billing', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final text = File('lib/text_cert_page.dart').readAsStringSync();
    expect(camera, contains('report.subscriptionInactivePaths.contains(currentPath)'));
    expect(camera, contains('await _handleSubscriptionInactive()'));
    expect(text, contains('HCVRegistryFailureKind.subscriptionInactive'));
    expect(text, contains('await _routeToSubscription()'));
  });
}
''', encoding='utf-8')

Path('test/reflective_planar_surface_regression_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:hcv_app/camera_page.dart';

Map<String, dynamic> mlPhoto({
  required double probability,
  required double confidence,
  required int score,
  required int full,
  required int content,
}) =>
    {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'predictedClassConfidence': confidence,
      'screenReplayRiskScore': score,
      'framesAnalyzed': 1,
      'signals': {
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
        'flatSceneUniformity': true,
        'lowMicroVariation': true,
      },
    };

Map<String, dynamic> optical({bool physical = false}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'COMPLETE',
      'screenReplayRiskScore': physical ? 70 : 0,
      'signals': {
        'flatSceneUniformity': true,
        'lowMicroVariation': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'opticalCorroboratedTrace': false,
        'structuralDisplayTrace': physical,
        'strongDisplayTrace': false,
        'localRefreshFlicker': physical,
        'horizontalRefreshBands': false,
      },
    };

Map<String, dynamic> mlVideo({
  required double probability,
  required double confidence,
  required int score,
  required int medium,
  required int strong,
  required double average,
  required int maxFrame,
  required int full,
  required int content,
  required int frames,
}) =>
    {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'predictedClassConfidence': confidence,
      'screenReplayRiskScore': score,
      'framesAnalyzed': frames,
      'mediumScreenFrameCount': medium,
      'strongScreenFrameCount': strong,
      'averageScreenReplayRiskScore': average,
      'maxFrameScreenReplayRiskScore': maxFrame,
      'signals': {
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
        'flatSceneUniformity': true,
        'lowMicroVariation': true,
      },
      'videoFrameAnalyses': List.generate(
        frames,
        (_) => {'predictedClass': 'SCREEN_MONITOR'},
      ),
    };

void main() {
  test('framed reflective artwork is no longer strong from ML alone', () {
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
      mlPhoto(
        probability: 0.8519,
        confidence: 0.7745,
        score: 85,
        full: 85,
        content: 85,
      ),
      optical(),
    ]);
    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.risk, 'MEDIUM');
    expect(result.reasons,
        contains('FLAT_REFLECTIVE_SCREEN_LIKE_CONTENT_WITHOUT_STRONG_DISPLAY_CORROBORATION'));
  });

  test('reflective artwork video is no longer strong from weak persistence', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      mlVideo(
        probability: 0.9551,
        confidence: 0.9421,
        score: 96,
        medium: 1,
        strong: 1,
        average: 84.67,
        maxFrame: 96,
        full: 96,
        content: 95,
        frames: 3,
      ),
      optical(),
    ]);
    expect(result.decision, 'NON_CONCLUSIVE');
  });

  test('true monitor photo remains strong with physical corroboration', () {
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
      mlPhoto(
        probability: 0.9845,
        confidence: 0.9742,
        score: 97,
        full: 98,
        content: 98,
      ),
      optical(physical: true),
    ]);
    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });

  test('true monitor video remains strong with stringent multi-frame ML', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      mlVideo(
        probability: 0.9937,
        confidence: 0.9906,
        score: 99,
        medium: 3,
        strong: 3,
        average: 98.67,
        maxFrame: 99,
        full: 99,
        content: 99,
        frames: 3,
      ),
      optical(),
    ]);
    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });
}
''', encoding='utf-8')

print('Creator entitlement, Registry 402 and reflective planar guards applied')
