import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification copy covers every selectable app language', () {
    final copy = File('lib/verification_ui_copy.dart').readAsStringSync();
    for (final code in ["'it'", "'en'", "'es'", "'ru'"]) {
      expect(copy, contains('$code: {'));
    }
    for (final token in [
      "'provenanceHint':",
      "'integrityHint':",
      "'sceneHint':",
      "'derivationHint':",
      "'realityDetected':",
      "'technicalDetails':",
    ]) {
      expect(copy, contains(token));
    }
  });

  test('pipeline cannot restore the obsolete text document label', () {
    final picker = File(
      'tool/apply_media_specific_verification_picker_fix_20260822.py',
    ).readAsStringSync();
    final finalizer = File(
      'tool/apply_verification_language_finalizer_20260824.py',
    ).readAsStringSync();
    expect(picker, isNot(contains('VERIFICA TESTO / DOCUMENTO')));
    expect(picker, contains("'VERIFICA TESTO'"));
    expect(finalizer, contains("_v('verifyText')"));
    expect(finalizer, contains("_v('verifyPhoto')"));
    expect(finalizer, contains("_v('verifyVideo')"));
  });

  test('verification refinement fixes scene regression without weakening confirmed display evidence', () {
    final patch = File(
      'tool/apply_verification_clarity_localization_ml_fix_20260824.py',
    ).readAsStringSync();
    expect(
      patch,
      contains('SIGNED_GEOMETRIC_REALITY_OVERRIDES_UNCORROBORATED_DISPLAY_SIGNALS'),
    );
    expect(patch, contains("live['sceneClass'] == 'REALITY'"));
    expect(
      patch,
      contains("live['displayRiskDecision'] == 'NO_DISPLAY_EVIDENCE'"),
    );
    expect(
      patch,
      contains('final confirmedDisplayEvidence = liveTemporal || activeDisplayEvidence || mlStrong;'),
    );
    expect(patch, contains('signedGeometricReality && !confirmedDisplayEvidence'));
  });

  test('user build has a bundled ML fallback if v2 interpreter cannot start', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final patch = File(
      'tool/apply_verification_clarity_localization_ml_fix_20260824.py',
    ).readAsStringSync();
    expect(pubspec, contains('assets/ml/sigillum_screen_replay_v2.tflite'));
    expect(pubspec, contains('assets/ml/sigillum_screen_replay_v1.tflite'));
    expect(patch, contains('loadBundledFallbackBundle'));
    expect(patch, contains('BUNDLED_ASSET_MODEL_V1_FALLBACK'));
  });

  test('technical diagnostics are collapsed and verification subpages inherit selected language', () {
    final patch = File(
      'tool/apply_verification_clarity_localization_ml_fix_20260824.py',
    ).readAsStringSync();
    final finalizer = File(
      'tool/apply_verification_language_finalizer_20260824.py',
    ).readAsStringSync();
    expect(patch, contains("_v('technicalDetails')"));
    expect(patch, contains('ExpansionTile('));
    expect(patch, contains("_v('provenanceHint')"));
    expect(patch, contains("_v('integrityHint')"));
    expect(patch, contains("_v('sceneHint')"));
    expect(patch, contains("_v('derivationHint')"));
    expect(
      finalizer,
      contains("VerificationUiCopy.t(widget.languageCode, key)"),
    );
  });
}
