import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'shared media waits for a frame and enters the lightweight import router',
    () {
      final gate = File('lib/commercial_gate.dart').readAsStringSync();
      final home = File('lib/user_home_page.dart').readAsStringSync();

      expect(gate, contains('void _queueImportedPath(String path)'));
      expect(gate, contains('_queueImportedPath(path);'));
      expect(home, contains('WidgetsBinding.instance.addPostFrameCallback'));
      expect(
        gate,
        contains('Future<void> _openImportedPath(String path) async'),
      );
      expect(gate, contains('HCVImportRouterPage('));
      expect(gate, contains("MethodChannel('hcv.intent')"));
      expect(gate, contains("invokeMethod<String>('getSharedPath')"));
      expect(gate, contains("invokeMethod<bool>('ackSharedPath'"));
      expect(
        gate.indexOf("MethodChannel('hcv.intent')"),
        lessThan(gate.indexOf("if (_stage == _GateStage.creator)")),
        reason: 'Shared verification must be owned above Creator entitlement.',
      );
      expect(home, isNot(contains("MethodChannel('hcv.intent')")));
      expect(home, isNot(contains('HCVImportRouterPage(')));
    },
  );
}
