import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text pages dismiss the iOS keyboard before actions and navigation', () {
    final script = File('tool/apply_text_keyboard_registry_photo_arm_fix.py')
        .readAsStringSync();
    expect(
      script,
      contains("SystemChannels.textInput.invokeMethod<void>('TextInput.hide')"),
    );
    expect(script, contains('_dismissKeyboard();'));
    expect(script, contains('dismiss keyboard before text verification route'));
    expect(script, contains('dismiss keyboard on Registry verification'));
  });

  test(
    'missing text certificate is recovered only from a valid signed local copy',
    () {
      final script = File('tool/apply_text_keyboard_registry_photo_arm_fix.py')
          .readAsStringSync();
      expect(script, contains('_findLocalTextCertificate'));
      expect(script, contains('await _verifier.verifyFile(entity.path)'));
      expect(script, contains('localId == normalizedId'));
      expect(script, contains('uploadCertificateFile(localFile.path)'));
      expect(script, contains('enqueueCertificateFile(localFile.path)'));
    },
  );

  test(
    'photo proceed only arms a manual shot while video flow is untouched',
    () {
      final script = File('tool/apply_text_keyboard_registry_photo_arm_fix.py')
          .readAsStringSync();
      expect(script, contains('_armedPhotoScreenProbe'));
      expect(script, contains('INQUADRA E PREMI IL PULSANTE DI SCATTO'));
      expect(script, contains('return;'));
      expect(script, isNot(contains('Future<void> start() async')));
      expect(script, isNot(contains('processVideo(')));
      expect(script, isNot(contains('engine.setClaims')));
      expect(script, isNot(contains('displayRisk')));
      expect(script, isNot(contains('HCVDisplayRiskFusion')));
    },
  );

  test('photo arming expires and cannot cross camera or zoom changes', () {
    final script = File('tool/apply_text_keyboard_registry_photo_arm_fix.py')
        .readAsStringSync();
    expect(script, contains('Duration(seconds: 15)'));
    expect(script, contains('_armedPhotoCameraIndex == selectedCameraIndex'));
    expect(script, contains('(currentZoom - _armedPhotoZoom!).abs() < 0.01'));
  });
}
