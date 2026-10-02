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

  test('production copy maps keep exact key parity across all four languages', () {
    const files = <String>[
      'lib/sigillum_localization.dart',
      'lib/camera_ui_copy.dart',
      'lib/camera_ui_extended_copy.dart',
      'lib/verification_ui_copy.dart',
      'lib/registry_verify_copy.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      final positions = <String, int>{
        for (final language in languages)
          language: source.indexOf("'$language':"),
      };
      for (final entry in positions.entries) {
        expect(
          entry.value,
          greaterThanOrEqualTo(0),
          reason: path + ' missing language map ' + entry.key,
        );
      }

      Set<String> keysFor(String language) {
        final start = positions[language]!;
        final later = positions.values.where((value) => value > start).toList();
        final end = later.isEmpty
            ? source.length
            : later.reduce((left, right) => left < right ? left : right);
        final chunk = source.substring(start, end);
        return RegExp(r"^\s*'([^']+)'\s*:", multiLine: true)
            .allMatches(chunk)
            .map((match) => match.group(1)!)
            .where((key) => !languages.contains(key))
            .toSet();
      }

      final italian = keysFor('it');
      expect(italian, isNotEmpty, reason: path + ' has no Italian copy keys');
      for (final language in const ['en', 'es', 'ru']) {
        expect(
          keysFor(language),
          italian,
          reason: path + ' key mismatch for ' + language,
        );
      }
    }
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
