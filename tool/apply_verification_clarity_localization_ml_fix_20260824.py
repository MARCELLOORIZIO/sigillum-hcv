from pathlib import Path
import re


def require(path: Path, token: str, label: str) -> None:
    if token not in path.read_text(encoding='utf-8'):
        raise RuntimeError(f'{label}: missing {token}')


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    if old not in source:
        raise RuntimeError(f'{label}: anchor missing')
    return source.replace(old, new, 1)


# ---------------------------------------------------------------------------
# 1) Verification hub: never reintroduce the obsolete long button label.
# ---------------------------------------------------------------------------
import_path = Path('lib/import_page.dart')
source = import_path.read_text(encoding='utf-8')
source = source.replace("'VERIFICA TESTO / DOCUMENTO'", "'VERIFICA TESTO'")
source = source.replace("'VERIFY TEXT / DOCUMENT'", "'VERIFY TEXT'")
import_path.write_text(source, encoding='utf-8')


# ---------------------------------------------------------------------------
# 2) Quick media gate: use the selected IT/EN/ES/RU language, not IT/EN only.
# ---------------------------------------------------------------------------
quick_path = Path('lib/quick_hcv_media_gate_page.dart')
quick = quick_path.read_text(encoding='utf-8')
if "import 'verification_ui_copy.dart';" not in quick:
    quick = replace_once(
        quick,
        "import 'sigillum_theme.dart';\n",
        "import 'sigillum_theme.dart';\nimport 'verification_ui_copy.dart';\n",
        'quick copy import',
    )
quick = quick.replace("  bool get _isItalian => widget.languageCode == 'it';\n", "  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);\n")
quick = quick.replace("  String _status = 'Controllo rapido SIGILLUM...';", "  String _status = '';" )
quick = quick.replace("    WidgetsBinding.instance.addPostFrameCallback((_) {", "    _status = _v('fastCheck');\n    WidgetsBinding.instance.addPostFrameCallback((_) {")
quick = re.sub(
    r"_status = _isItalian\s*\? 'Contenuto non certificato SIGILLUM'\s*:\s*'Content not certified by SIGILLUM';",
    "_status = _v('notCertified');",
    quick,
)
quick = re.sub(
    r"_status = _isItalian\s*\? 'HCV-ID rilevato\. Verifica certificato in corso\.\.\.'\s*:\s*'HCV-ID detected\. Verifying certificate\.\.\.';",
    "_status = _v('idDetected');",
    quick,
)
quick = quick.replace("_isItalian ? 'Verifica contenuto' : 'Verify content'", "_v('verifyTitle')")
quick = re.sub(
    r"_checking\s*\? \(_isItalian\s*\? 'Cerco subito il marchio HCV e il codice\. Se non sono presenti, il controllo si ferma qui\.'\s*:\s*'Checking immediately for the HCV mark and code\. If absent, verification stops here\.'\)\s*:\s*\(_isItalian\s*\? 'Non è stato rilevato un HCV-ID valido nel contenuto selezionato\.'\s*:\s*'No valid HCV-ID was detected in the selected content\.'\)",
    "_checking ? _v('fastHelp') : _v('noId')",
    quick,
)
quick = re.sub(
    r"_isItalian\s*\? 'TORNA ALLA VERIFICA'\s*:\s*'BACK TO VERIFY'",
    "_v('backVerify')",
    quick,
)
quick_path.write_text(quick, encoding='utf-8')


# ---------------------------------------------------------------------------
# 3) Router title follows the selected language.
# ---------------------------------------------------------------------------
router_path = Path('lib/hcv_import_router_page.dart')
router = router_path.read_text(encoding='utf-8')
if "import 'verification_ui_copy.dart';" not in router:
    router = replace_once(
        router,
        "import 'sigillum_localization.dart';\n",
        "import 'sigillum_localization.dart';\nimport 'verification_ui_copy.dart';\n",
        'router copy import',
    )
if "String _v(String key)" not in router:
    router = replace_once(
        router,
        "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n",
        "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);\n",
        'router copy helper',
    )
router = router.replace('title: const Text("HCV Import"),', "title: Text(_v('routerTitle')),")
router_path.write_text(router, encoding='utf-8')


# ---------------------------------------------------------------------------
# 4) Registry result: concise public UI, translated axes, reality normalization,
#    and technical diagnostics collapsed behind a disclosure control.
# ---------------------------------------------------------------------------
registry_path = Path('lib/registry_verify_page.dart')
registry = registry_path.read_text(encoding='utf-8')
if "import 'verification_ui_copy.dart';" not in registry:
    anchor = "import 'sigillum_theme.dart';\n" if "import 'sigillum_theme.dart';\n" in registry else "import 'sigillum_localization.dart';\n"
    registry = replace_once(
        registry,
        anchor,
        anchor + "import 'verification_ui_copy.dart';\n",
        'registry copy import',
    )
if "String _v(String key)" not in registry:
    registry = replace_once(
        registry,
        "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n",
        "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);\n",
        'registry copy helper',
    )

# Set the initial visible status in the selected language.
registry = registry.replace(
    "    final path = widget.initialMediaPath;\n",
    "    status = _v('verificationIncomplete');\n    final path = widget.initialMediaPath;\n",
    1,
)

# Add presentation helpers immediately before build(). These helpers do not
# alter certificate contents; they only explain signed evidence to the user.
helper_marker = "  String _verificationAxisSubtitle(String axis)"
if helper_marker not in registry:
    build_anchor = "  @override\n  Widget build(BuildContext context) {\n"
    helpers = r'''  bool get _signedRealityScene {
    final cert = certificate;
    final claims = cert?['claims'];
    final live = claims is Map ? claims['liveScreenProbe'] : null;
    if (live is! Map) return false;
    final reason = live['reason']?.toString() ?? '';
    return live['sceneClass'] == 'REALITY' &&
        live['displayRiskDecision'] == 'NO_DISPLAY_EVIDENCE' &&
        (reason.contains('MULTI_DEPTH_PARALLAX_DETECTED') ||
            reason.contains('GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS'));
  }

  String _verificationAxisSubtitle(String axis) {
    switch (axis) {
      case 'provenance': return _v('provenanceHint');
      case 'integrity': return _v('integrityHint');
      case 'scene': return _v('sceneHint');
      case 'derivation': return _v('derivationHint');
      default: return '';
    }
  }

  String _localizedAxisState(String axis, String? raw) {
    final value = (raw ?? '').toLowerCase();
    if (axis == 'scene' && _signedRealityScene) return _v('realityDetected');
    if (axis == 'provenance' && value.contains('verificat')) return _v('verified');
    if (axis == 'integrity' && value.contains('originale') && value.contains('integro')) return _v('originalIntact');
    if (axis == 'integrity' && value.contains('derivato')) return _v('compatibleDerivative');
    if (axis == 'scene' && (value.contains('forte rischio') || value.contains('display'))) return _v('screenRisk');
    if (axis == 'scene' && value.contains('conclusiva')) return _v('sceneUncertain');
    if (axis == 'scene' && value.contains('nessun')) return _v('noScreenEvidence');
    if (axis == 'derivation' && value.contains('non necessaria')) return _v('derivationNotNeeded');
    if (axis == 'derivation' && value.contains('compatibile')) return _v('compatible');
    if (value.contains('non verificata')) return _v('notVerified');
    if (value.contains('non determinata')) return _v('notDetermined');
    if (value.contains('non analizzata')) return _v('notAnalyzed');
    return raw ?? '-';
  }

  String _localizedAxisDetail(String axis) {
    if (axis == 'scene' && _signedRealityScene) return _v('realityDetail');
    if (axis == 'provenance') return _v('provenanceOkDetail');
    if (axis == 'integrity') return _isForensicResult ? _v('originalDetail') : _v('derivedDetail');
    if (axis == 'scene') {
      if (_isStrongDisplayRisk) return _v('screenDetail');
      if (_isDisplayNonConclusive) return _v('uncertainDetail');
      return _v('noScreenDetail');
    }
    if (axis == 'derivation') return _isForensicResult ? _v('originalDerivationDetail') : _v('derivedDerivationDetail');
    return '-';
  }

  String get _publicResultTitle {
    if (_isForensicResult) return _v('forensicOk');
    if (_isSocialResult) return _v('socialOk');
    if ((result ?? '').contains('REGISTRY NOT FOUND')) return _v('registryNotFound');
    if ((result ?? '').contains('REGISTRY UNAVAILABLE')) return _v('registryUnavailable');
    return _v('verificationIncomplete');
  }

  String get _publicResultDetail {
    if (_isForensicResult) return _v('forensicOkDetail');
    if (_isSocialResult) return _v('socialOkDetail');
    return status;
  }

'''
    if build_anchor not in registry:
        raise RuntimeError('registry build anchor missing')
    registry = registry.replace(build_anchor, helpers + build_anchor, 1)

# Result status is public/localized rather than raw Italian internal status.
registry = registry.replace(
    "              Text(\n                status,\n                textAlign: TextAlign.center,\n              ),",
    "              Text(\n                _publicResultDetail,\n                textAlign: TextAlign.center,\n                style: const TextStyle(color: SigillumTheme.ink, fontSize: 16, height: 1.35),\n              ),",
    1,
)

# Localized action labels.
registry = registry.replace("child: Text(_t('selectOriginalMedia'))", "child: Text(_v('selectOriginal'))")
registry = registry.replace("loading ? _t('verifyingShort') : _t('verifyFromRegistry')", "loading ? _v('verifying') : _v('verifyRegistry')")

# Localized axis titles, hints, states and details.
axis_replacements = {
    "title: 'Provenienza',\n                  value: _effectiveProvenanceState,\n                  detail: _effectiveProvenanceDetail,": "title: _v('provenance'),\n                  subtitle: _verificationAxisSubtitle('provenance'),\n                  value: _localizedAxisState('provenance', _effectiveProvenanceState),\n                  detail: _localizedAxisDetail('provenance'),",
    "title: 'Integrita',\n                  value: _effectiveIntegrityState,\n                  detail: _effectiveIntegrityDetail,": "title: _v('integrity'),\n                  subtitle: _verificationAxisSubtitle('integrity'),\n                  value: _localizedAxisState('integrity', _effectiveIntegrityState),\n                  detail: _localizedAxisDetail('integrity'),",
    "title: 'Scena',\n                  value: _effectiveSceneState,\n                  detail: _effectiveSceneDetail,": "title: _v('scene'),\n                  subtitle: _verificationAxisSubtitle('scene'),\n                  value: _localizedAxisState('scene', _effectiveSceneState),\n                  detail: _localizedAxisDetail('scene'),",
    "title: 'Derivazione',\n                    value: _effectiveDerivationState!,\n                    detail: _effectiveDerivationDetail,": "title: _v('derivation'),\n                    subtitle: _verificationAxisSubtitle('derivation'),\n                    value: _localizedAxisState('derivation', _effectiveDerivationState),\n                    detail: _localizedAxisDetail('derivation'),",
}
for old, new in axis_replacements.items():
    if old in registry:
        registry = registry.replace(old, new, 1)

# Result headline should be understandable, not an internal enum.
registry = registry.replace("                  result!,", "                  _publicResultTitle,")

# Add subtitle to the card component.
registry = registry.replace(
    "    required this.title,\n    required this.value,",
    "    required this.title,\n    required this.subtitle,\n    required this.value,",
    1,
)
registry = registry.replace(
    "  final String title;\n  final String value;",
    "  final String title;\n  final String subtitle;\n  final String value;",
    1,
)
registry = registry.replace(
    "                const SizedBox(height: 3),\n                Text(\n                  value,",
    "                const SizedBox(height: 2),\n                Text(\n                  subtitle,\n                  style: const TextStyle(color: SigillumTheme.muted, fontSize: 12, fontWeight: FontWeight.w600),\n                ),\n                const SizedBox(height: 6),\n                Text(\n                  value,",
    1,
)

# Force light public cards even if an older build-time patch restored the dark shell.
registry = re.sub(
    r"decoration: BoxDecoration\(\s*color: (?:const Color\(0xFF111A17\)|SigillumTheme\.panel|Colors\.white),\s*borderRadius: BorderRadius\.circular\((?:8|20|28)\),\s*border: Border\.all\([^\n]+\),(?:\s*boxShadow: const \[[\s\S]*?\],)?\s*\),",
    "decoration: BoxDecoration(\n        color: Colors.white.withValues(alpha: 0.96),\n        borderRadius: BorderRadius.circular(26),\n        border: Border.all(color: SigillumTheme.border),\n        boxShadow: const [BoxShadow(color: Color(0x12280D5F), blurRadius: 18, offset: Offset(0, 7))],\n      ),",
    registry,
    count=1,
)

# Hide the giant diagnostics dump behind a collapsed disclosure control.
tech_start = "              if (hcvTrustLevel != null ||\n"
if tech_start in registry and "title: Text(_v('technicalDetails'))" not in registry:
    start = registry.index(tech_start)
    # The diagnostics block ends immediately before the closing children list.
    end_token = "              ],\n            ],\n          ),\n"
    end = registry.find(end_token, start)
    if end != -1:
        block = registry[start:end]
        indented = '\n'.join('                    ' + line[14:] if line.startswith('              ') else '                    ' + line for line in block.splitlines())
        replacement = "              if (hcvTrustLevel != null || liveCaptureTrust != null || screenReplayRisk != null) ...[\n                const SizedBox(height: 14),\n                ExpansionTile(\n                  title: Text(_v('technicalDetails'), style: const TextStyle(color: SigillumTheme.ink, fontWeight: FontWeight.w800)),\n                  childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 14),\n                  children: [\n" + indented + "\n                  ],\n                ),\n              ],\n"
        registry = registry[:start] + replacement + registry[end:]

registry_path.write_text(registry, encoding='utf-8')


# ---------------------------------------------------------------------------
# 5) HCVPACK: localize the most visible internal states for all four languages.
# ---------------------------------------------------------------------------
pack_path = Path('lib/hcvpack_player_page.dart')
pack = pack_path.read_text(encoding='utf-8')
if "import 'verification_ui_copy.dart';" not in pack:
    pack = replace_once(pack, "import 'sigillum_localization.dart';\n", "import 'sigillum_localization.dart';\nimport 'verification_ui_copy.dart';\n", 'pack copy import')
if "String _v(String key)" not in pack:
    pack = replace_once(pack, "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n", "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);\n", 'pack copy helper')
pack = pack.replace('status = "Analisi HCVPACK...";', "status = _v('packAnalyzing');")
pack = pack.replace('status = "File non trovato:\\n$packPath";', "status = _v('fileNotFound');")
pack = pack.replace('status = "HCVPACK incompleto";', "status = _v('packIncomplete');")
pack = pack.replace('status = "Formato HCVPACK non valido";', "status = _v('packInvalid');")
pack = pack.replace('status = "Questo non e un file HCVPACK";', "status = _v('packInvalid');")
pack_path.write_text(pack, encoding='utf-8')


# ---------------------------------------------------------------------------
# 6) ML recovery: v2 remains primary, v1 bundled model becomes a deterministic
#    fallback if TensorFlow Lite cannot create an interpreter for v2.
# ---------------------------------------------------------------------------
store_path = Path('lib/hcv_ml_model_store.dart')
store = store_path.read_text(encoding='utf-8')
if "assetFallbackModelPath" not in store:
    store = replace_once(
        store,
        "  static const assetModelPath = 'assets/ml/sigillum_screen_replay_v2.tflite';\n",
        "  static const assetModelPath = 'assets/ml/sigillum_screen_replay_v2.tflite';\n  static const assetFallbackModelPath = 'assets/ml/sigillum_screen_replay_v1.tflite';\n",
        'fallback model constant',
    )
    store = replace_once(
        store,
        "  Future<HCVMLModelBundle> loadBundledBundle() async {\n    return _loadAssetBundle();\n  }\n",
        "  Future<HCVMLModelBundle> loadBundledBundle() async {\n    return _loadAssetBundle(assetModelPath, 'BUNDLED_ASSET_MODEL_V2');\n  }\n\n  Future<HCVMLModelBundle> loadBundledFallbackBundle() async {\n    return _loadAssetBundle(assetFallbackModelPath, 'BUNDLED_ASSET_MODEL_V1_FALLBACK');\n  }\n",
        'fallback bundle API',
    )
    store = store.replace("    return _loadAssetBundle();", "    return _loadAssetBundle(assetModelPath, 'BUNDLED_ASSET_MODEL_V2');", 1)
    store = store.replace(
        "  Future<HCVMLModelBundle> _loadAssetBundle() async {\n    final tempDir = await getTemporaryDirectory();\n    final modelFile = File(p.join(tempDir.path, p.basename(assetModelPath)));\n    final asset = await rootBundle.load(assetModelPath);",
        "  Future<HCVMLModelBundle> _loadAssetBundle(String modelPath, String source) async {\n    final tempDir = await getTemporaryDirectory();\n    final modelFile = File(p.join(tempDir.path, p.basename(modelPath)));\n    final asset = await rootBundle.load(modelPath);",
        1,
    )
    store = store.replace("      source: 'BUNDLED_ASSET_MODEL',", "      source: source,", 1)
store_path.write_text(store, encoding='utf-8')

classifier_path = Path('lib/hcv_ml_screen_replay_classifier.dart')
classifier = classifier_path.read_text(encoding='utf-8')
classifier = classifier.replace("bundle.source == 'BUNDLED_ASSET_MODEL' ? 'v2' : 'local-update'", "bundle.source == 'BUNDLED_ASSET_MODEL_V2' ? 'v2' : bundle.source == 'BUNDLED_ASSET_MODEL_V1_FALLBACK' ? 'v1-fallback' : 'local-update'")
old_user_fail = """    if (bundle.source == 'BUNDLED_ASSET_MODEL') {
      throw Exception(_modelLoadError);
    }
"""
new_user_fail = """    if (bundle.source == 'BUNDLED_ASSET_MODEL_V2') {
      final primaryError = _modelLoadError;
      try {
        final fallback = await HCVMLModelStore.instance.loadBundledFallbackBundle();
        await _loadBundle(fallback);
        _modelLoadError = primaryError;
        return;
      } catch (fallbackError) {
        _modelLoadError = '$primaryError; BUNDLED_ASSET_MODEL_V1_FALLBACK: $fallbackError';
        throw Exception(_modelLoadError);
      }
    }
"""
if old_user_fail in classifier:
    classifier = classifier.replace(old_user_fail, new_user_fail, 1)
elif "loadBundledFallbackBundle" not in classifier:
    raise RuntimeError('ML user fallback anchor missing')
classifier_path.write_text(classifier, encoding='utf-8')


# ---------------------------------------------------------------------------
# 7) Authorized narrow detector correction. Strong signed geometric REALITY
#    must override uncorroborated static optical structure and missing ML, but
#    never confirmed temporal/active/ML display evidence.
# ---------------------------------------------------------------------------
fusion_path = Path('lib/hcv_display_risk_fusion.dart')
fusion = fusion_path.read_text(encoding='utf-8')
if "SIGNED_GEOMETRIC_REALITY_OVERRIDES_UNCORROBORATED_DISPLAY_SIGNALS" not in fusion:
    anchor = """    late final String decision;
    late final int score;
    if (hasIndependentCorroboration) {"""
    replacement = """    final liveReason = live?['reason']?.toString() ?? '';
    final signedGeometricReality = live != null &&
        live['sceneClass'] == 'REALITY' &&
        live['displayRiskDecision'] == 'NO_DISPLAY_EVIDENCE' &&
        (liveReason.contains('MULTI_DEPTH_PARALLAX_DETECTED') ||
            liveReason.contains('GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS'));
    final confirmedDisplayEvidence = liveTemporal || activeDisplayEvidence || mlStrong;

    late final String decision;
    late final int score;
    if (signedGeometricReality && !confirmedDisplayEvidence) {
      decision = 'NO_DISPLAY_EVIDENCE';
      score = min(rawScore, 20);
      evidenceSources.remove('STATIC_OPTICAL');
      strongSources.remove('STATIC_OPTICAL');
      reasons.remove('STATIC_STRUCTURE_CONFIRMED');
      reasons.remove('STATIC_SCORE_UNCORROBORATED');
      reasons.add('SIGNED_GEOMETRIC_REALITY_OVERRIDES_UNCORROBORATED_DISPLAY_SIGNALS');
    } else if (hasIndependentCorroboration) {"""
    if anchor not in fusion:
        raise RuntimeError('display fusion decision anchor missing')
    fusion = fusion.replace(anchor, replacement, 1)
fusion_path.write_text(fusion, encoding='utf-8')


# Final assertions: these are the exact regressions observed on device.
checks = {
    Path('lib/import_page.dart'): ["'VERIFICA TESTO'"],
    Path('lib/quick_hcv_media_gate_page.dart'): ["VerificationUiCopy.t(widget.languageCode, key)"],
    Path('lib/registry_verify_page.dart'): ["_v('provenanceHint')", "_v('sceneHint')", "_v('technicalDetails')", "_signedRealityScene"],
    Path('lib/hcv_ml_model_store.dart'): ['loadBundledFallbackBundle', 'BUNDLED_ASSET_MODEL_V1_FALLBACK'],
    Path('lib/hcv_ml_screen_replay_classifier.dart'): ['loadBundledFallbackBundle'],
    Path('lib/hcv_display_risk_fusion.dart'): ['SIGNED_GEOMETRIC_REALITY_OVERRIDES_UNCORROBORATED_DISPLAY_SIGNALS'],
}
for check_path, tokens in checks.items():
    text = check_path.read_text(encoding='utf-8')
    for token in tokens:
        if token not in text:
            raise RuntimeError(f'{check_path}: required verification token missing: {token}')

if 'VERIFICA TESTO / DOCUMENTO' in Path('lib/import_page.dart').read_text(encoding='utf-8'):
    raise RuntimeError('obsolete verification text/document label remains')

print('Verification UI localized and clarified; ML fallback installed; signed geometric reality fusion corrected')