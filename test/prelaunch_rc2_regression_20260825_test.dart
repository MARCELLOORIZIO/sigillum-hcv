import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RC2 verification back navigation stays in AppBar', () {
    final page = File('lib/import_page.dart').readAsStringSync();
    expect(page, contains('appBar: AppBar('));
    expect(page, contains('leading: IconButton('));
    expect(page, contains('icon: const Icon(Icons.arrow_back_rounded)'));
    expect(
      page,
      isNot(contains(
        'Align(\n                    alignment: Alignment.centerLeft,\n                    child: IconButton(',
      )),
    );
  });

  test('RC2 camera runtime copy follows selected IT EN ES RU language', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final copy = File('lib/camera_ui_copy.dart').readAsStringSync();

    expect(camera, contains('CameraUiCopy.t(widget.languageCode, key)'));
    expect(camera, contains("_c('physicalProbe')"));
    expect(camera, contains("_c('analyzingScreen')"));
    expect(camera, contains("_c('registryPublishing')"));
    expect(camera, isNot(contains("status = 'STARTING...'")));
    expect(camera, isNot(contains("status = 'SCATTO FOTO...'")));

    for (final language in ["'it'", "'en'", "'es'", "'ru'"]) {
      expect(copy, contains(language));
    }
  });

  test('RC2 Registry keeps complete signed diagnostics available', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(registry, contains('String get _fullTechnicalDiagnostics'));
    expect(registry, contains("claims['mlScreenReplayAnalysis']"));
    expect(registry, contains('TFLite runtime:'));
    expect(registry, contains('Pixel-grid uniformity:'));
    expect(registry, contains('Fine stripe:'));
    expect(registry, contains('_fullTechnicalDiagnostics,'));
  });

  test('RC2 ML recovery changes runtime loading, not detector thresholds', () {
    final classifier =
        File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();
    final finalizer =
        File('tool/apply_ml_ios_runtime_finalizer_20260825.py')
            .readAsStringSync();

    expect(classifier, contains('loadBundledFallbackBundle'));
    expect(classifier, contains('Interpreter.fromBuffer(bytes)'));
    expect(classifier, contains('TFLITE_INTERPRETER_CREATE_FAILED'));
    expect(classifier, contains("'tfliteRuntimeVersion': _tfliteRuntimeVersion"));
    expect(finalizer, isNot(contains('hcv_display_risk_fusion.dart')));
    expect(finalizer, isNot(contains('_persistentVideoRiskScore')));
    expect(finalizer, isNot(contains('screenProbability >=')));
  });

  test('RC2 final source is protected by a post-patcher audit', () {
    final audit = File('tool/verify_postpatch_release_20260825.py')
        .readAsStringSync();
    expect(audit, contains('POSTPATCH_CONTRACT=PASS'));
    expect(audit, contains('lib/hcv_display_risk_fusion.dart'));
    expect(audit, contains('lib/hcv_ml_screen_replay_classifier.dart'));
    expect(audit, contains("tflite_version = '2.17.0'"));
  });
}
