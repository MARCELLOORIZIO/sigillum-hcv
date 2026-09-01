import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared media waits for a frame and enters the lightweight import router', () {
    final home = File('lib/user_home_page.dart').readAsStringSync();

    expect(home, contains('_queueImportedPath(path);'));
    expect(home, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(home, contains('if (!await File(path).exists()) return;'));
    expect(home, contains('builder: (_) => HCVImportRouterPage('));
    expect(home, isNot(contains("import 'registry_verify_page.dart';")));
    expect(home, isNot(contains('initialMediaPath: path')));
  });
}
