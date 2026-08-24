import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification chooser uses the public SIGILLUM visual shell', () {
    final source = File('lib/import_page.dart').readAsStringSync();
    expect(source, contains("import 'sigillum_theme.dart';"));
    expect(source, contains('backgroundColor: SigillumTheme.deep'));
    expect(source, contains('constraints: const BoxConstraints(maxWidth: 560)'));
    expect(source, contains('EdgeInsets.fromLTRB(22, 24, 22, 36)'));
    expect(source, contains('FilledButton.icon'));
    expect(source, isNot(contains('selectedPath!')));
  });

  test('quick media gate uses the same public SIGILLUM theme', () {
    final source = File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();
    expect(source, contains("import 'sigillum_theme.dart';"));
    expect(source, contains('backgroundColor: SigillumTheme.deep'));
    expect(source, contains('constraints: const BoxConstraints(maxWidth: 560)'));
    expect(source, contains('EdgeInsets.fromLTRB(22, 24, 22, 36)'));
    expect(source, contains('FilledButton('));
  });

  test('Registry shell patch reuses SIGILLUM theme tokens', () {
    final patch = File(
      'tool/apply_fast_uncertified_media_precheck_20260823.py',
    ).readAsStringSync();
    expect(patch, contains("import 'sigillum_theme.dart';"));
    expect(patch, contains('backgroundColor: SigillumTheme.deep,'));
    expect(patch, contains('backgroundColor: SigillumTheme.panel,'));
    expect(patch, contains('border: Border.all(color: SigillumTheme.border),'));
  });
}
