import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncertified media precheck stays short and stops before full verification', () {
    final patch = File('tool/apply_fast_uncertified_media_precheck_20260823.py')
        .readAsStringSync();

    expect(patch, contains("'00:00:00.2'"));
    expect(patch, contains("'00:00:00.8'"));
    expect(patch, isNot(contains("'00:00:08.0'")));
    expect(patch, contains('if (!mounted) return null;'));
    expect(patch, contains('withData: false,'));
    expect(patch, contains("Contenuto non certificato SIGILLUM."));
  });
}
