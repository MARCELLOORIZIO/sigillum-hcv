import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TestFlight RC2 is fail-closed on the committed ML runtime contract', () {
    final codemagic = File('codemagic.yaml').readAsStringSync();
    final buildProofPath = 'tool/build_testflight_ipa_rc2_20260825.sh';
    final buildProof = File(buildProofPath).readAsStringSync();
    final macosPreIpa = File(
      '.github/workflows/validate-rc2-macos-preipa-20260825.yml',
    ).readAsStringSync();
    final tflitePin =
        File('tool/pin_tflite_ios_runtime_20260826.sh').readAsStringSync();
    final classifier =
        File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();
    final store = File('lib/hcv_ml_model_store.dart').readAsStringSync();

    final testflightStart = codemagic.indexOf('  ios-testflight:');
    expect(testflightStart, greaterThanOrEqualTo(0));
    final testflight = codemagic.substring(testflightStart);
    expect(
      testflight,
      contains('script: bash tool/build_testflight_ipa_rc2_20260825.sh'),
    );
    expect(testflight, contains('flutter: 3.47.1'));
    expect(
      testflight,
      contains('bash tool/pin_tflite_ios_runtime_20260826.sh'),
    );
    expect(
      testflight,
      isNot(contains(r'LATEST_BUILD_NUMBER="$(app-store-connect')),
    );

    // The final build consumes the already committed materialized source.
    // Build-time application patchers/finalizers are forbidden: source identity
    // is proved by git diff and hashes before/after pods and AOT instead.
    for (final forbidden in <String>[
      'python3 tool/apply_',
      'python3 tool/finalize_',
      'dart format',
    ]) {
      expect(
        testflight,
        isNot(contains(forbidden)),
        reason: 'TestFlight pipeline must not mutate committed source: $forbidden',
      );
      expect(
        buildProof,
        isNot(contains(forbidden)),
        reason: 'TestFlight build proof must not mutate committed source: $forbidden',
      );
    }

    for (final token in <String>[
      'COMMITTED_MATERIALIZED_SOURCE=PASS',
      'PODS_MUTATED_RELEASE_SOURCE=NO',
      'BUILD_MUTATED_RELEASE_SOURCE=NO',
      'flutter build ipa --release --no-pub',
      "tflite_version = '2.17.0'",
      'TensorFlowLiteSwift (2.17.0)',
      'BUILT_MODEL_MATCH=',
      'TFLITE_SYMBOL_PRESENT=',
      '_TfLiteInterpreterCreate',
      'TESTFLIGHT_RELEASE_PROOF=PASS',
    ]) {
      expect(buildProof, contains(token), reason: 'missing release proof: $token');
    }

    // The macOS pre-IPA gate must do more than resolve CocoaPods: it compiles
    // and links the exact iOS Release app without signing, then re-checks source
    // immutability and both bundled ML model bytes.
    expect(macosPreIpa, contains('Compile iOS release without signing'));
    expect(macosPreIpa, contains('flutter build ios'));
    expect(macosPreIpa, contains('--release'));
    expect(macosPreIpa, contains('--no-codesign'));
    expect(macosPreIpa, contains('--no-pub'));
    expect(macosPreIpa, contains("APP='build/ios/iphoneos/Runner.app'"));
    expect(macosPreIpa, contains('cmp -s "assets/ml/\$model"'));
    expect(macosPreIpa, contains('IOS_RELEASE_NOCODESIGN_BUILD=PASS'));

    for (final token in <String>[
      'TARGET_VERSION="2.17.0"',
      "tflite_version = '2.12.0'",
      "tflite_version = '2.17.0'",
      r'TFLITE_IOS_RUNTIME=$TARGET_VERSION',
    ]) {
      expect(tflitePin, contains(token), reason: 'missing TFLite pin guard: $token');
    }

    for (final token in <String>[
      'Interpreter.fromBuffer(bytes)',
      'Interpreter.fromFile(bundle.modelFile)',
      'TFLITE_INTERPRETER_CREATE_FAILED',
      'TFLITE_INTERPRETER_NULL',
      "'tfliteRuntimeVersion': _tfliteRuntimeVersion",
      'loadBundledFallbackBundle',
    ]) {
      expect(classifier, contains(token), reason: 'missing ML loader token: $token');
    }

    expect(store, contains('BUNDLED_ASSET_MODEL_V2'));
    expect(store, contains('BUNDLED_ASSET_MODEL_V1_FALLBACK'));

    if (!Platform.isWindows) {
      for (final shellPath in <String>[
        buildProofPath,
        'tool/pin_tflite_ios_runtime_20260826.sh',
      ]) {
        final shellCheck = Process.runSync('bash', ['-n', shellPath]);
        expect(
          shellCheck.exitCode,
          0,
          reason: '$shellPath syntax error: ${shellCheck.stderr}',
        );
      }
    }
  });
}
