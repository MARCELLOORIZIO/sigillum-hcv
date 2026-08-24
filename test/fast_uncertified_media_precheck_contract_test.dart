import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncertified media precheck stays short and stops before full verification', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();

    expect(source, contains("'00:00:00.2'"));
    expect(source, contains("'00:00:00.8'"));
    expect(source, isNot(contains("'00:00:01.5'")));
    expect(source, isNot(contains("'00:00:02.5'")));
    expect(source, isNot(contains("'00:00:04.0'")));
    expect(source, isNot(contains("'00:00:06.0'")));
    expect(source, isNot(contains("'00:00:08.0'")));
    expect(source, contains('if (!mounted) return null;'));
    expect(source, contains('withData: false,'));
    expect(source, contains('Contenuto non certificato SIGILLUM.'));
  });
}
