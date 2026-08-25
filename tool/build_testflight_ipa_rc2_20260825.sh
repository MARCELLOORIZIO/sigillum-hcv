#!/usr/bin/env bash
set -euo pipefail

AUDIT_DIR="/tmp/xcodebuild_logs"
PROOF_LOG="$AUDIT_DIR/sigillum-testflight-release-proof.log"
mkdir -p "$AUDIT_DIR"
: > "$PROOF_LOG"

log() {
  echo "$*" | tee -a "$PROOF_LOG"
}

require_source_token() {
  local file="$1"
  local token="$2"
  if ! grep -Fq "$token" "$file"; then
    log "SOURCE_GUARD_FAIL file=$file token=$token"
    exit 1
  fi
  log "SOURCE_GUARD_PASS file=$file token=$token"
}

log "=== SIGILLUM TESTFLIGHT RC2 RELEASE PROOF ==="
BUILD_COMMIT="$(git rev-parse HEAD)"
log "GIT_COMMIT=$BUILD_COMMIT"
log "GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)"

# Materialize the exact release source inside the same step that will archive
# it. The wrapper is resilient to the one legacy Registry layout variant that
# can lose its helper anchor on an additional finalization pass.
python3 tool/finalize_testflight_release_source_20260825.py

# The application source has just been finalized, so validate THIS exact tree
# before AOT. Nothing below this block is allowed to mutate Dart application
# source. A second audit after tests proves the test suite did not change it.
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --reporter expanded 2>&1 | tee "$AUDIT_DIR/flutter-tests-preipa.log"
python3 tool/verify_postpatch_release_20260825.py
log "PREBUILD_SOURCE_VALIDATION=PASS"

# Hard semantic guards: these are exactly the pieces that must be present in the
# source compiled into TestFlight.
require_source_token lib/camera_page.dart "import 'camera_ui_extended_copy.dart';"
require_source_token lib/camera_page.dart "CameraUiExtendedCopy.t(widget.languageCode, key)"
require_source_token lib/hcv_ml_screen_replay_classifier.dart "Interpreter.fromBuffer(bytes)"
require_source_token lib/hcv_ml_screen_replay_classifier.dart "Interpreter.fromFile(bundle.modelFile)"
require_source_token lib/hcv_ml_screen_replay_classifier.dart "TFLITE_INTERPRETER_CREATE_FAILED"
require_source_token lib/hcv_ml_screen_replay_classifier.dart "TFLITE_INTERPRETER_NULL"
require_source_token lib/hcv_ml_screen_replay_classifier.dart "'tfliteRuntimeVersion': _tfliteRuntimeVersion"
require_source_token lib/hcv_ml_screen_replay_classifier.dart "loadBundledFallbackBundle"
require_source_token lib/hcv_ml_model_store.dart "BUNDLED_ASSET_MODEL_V2"
require_source_token lib/hcv_ml_model_store.dart "BUNDLED_ASSET_MODEL_V1_FALLBACK"
require_source_token lib/registry_verify_page.dart "_v('registryHelper')"
require_source_token lib/registry_verify_page.dart "String get _fullTechnicalDiagnostics"
require_source_token lib/registry_verify_page.dart "TFLite runtime:"

# The release finalizer above pins the tflite_flutter podspec after pub get.
# Prove that exact native runtime before CocoaPods resolves the archive.
TFLITE_PODSPEC="$(python3 - <<'PY'
from pathlib import Path
import json
from urllib.parse import unquote, urlparse

config = Path('.dart_tool/package_config.json')
data = json.loads(config.read_text(encoding='utf-8'))
package = next(item for item in data['packages'] if item.get('name') == 'tflite_flutter')
root_uri = package['rootUri']
parsed = urlparse(root_uri)
if parsed.scheme == 'file':
    root = Path(unquote(parsed.path))
else:
    candidate = Path(unquote(root_uri))
    root = candidate if candidate.is_absolute() else (config.parent / candidate).resolve()
print(root / 'ios' / 'tflite_flutter.podspec')
PY
)"

if [[ ! -f "$TFLITE_PODSPEC" ]]; then
  log "TFLITE_PODSPEC_MISSING=$TFLITE_PODSPEC"
  exit 1
fi
if ! grep -Fq "tflite_version = '2.17.0'" "$TFLITE_PODSPEC"; then
  log "TFLITE_PODSPEC_VERSION_FAIL=$TFLITE_PODSPEC"
  cat "$TFLITE_PODSPEC" >> "$PROOF_LOG"
  exit 1
fi
log "TFLITE_PODSPEC_VERSION=2.17.0"
log "TFLITE_PODSPEC=$TFLITE_PODSPEC"

# Resolve pods now and lock the exact native runtime. flutter build below uses
# --no-pub, so the validated Dart source/package state cannot be rematerialized.
pushd ios >/dev/null
pod install --repo-update
popd >/dev/null

if [[ ! -f ios/Podfile.lock ]]; then
  log "PODFILE_LOCK_MISSING"
  exit 1
fi
cp ios/Podfile.lock "$AUDIT_DIR/Podfile.testflight.lock.log"

if ! grep -Fq "TensorFlowLiteSwift (2.17.0)" ios/Podfile.lock; then
  log "TFLITE_POD_LOCK_FAIL expected=TensorFlowLiteSwift_2.17.0"
  grep -n "TensorFlowLite" ios/Podfile.lock | tee -a "$PROOF_LOG" || true
  exit 1
fi
log "TFLITE_POD_LOCK=TensorFlowLiteSwift_2.17.0"
grep -n "TensorFlowLite" ios/Podfile.lock | tee -a "$PROOF_LOG" || true

# Source fingerprints immediately before AOT compilation.
log "PREBUILD_SOURCE_SHA_BEGIN"
shasum -a 256 \
  lib/camera_page.dart \
  lib/hcv_ml_screen_replay_classifier.dart \
  lib/hcv_ml_model_store.dart \
  lib/registry_verify_page.dart \
  lib/verification_ui_copy.dart \
  assets/ml/sigillum_screen_replay_v2.tflite \
  assets/ml/sigillum_screen_replay_v1.tflite | tee -a "$PROOF_LOG"
log "PREBUILD_SOURCE_SHA_END"

LATEST_BUILD_NUMBER="$(app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID")"
if ! [[ "$LATEST_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  log "INVALID_TESTFLIGHT_BUILD_NUMBER=$LATEST_BUILD_NUMBER"
  exit 1
fi
BUILD_NUMBER=$((LATEST_BUILD_NUMBER + 1))
log "TESTFLIGHT_BUILD_NUMBER=$BUILD_NUMBER"

flutter build ipa --release --no-pub \
  --build-number="$BUILD_NUMBER" \
  --dart-define=SIGILLUM_EDITION=user \
  --dart-define=SIGILLUM_API_BASE_URL=https://sigillum-registry-production.onrender.com \
  --dart-define=GIT_COMMIT="$BUILD_COMMIT" \
  --export-options-plist=/Users/builder/export_options.plist

ARCHIVE="$(find build/ios/archive -maxdepth 1 -type d -name '*.xcarchive' | head -n 1)"
if [[ -z "$ARCHIVE" || ! -d "$ARCHIVE" ]]; then
  log "XCARCHIVE_MISSING"
  exit 1
fi
APP="$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  log "ARCHIVED_APP_MISSING archive=$ARCHIVE"
  exit 1
fi
log "XCARCHIVE=$ARCHIVE"
log "ARCHIVED_APP=$APP"

# Prove the models embedded in the app are byte-identical to the validated
# repository assets.
FLUTTER_ASSETS="$APP/Frameworks/App.framework/flutter_assets"
BUILT_V2="$FLUTTER_ASSETS/assets/ml/sigillum_screen_replay_v2.tflite"
BUILT_V1="$FLUTTER_ASSETS/assets/ml/sigillum_screen_replay_v1.tflite"
for pair in \
  "assets/ml/sigillum_screen_replay_v2.tflite|$BUILT_V2" \
  "assets/ml/sigillum_screen_replay_v1.tflite|$BUILT_V1"; do
  SOURCE_FILE="${pair%%|*}"
  BUILT_FILE="${pair#*|}"
  if [[ ! -f "$BUILT_FILE" ]]; then
    log "BUILT_MODEL_MISSING=$BUILT_FILE"
    exit 1
  fi
  if ! cmp -s "$SOURCE_FILE" "$BUILT_FILE"; then
    log "BUILT_MODEL_MISMATCH source=$SOURCE_FILE built=$BUILT_FILE"
    shasum -a 256 "$SOURCE_FILE" "$BUILT_FILE" | tee -a "$PROOF_LOG"
    exit 1
  fi
  log "BUILT_MODEL_MATCH=$SOURCE_FILE"
  shasum -a 256 "$BUILT_FILE" | tee -a "$PROOF_LOG"
done

# tflite_flutter resolves the C API through DynamicLibrary.process() on iOS.
# The required TfLite symbols may therefore be exported either by the Runner
# executable or by a dynamic framework/dylib loaded into the app process. Scan
# the complete archived process image instead of assuming one linkage shape.
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
RUNNER_BIN="$APP/$EXECUTABLE_NAME"
if [[ ! -f "$RUNNER_BIN" ]]; then
  log "RUNNER_BINARY_MISSING=$RUNNER_BIN"
  exit 1
fi

SYMBOL_DUMP="$AUDIT_DIR/tflite-global-symbols.log"
: > "$SYMBOL_DUMP"
{
  echo "=== $RUNNER_BIN ==="
  nm -gU "$RUNNER_BIN" || true
} >> "$SYMBOL_DUMP" 2>&1

if [[ -d "$APP/Frameworks" ]]; then
  for framework in "$APP"/Frameworks/*.framework; do
    [[ -d "$framework" ]] || continue
    framework_name="$(basename "$framework" .framework)"
    framework_binary="$framework/$framework_name"
    if [[ -f "$framework_binary" ]]; then
      {
        echo "=== $framework_binary ==="
        nm -gU "$framework_binary" || true
      } >> "$SYMBOL_DUMP" 2>&1
    fi
  done
  for dylib in "$APP"/Frameworks/*.dylib; do
    [[ -f "$dylib" ]] || continue
    {
      echo "=== $dylib ==="
      nm -gU "$dylib" || true
    } >> "$SYMBOL_DUMP" 2>&1
  done
fi

for symbol in _TfLiteModelCreate _TfLiteInterpreterCreate _TfLiteInterpreterAllocateTensors _TfLiteInterpreterInvoke; do
  if ! grep -Fq "$symbol" "$SYMBOL_DUMP"; then
    log "TFLITE_SYMBOL_MISSING=$symbol"
    exit 1
  fi
  log "TFLITE_SYMBOL_PRESENT=$symbol"
done

# Confirm the Xcode release configuration retains global symbols as required by
# the FFI package.
if ! grep -Fq 'STRIP_STYLE = "non-global";' ios/Runner.xcodeproj/project.pbxproj; then
  log "STRIP_STYLE_GUARD_FAIL"
  exit 1
fi
log "STRIP_STYLE=non-global"

# AOT proof is informational because Dart snapshot layout can change between
# Flutter releases; the source/pod/model/symbol guards above are authoritative.
APP_AOT="$APP/Frameworks/App.framework/App"
if [[ -f "$APP_AOT" ]] && strings "$APP_AOT" | grep -Fq 'TFLITE_INTERPRETER_CREATE_FAILED'; then
  log "AOT_ML_DIAGNOSTIC_MARKER=PASS"
else
  log "AOT_ML_DIAGNOSTIC_MARKER=NOT_VISIBLE_IN_STRINGS"
fi

log "ARCHIVED_RUNNER_SHA=$(shasum -a 256 "$RUNNER_BIN" | awk '{print $1}')"
log "TESTFLIGHT_RELEASE_PROOF=PASS"
