from pathlib import Path
import json
from urllib.parse import unquote, urlparse

CLASSIFIER = Path('lib/hcv_ml_screen_replay_classifier.dart')
PACKAGE_CONFIG = Path('.dart_tool/package_config.json')
TARGET_IOS_TFLITE = '2.17.0'


def replace_balanced_function(source: str, signature: str, replacement: str) -> str:
    start = source.find(signature)
    if start < 0:
        raise RuntimeError(f'function signature missing: {signature}')
    brace = source.find('{', start)
    if brace < 0:
        raise RuntimeError(f'function body missing: {signature}')
    depth = 0
    end = None
    for index in range(brace, len(source)):
        char = source[index]
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                end = index + 1
                break
    if end is None:
        raise RuntimeError(f'unbalanced function: {signature}')
    return source[:start] + replacement.rstrip() + source[end:]


# ---------------------------------------------------------------------------
# Dart-side loading recovery and evidence. This changes only model loading and
# diagnostics. It deliberately leaves ML thresholds and display fusion untouched.
# ---------------------------------------------------------------------------
source = CLASSIFIER.read_text(encoding='utf-8')

if 'String? _tfliteRuntimeVersion;' not in source:
    anchor = '  String? _modelLoadError;\n'
    if anchor not in source:
        raise RuntimeError('ML runtime field anchor missing')
    source = source.replace(anchor, anchor + '  String? _tfliteRuntimeVersion;\n', 1)

if '_tfliteRuntimeVersion = null;' not in source:
    anchor = '    _modelLoadError = null;\n'
    if anchor not in source:
        raise RuntimeError('ML reset anchor missing')
    source = source.replace(anchor, anchor + '    _tfliteRuntimeVersion = null;\n', 1)

if 'String? _readTfliteRuntimeVersion()' not in source:
    signature = '  Future<void> _loadBundle(HCVMLModelBundle bundle) async'
    pos = source.find(signature)
    if pos < 0:
        raise RuntimeError('ML load-bundle anchor missing')
    helper = r'''  String? _readTfliteRuntimeVersion() {
    try {
      return version;
    } catch (_) {
      return null;
    }
  }

'''
    source = source[:pos] + helper + source[pos:]

replacement = r'''  Future<void> _loadBundle(HCVMLModelBundle bundle) async {
    _tfliteRuntimeVersion = _readTfliteRuntimeVersion();
    Object? fileLoadError;
    try {
      _interpreter = Interpreter.fromFile(bundle.modelFile);
    } catch (error) {
      fileLoadError = error;
      try {
        final bytes = await bundle.modelFile.readAsBytes();
        _interpreter = Interpreter.fromBuffer(bytes);
      } catch (bufferError) {
        throw Exception(
          'TFLITE_INTERPRETER_CREATE_FAILED '
          'runtime=${_tfliteRuntimeVersion ?? 'UNKNOWN'}; '
          'source=${bundle.source}; '
          'fromFile=$fileLoadError; fromBuffer=$bufferError',
        );
      }
    }

    final interpreter = _interpreter;
    if (interpreter == null) {
      throw Exception(
        'TFLITE_INTERPRETER_NULL runtime=${_tfliteRuntimeVersion ?? 'UNKNOWN'}; '
        'source=${bundle.source}',
      );
    }

    _classes = bundle.labels;
    _modelSource = bundle.source;
    _modelVersion = bundle.source == 'BUNDLED_ASSET_MODEL_V2'
        ? 'v2'
        : bundle.source == 'BUNDLED_ASSET_MODEL_V1_FALLBACK'
            ? 'v1-fallback'
            : 'local-update';
    _modelSha256 =
        (await sha256.bind(bundle.modelFile.openRead()).first).toString();
    _modelLoadError = null;
  }'''
source = replace_balanced_function(
    source,
    '  Future<void> _loadBundle(HCVMLModelBundle bundle) async',
    replacement,
)

# Successful analysis must state which native runtime produced the result.
if "'tfliteRuntimeVersion': _tfliteRuntimeVersion," not in source:
    anchor = "        'modelSha256': _modelSha256,\n"
    if anchor not in source:
        raise RuntimeError('ML success metadata anchor missing')
    source = source.replace(
        anchor,
        anchor + "        'tfliteRuntimeVersion': _tfliteRuntimeVersion,\n",
        1,
    )

# Unknown/error analysis must preserve the same runtime evidence.
unknown_pos = source.find("  Map<String, dynamic> _unknown(")
if unknown_pos < 0:
    raise RuntimeError('ML unknown-result function missing')
unknown_tail = source[unknown_pos:]
if "'tfliteRuntimeVersion': _tfliteRuntimeVersion," not in unknown_tail:
    anchor = "      'modelSha256': _modelSha256,\n"
    local = unknown_tail.find(anchor)
    if local < 0:
        raise RuntimeError('ML unknown metadata anchor missing')
    absolute = unknown_pos + local
    source = (
        source[:absolute]
        + anchor
        + "      'tfliteRuntimeVersion': _tfliteRuntimeVersion,\n"
        + source[absolute + len(anchor):]
    )

for token in [
    'Interpreter.fromFile(bundle.modelFile)',
    'Interpreter.fromBuffer(bytes)',
    'TFLITE_INTERPRETER_CREATE_FAILED',
    "'tfliteRuntimeVersion': _tfliteRuntimeVersion",
    'loadBundledFallbackBundle',
]:
    if token not in source:
        raise RuntimeError(f'ML iOS recovery token missing: {token}')

CLASSIFIER.write_text(source, encoding='utf-8')


# ---------------------------------------------------------------------------
# iOS native runtime compatibility. tflite_flutter 0.12.1 ships an iOS podspec
# pinned to TFLite 2.12. The bundled fallback model was produced with TF 2.16-17.
# Pin the native iOS runtime to 2.17 only after flutter pub get has materialized
# the package cache. The pre-pub invocation intentionally defers this step.
# ---------------------------------------------------------------------------
def package_root_from_uri(root_uri: str) -> Path:
    parsed = urlparse(root_uri)
    if parsed.scheme == 'file':
        return Path(unquote(parsed.path))
    candidate = Path(unquote(root_uri))
    if candidate.is_absolute():
        return candidate
    return (PACKAGE_CONFIG.parent / candidate).resolve()


def patch_ios_podspec_if_available() -> None:
    if not PACKAGE_CONFIG.exists():
        print('TFLite iOS podspec pin deferred until flutter pub get')
        return

    data = json.loads(PACKAGE_CONFIG.read_text(encoding='utf-8'))
    packages = data.get('packages')
    if not isinstance(packages, list):
        raise RuntimeError('package_config packages list missing')

    package = next(
        (item for item in packages if item.get('name') == 'tflite_flutter'),
        None,
    )
    if package is None:
        raise RuntimeError('tflite_flutter missing from package_config')

    root_uri = package.get('rootUri')
    if not isinstance(root_uri, str) or not root_uri:
        raise RuntimeError('tflite_flutter rootUri missing')

    root = package_root_from_uri(root_uri)
    podspec = root / 'ios' / 'tflite_flutter.podspec'
    if not podspec.exists():
        raise RuntimeError(f'tflite_flutter iOS podspec not found: {podspec}')

    text = podspec.read_text(encoding='utf-8')
    target = f"tflite_version = '{TARGET_IOS_TFLITE}'"
    if target not in text:
        old = "tflite_version = '2.12.0'"
        if old not in text:
            raise RuntimeError(
                'unexpected tflite_flutter podspec runtime; '
                f'expected 2.12.0 or {TARGET_IOS_TFLITE}: {podspec}'
            )
        text = text.replace(old, target, 1)
        podspec.write_text(text, encoding='utf-8')

    audit_dir = Path('/tmp/xcodebuild_logs')
    audit_dir.mkdir(parents=True, exist_ok=True)
    with (audit_dir / 'sigillum-postpatch-audit.log').open(
        'a', encoding='utf-8'
    ) as handle:
        handle.write(
            f'TFLITE_IOS_RUNTIME={TARGET_IOS_TFLITE} PODSPEC={podspec}\n'
        )

    print(f'TFLite iOS runtime pinned to {TARGET_IOS_TFLITE}: {podspec}')


patch_ios_podspec_if_available()
print('ML model loading finalized with runtime diagnostics; scoring unchanged')
