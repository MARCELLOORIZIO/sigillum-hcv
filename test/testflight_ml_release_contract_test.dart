import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TestFlight RC2 is fail-closed on the committed ML runtime contract', () {
    final codemagic = File('codemagic.yaml').readAsStringSync();
    final buildProof =
        File('tool/build_testflight_ipa_rc2_20260825.sh').readAsStringSync();
    final classifier =
        File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();
    final store = File('lib/hcv_ml_model_store.dart').readAsStringSync();

    expect(
      codemagic,
      contains(
        'script: bash tool/build_testflight_ipa_rc2_20260825.sh',
      ),
    );
    expect(
      codemagic,
      isNot(contains('flutter build ipa --release \\\n            --build-number=')),
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
  });
}
