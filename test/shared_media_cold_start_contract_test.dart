import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'shared media waits for a frame and enters the lightweight import router',
    () {
      final home = File('lib/user_home_page.dart').readAsStringSync();

      expect(home, contains('void _queueImportedPath(String path)'));
      expect(home, contains('_queueImportedPath(path);'));
      expect(home, contains('WidgetsBinding.instance.addPostFrameCallback'));
      expect(
        home,
        contains('Future<void> _openImportedPath(String path) async'),
      );
      expect(home, contains('HCVImportRouterPage('));
      expect(home, isNot(contains("import 'registry_verify_page.dart';")));
    },
  );
}
