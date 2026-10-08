import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BUILD136 field regression fixes', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final manual =
        File('lib/manual_reference_compare_page.dart').readAsStringSync();
    final secure = File('lib/secure_originals_page.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final shareExtension = File(
      'ios/SigillumShareExtension/ShareViewController.swift',
    ).readAsStringSync();

    test('warm iOS share handoff survives a non-root visible route', () {
      expect(gate, contains('with WidgetsBindingObserver'));
      expect(gate, contains('didChangeAppLifecycleState'));
      expect(gate, contains('AppLifecycleState.resumed'));
      expect(gate, contains('Navigator.of(context, rootNavigator: true)'));
      expect(gate, contains('await _ackSharedPath(path);'));

      final handlerStart = gate.indexOf('Future<dynamic> _handleNativeIntent');
      final handlerEnd = gate.indexOf('Future<void> _checkInitialIntent');
      final handler = gate.substring(handlerStart, handlerEnd);
      expect(handler, isNot(contains("'ackSharedPath'")));

      final getStart = scene.indexOf('if call.method == "getSharedPath"');
      final ackStart = scene.indexOf('call.method == "ackSharedPath"');
      final getBlock = scene.substring(getStart, ackStart);
      expect(getBlock, contains('pendingSharedPath()'));
      expect(getBlock, isNot(contains('consumeSharedPath()')));
    });

    test('manual R2 comparison preserves the selected video timestamp', () {
      expect(
        manual,
        contains('position >= duration - const Duration(seconds: 1)'),
      );
      expect(manual, contains('await controller.seekTo(Duration.zero);'));
      expect(
        manual,
        contains('initialPosition: Duration(seconds: seconds)'),
      );
      expect(manual, isNot(contains('Uri.https(')));
      expect(manual, isNot(contains('LaunchMode.externalApplication')));
    });

    test('share-extension photo handoff adds no lossy JPEG recompression', () {
      expect(
        shareExtension,
        isNot(contains('jpegData(compressionQuality: 0.95)')),
      );
      expect(shareExtension, contains('prepareImageData'));
      expect(shareExtension, contains('return (data, "jpg")'));
      expect(shareExtension, contains('return (data, "png")'));
      expect(shareExtension, contains('image.pngData()'));
    });

    test('protected originals expose the full verifier again', () {
      expect(secure, contains("import 'registry_verify_page.dart';"));
      expect(secure, contains('Future<void> _verify('));
      expect(secure, contains('RegistryVerifyPage('));
      expect(secure, contains('initialMediaPath: clear!.path'));
      expect(secure, contains('initialHcvId: record.hcvId'));
      expect(secure, contains("label: Text(_t('verifyTitle'))"));
    });

    test('successful Registry outbox completion is green Registry OK', () {
      expect(
        camera,
        contains(
          "? '\${_c('registryOk')}: \${hcvId ?? _c('certificatePublished')}'",
        ),
      );
      expect(camera, contains("registryStatus!.startsWith(_c('registryOk'))"));
    });
  });
}
