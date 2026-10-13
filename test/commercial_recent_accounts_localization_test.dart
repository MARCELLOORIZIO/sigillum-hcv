import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recent account picker resolves both strings through localized copy', () {
    final source = File('lib/commercial_gate.dart').readAsStringSync();
    expect(RegExp(r"'recentAccountsTitle':").allMatches(source).length, 4);
    expect(RegExp(r"'recentAccountsHint':").allMatches(source).length, 4);
    expect(source, contains("_t('recentAccountsTitle')"));
    expect(source, contains("_t('recentAccountsHint')"));
    expect(source, isNot(contains("const Text(\n            'Account usati su questo iPhone'")));
  });
}
