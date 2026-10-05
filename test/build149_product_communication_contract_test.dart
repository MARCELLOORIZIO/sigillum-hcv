import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD149 product communication matches the current SIGILLUM architecture', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final localization = File('lib/sigillum_localization.dart').readAsStringSync();
    final guide = File('lib/sigillum_quick_guide_page.dart').readAsStringSync();
    final verify = File('lib/verification_ui_copy.dart').readAsStringSync();
    final registry = File('lib/registry_verify_copy.dart').readAsStringSync();
    final textPage = File('lib/text_cert_page.dart').readAsStringSync();

    final versionMatch =
        RegExp(r'^version:\s*1\.0\.0\+(\d+)\s*$', multiLine: true)
            .firstMatch(pubspec);
    expect(versionMatch, isNotNull);
    expect(int.parse(versionMatch!.group(1)!), greaterThanOrEqualTo(149));

    for (final phrase in <String>[
      'Tu crei. SIGILLUM protegge l’origine.',
      'You create. SIGILLUM protects the origin.',
      'Tú creas. SIGILLUM protege el origen.',
      'Вы создаёте. SIGILLUM защищает источник.',
    ]) {
      expect(localization, contains(phrase));
    }

    expect(localization, contains('Scrivi in SIGILLUM. Certifica le tue parole prima di pubblicarle.'));
    expect(localization, contains('Per foto e video il riferimento protetto viene registrato prima del rilascio all’esterno'));
    expect(guide, contains('iOS 16'));
    expect(guide, contains('iPhone 8'));
    expect(guide, contains('iPhone X'));
    expect(guide, contains('TU — Scatta, registra o scrivi'));
    expect(guide, contains('SIGILLUM — Crea l’origine verificabile'));

    expect(verify, contains('Indizi di scena fisica'));
    expect(verify, contains('Physical-scene evidence'));
    expect(registry, contains('COPIA COMPATIBILE CON IL RIFERIMENTO SIGILLUM'));
    expect(registry, contains('Analisi tecnica della scena'));
    expect(textPage, contains('impronta del testo originale certificato'));

    for (final obsolete in <String>[
      'Prova tecnica per contenuti creati da persone reali.',
      'Technical proof for content created by real people.',
      'Changes remain detectable.',
      'Realtà rilevata',
      'Reality detected',
      'Livello prova AI',
      'AI proof level',
    ]) {
      expect(
        localization.contains(obsolete) ||
            verify.contains(obsolete) ||
            registry.contains(obsolete),
        isFalse,
        reason: 'Obsolete or overbroad claim remains: $obsolete',
      );
    }
  });
}
