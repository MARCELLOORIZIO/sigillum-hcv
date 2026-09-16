import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/sigillum_localization.dart';
import 'package:sigillum_iphone/verification_ui_copy.dart';
import 'package:sigillum_iphone/registry_verify_copy.dart';
import 'package:sigillum_iphone/lab_ui_copy.dart';

void main() {
  const languages = ['it', 'en', 'es', 'ru'];

  test('BUILD113 public copy exposes all four languages with current semantics', () {
    expect(SigillumCopy.languages.map((e) => e.code).toList(), languages);
    expect(SigillumCopy.language('es').name, 'Español');
    for (final language in languages) {
      expect(SigillumCopy.t(language, 'checkSocial'), isNotEmpty);
      expect(VerificationUiCopy.t(language, 'derivedDetail'), isNotEmpty);
      expect(RegistryVerifyCopy.t(language, 'audioMismatchDetected'), isNotEmpty);
      expect(RegistryVerifyCopy.t(language, 'videoBothDetected'), isNotEmpty);
      expect(LabUiCopy.t(language, 'diagTitle'), isNotEmpty);
    }
    expect(VerificationUiCopy.t('en', 'compatible'), 'Cannot be determined');
  });

  test('visible production verdicts no longer claim HUMAN VERIFIED', () {
    const files = [
      'lib/camera_ui_copy.dart',
      'lib/hcvpack_player_page.dart',
      'lib/text_cert_page.dart',
      'lib/video_player_verify_page.dart',
      'lib/video_verify_page.dart',
      'lib/home_page.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('HUMAN VERIFIED'), isFalse, reason: path);
    }
  });

  test('quick guide and camera copy contain no manual movement instruction', () {
    final source = '${File('lib/sigillum_quick_guide_page.dart').readAsStringSync()}\n'
        '${File('lib/camera_ui_copy.dart').readAsStringSync()}\n'
        '${File('lib/camera_ui_extended_copy.dart').readAsStringSync()}';
    for (final stale in [
      'muovi leggermente',
      'move the phone slightly',
      'mueve ligeramente',
      'слегка перемещ',
      'MUOVI IL TELEFONO LATERALMENTE',
      'MOVE THE PHONE SIDEWAYS',
    ]) {
      expect(source.toLowerCase().contains(stale.toLowerCase()), isFalse,
          reason: stale);
    }
  });

  test('registry user statuses use multilingual copy for BUILD113 audio axis', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains("_r('videoBothDetected')"));
    expect(source, contains("_r('audioMismatchDetected')"));
    expect(source, contains("_r('techHcvTrust')"));
    expect(source.contains('fingerprint audio non corrisponde al contenuto certificato'), isFalse);
  });
}
