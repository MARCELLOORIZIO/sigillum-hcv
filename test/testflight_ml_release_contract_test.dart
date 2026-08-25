import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TestFlight RC2 is fail-closed on the committed ML runtime contract', () {
    final codemagic = File('codemagic.yaml').readAsStringSync();
    final buildProofPath = 'tool/build_testflight_ipa_rc2_20260825.sh';
    final buildProof = File(buildProofPath).readAsStringSync();
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
    expect(
      testflight,
      isNot(contains(r'LATEST_BUILD_NUMBER="$(app-store-connect')),
    );

    for (final token in <String>[
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
      final shellCheck = Process.runSync('bash', ['-n', buildProofPath]);
      expect(
        shellCheck.exitCode,
        0,
        reason: 'TestFlight build script syntax error: ${shellCheck.stderr}',
      );
    }
  });
}
