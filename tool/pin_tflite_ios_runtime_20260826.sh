#!/usr/bin/env bash
set -euo pipefail

TARGET_VERSION="2.17.0"
PACKAGE_CONFIG=".dart_tool/package_config.json"

if [[ ! -f "$PACKAGE_CONFIG" ]]; then
  echo "TFLITE_PIN_FAIL missing $PACKAGE_CONFIG; run flutter pub get first" >&2
  exit 1
fi

PODSPEC="$(python3 - <<'PY'
from pathlib import Path
import json
from urllib.parse import unquote, urlparse

config = Path('.dart_tool/package_config.json')
data = json.loads(config.read_text(encoding='utf-8'))
package = next(
    (item for item in data.get('packages', []) if item.get('name') == 'tflite_flutter'),
    None,
)
if package is None:
    raise SystemExit('tflite_flutter missing from package_config')
root_uri = package.get('rootUri')
if not isinstance(root_uri, str) or not root_uri:
    raise SystemExit('tflite_flutter rootUri missing')
parsed = urlparse(root_uri)
if parsed.scheme == 'file':
    root = Path(unquote(parsed.path))
else:
    candidate = Path(unquote(root_uri))
    root = candidate if candidate.is_absolute() else (config.parent / candidate).resolve()
print(root / 'ios' / 'tflite_flutter.podspec')
PY
)"

if [[ ! -f "$PODSPEC" ]]; then
  echo "TFLITE_PIN_FAIL podspec missing: $PODSPEC" >&2
  exit 1
fi

if grep -Fq "tflite_version = '$TARGET_VERSION'" "$PODSPEC"; then
  :
elif grep -Fq "tflite_version = '2.12.0'" "$PODSPEC"; then
  python3 - "$PODSPEC" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
old = "tflite_version = '2.12.0'"
new = "tflite_version = '2.17.0'"
if text.count(old) != 1:
    raise SystemExit(f'unexpected TFLite 2.12 token count: {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
PY
else
  echo "TFLITE_PIN_FAIL unexpected tflite_flutter podspec runtime" >&2
  grep -n "tflite_version" "$PODSPEC" >&2 || true
  exit 1
fi

if ! grep -Fq "tflite_version = '$TARGET_VERSION'" "$PODSPEC"; then
  echo "TFLITE_PIN_FAIL target did not persist: $PODSPEC" >&2
  exit 1
fi

echo "TFLITE_IOS_RUNTIME=$TARGET_VERSION"
echo "TFLITE_PODSPEC=$PODSPEC"
