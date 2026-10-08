import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Share Extension copy is localized in all four supported languages', () {
    final source =
        File('ios/SigillumShareExtension/ShareViewController.swift')
            .readAsStringSync();

    expect(source, contains('Locale.preferredLanguages.first'));
    for (final code in const <String>['it', 'en', 'es', 'ru']) {
      expect(source, contains('"$code": ['));
    }

    expect(source, contains('"Preparing content..."'));
    expect(source, contains('"Preparando contenido..."'));
    expect(source, contains('"Подготовка содержимого..."'));
    expect(source, contains('"CHIUDI"'));
    expect(source, contains('"CLOSE"'));
    expect(source, contains('"CERRAR"'));
    expect(source, contains('"ЗАКРЫТЬ"'));

    expect(source, contains('label.text = localized("loading")'));
    expect(source, contains('self.statusLabel?.text = self.localized("saved")'));
    expect(source, contains('openButton?.setTitle(localized("close")'));
  });

  test('PHOTO reference copy no longer claims the R2 comparison is local', () {
    final source = File('lib/registry_verify_copy.dart').readAsStringSync();

    expect(source, isNot(contains('Confronto locale V3')));
    expect(source, isNot(contains('Local V3 comparison')));
    expect(source, isNot(contains('comparación local V3')));
    expect(source, isNot(contains('Локальное сравнение V3')));

    expect(
      source,
      contains(
        'Il confronto automatico con il riferimento originale protetto SIGILLUM',
      ),
    );
    expect(
      source,
      contains(
        'The automatic comparison with the protected SIGILLUM original reference',
      ),
    );
    expect(
      source,
      contains(
        'La comparación automática con la referencia original protegida de SIGILLUM',
      ),
    );
    expect(
      source,
      contains(
        'Автоматическое сравнение с защищённым оригинальным эталоном SIGILLUM',
      ),
    );
  });
}
