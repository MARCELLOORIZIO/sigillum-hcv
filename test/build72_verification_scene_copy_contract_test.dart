import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no-display scene state is mapped before screen-risk state', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    const noScreen = "if (axis == 'scene' && value.contains('nessun'))";
    const uncertain = "if (axis == 'scene' && value.contains('conclusiva'))";
    const risk = "if (axis == 'scene' && value.contains('forte rischio'))";

    final noScreenIndex = source.indexOf(noScreen);
    final uncertainIndex = source.indexOf(uncertain);
    final riskIndex = source.indexOf(risk);

    expect(noScreenIndex, greaterThanOrEqualTo(0));
    expect(uncertainIndex, greaterThan(noScreenIndex));
    expect(riskIndex, greaterThan(uncertainIndex));
    expect(
      source,
      isNot(contains("value.contains('forte rischio') || value.contains('display')")),
    );
  });
}
