import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS share handoff', () {
    final extension = File(
      'ios/SigillumShareExtension/ShareViewController.swift',
    ).readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final userHome = File('lib/user_home_page.dart').readAsStringSync();
    final labHome = File('lib/home_page.dart').readAsStringSync();

    test('share extension does not attempt an unsupported app launch', () {
      expect(extension, isNot(contains('extensionContext?.open(')));
      expect(extension, isNot(contains('openUrlViaResponderChain')));
      expect(extension, isNot(contains('NSSelectorFromString("openURL:")')));
      expect(extension, isNot(contains('APRI SIGILLUM')));
    });

    test('share extension saves the file and presents a clear close action', () {
      expect(extension, contains('Contenuto salvato in Fotocamera Sigillum'));
      expect(extension, contains('la verifica partirà automaticamente'));
      expect(extension, contains('setTitle("CHIUDI", for: .normal)'));
      expect(
        extension,
        contains('defaults?.set(destination.path, forKey: sharedPathKey)'),
      );
    });

    test('native path remains pending until Flutter acquires it', () {
      expect(scene, contains('stageSharedPathFromAppGroupIfNeeded'));
      expect(scene, contains('ackSharedPath'));
      expect(
        scene,
        contains('UserDefaults.standard.set(path, forKey: "hcv.sharedPath")'),
      );
    });

    test('both Flutter entry pages acknowledge and deduplicate the path', () {
      for (final source in [userHome, labHome]) {
        expect(source, contains("'ackSharedPath'"));
        expect(source, contains('_lastOpenedSharedPath'));
        expect(source, contains("'path': path"));
      }
    });
  });
}
