from pathlib import Path
import hashlib
import json
import subprocess
from urllib.parse import unquote, urlparse


def text(path: str) -> str:
    file = Path(path)
    if not file.exists():
        raise RuntimeError(f'post-patch required file missing: {path}')
    return file.read_text(encoding='utf-8')


# ---------------------------------------------------------------------------
# Public verification/navigation contract.
# ---------------------------------------------------------------------------
import_page = text('lib/import_page.dart')
for token in [
    'appBar: AppBar(',
    'leading: IconButton(',
    'icon: const Icon(Icons.arrow_back_rounded)',
    "_v('verifyText')",
    "_v('verifyPhoto')",
    "_v('verifyVideo')",
]:
    if token not in import_page:
        raise RuntimeError(f'final verification hub token missing: {token}')

old_body_arrow = """Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton("""
if old_body_arrow in import_page:
    raise RuntimeError('legacy floating verification back arrow survived post-patch')

# ---------------------------------------------------------------------------
# Camera public copy must follow the selected language. Internal HCV enums are
# intentionally not translated and are therefore not part of this check.
# ---------------------------------------------------------------------------
camera = text('lib/camera_page.dart')
for token in [
    "import 'camera_ui_copy.dart';",
    'CameraUiCopy.t(widget.languageCode, key)',
    "_c('physicalProbe')",
    "_c('analyzingScreen')",
    "_c('registryPublishing')",
    "_c('humanVerified')",
]:
    if token not in camera:
        raise RuntimeError(f'camera selected-language token missing: {token}')

for forbidden in [
    "widget.languageCode.toLowerCase().startsWith('it')",
    "status = 'STARTING...'",
    "status = 'RECORDING...'",
    "status = 'PROCESSING VIDEO...'",
    "status = 'SCATTO FOTO...'",
    "status = 'ANALYZING SCREEN REPLAY RISK...'",
    "status = 'ADDING SIGILLUM LOGO...'",
    "status = 'CREATING HCV CERTIFICATE...'",
    "status = 'DONE'",
]:
    if forbidden in camera:
        raise RuntimeError(f'camera mixed-language public status survived: {forbidden}')

# ---------------------------------------------------------------------------
# Registry must expose complete signed diagnostics while keeping the public
# four-axis result localized and severity-aware.
# ---------------------------------------------------------------------------
registry = text('lib/registry_verify_page.dart')
for token in [
    'String get _fullTechnicalDiagnostics',
    "claims['mlScreenReplayAnalysis']",
    'TFLite runtime:',
    'Pixel-grid uniformity:',
    'Fine stripe:',
    '_fullTechnicalDiagnostics,',
    "_v('registryNotFound')",
    "_v('registryUnavailable')",
]:
    if token not in registry:
        raise RuntimeError(f'final Registry diagnostic/localization token missing: {token}')

# ---------------------------------------------------------------------------
# ML: V2 remains primary, V1 remains fallback. RC2 changes only interpreter
# compatibility/diagnostics; it must not contain a detector-threshold rewrite.
# ---------------------------------------------------------------------------
classifier = text('lib/hcv_ml_screen_replay_classifier.dart')
for token in [
    'loadBundledFallbackBundle',
    'Interpreter.fromFile(bundle.modelFile)',
    'Interpreter.fromBuffer(bytes)',
    'TFLITE_INTERPRETER_CREATE_FAILED',
    "'tfliteRuntimeVersion': _tfliteRuntimeVersion",
]:
    if token not in classifier:
        raise RuntimeError(f'ML post-patch recovery token missing: {token}')

ml_finalizer = text('tool/apply_ml_ios_runtime_finalizer_20260825.py')
for forbidden in [
    'hcv_display_risk_fusion.dart',
    '_persistentVideoRiskScore',
    '_riskLabel(',
    'screenProbability >=',
    'finalScore >=',
]:
    if forbidden in ml_finalizer:
        raise RuntimeError(
            f'RC2 ML runtime finalizer unexpectedly touches scoring/fusion: {forbidden}'
        )

# Once flutter pub get exists, the package podspec must be pinned to 2.17.0.
package_config = Path('.dart_tool/package_config.json')
if package_config.exists():
    data = json.loads(package_config.read_text(encoding='utf-8'))
    package = next(
        (
            item
            for item in data.get('packages', [])
            if item.get('name') == 'tflite_flutter'
        ),
        None,
    )
    if package is None:
        raise RuntimeError('tflite_flutter missing from package_config during audit')
    root_uri = package.get('rootUri', '')
    parsed = urlparse(root_uri)
    if parsed.scheme == 'file':
        root = Path(unquote(parsed.path))
    else:
        candidate = Path(unquote(root_uri))
        root = (
            candidate
            if candidate.is_absolute()
            else (package_config.parent / candidate).resolve()
        )
    podspec = root / 'ios' / 'tflite_flutter.podspec'
    podspec_text = podspec.read_text(encoding='utf-8')
    if "tflite_version = '2.17.0'" not in podspec_text:
        raise RuntimeError(f'iOS TFLite runtime is not pinned to 2.17.0: {podspec}')

# ---------------------------------------------------------------------------
# Produce a reproducible manifest of the source ACTUALLY present after every
# build-time patcher. Existing Codemagic artifacts already collect *.log here.
# ---------------------------------------------------------------------------
critical_files = [
    'lib/camera_page.dart',
    'lib/text_cert_page.dart',
    'lib/hcv_engine.dart',
    'lib/hcv_live_screen_probe.dart',
    'lib/hcv_live_screen_probe_core.dart',
    'lib/hcv_live_screen_probe_geometry.dart',
    'lib/hcv_scene_geometry_classifier.dart',
    'lib/hcv_scene_decision_fusion.dart',
    'lib/hcv_display_risk_fusion.dart',
    'lib/hcv_planar_motion_model.dart',
    'lib/hcv_projective_motion_model.dart',
    'lib/hcv_ml_screen_replay_classifier.dart',
    'lib/hcv_ml_model_store.dart',
    'lib/import_page.dart',
    'lib/registry_verify_page.dart',
]

try:
    commit = subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], text=True
    ).strip()
except Exception:
    commit = 'UNKNOWN'

try:
    status = subprocess.check_output(
        ['git', 'status', '--short'], text=True
    ).strip()
except Exception:
    status = 'UNAVAILABLE'

audit_dir = Path('/tmp/xcodebuild_logs')
audit_dir.mkdir(parents=True, exist_ok=True)
audit_file = audit_dir / 'sigillum-postpatch-audit.log'
with audit_file.open('a', encoding='utf-8') as handle:
    handle.write('\n=== SIGILLUM POST-PATCH SOURCE AUDIT ===\n')
    handle.write(f'GIT_COMMIT={commit}\n')
    for file_name in critical_files:
        raw = Path(file_name).read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        handle.write(f'SHA256 {digest}  {file_name}\n')
    handle.write('GIT_STATUS_BEGIN\n')
    handle.write(status + '\n')
    handle.write('GIT_STATUS_END\n')
    handle.write('POSTPATCH_CONTRACT=PASS\n')

print(f'Post-patch release audit PASS: {audit_file}')
