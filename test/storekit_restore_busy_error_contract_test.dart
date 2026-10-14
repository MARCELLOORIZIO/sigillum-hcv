import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restore purchases routes through existing busy and error handler', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    expect(gate, contains('() => _run(() => CommercialBillingService.instance.restore())'));
    expect(gate, contains("if (_busy) return;"));
    expect(gate, contains("_localizedError(error)"));
    expect(gate, isNot(contains('() => CommercialBillingService.instance.restore(),')));
  });
}
