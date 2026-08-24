import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restored unpaid sessions return to public home only at bootstrap', () {
    final source = File('lib/commercial_gate.dart').readAsStringSync();

    expect(
      source,
      contains('await _routeAuthenticated(returnToLandingIfUnpaid: true);'),
    );
    expect(
      source,
      contains('bool returnToLandingIfUnpaid = false,'),
    );
    expect(
      source,
      contains('if (returnToLandingIfUnpaid)'),
    );
    expect(
      source,
      contains('setState(() => _stage = _GateStage.landing)'),
    );
    expect(
      source,
      contains('setState(() => _stage = _GateStage.billing)'),
    );

    expect(
      'returnToLandingIfUnpaid: true'.allMatches(source).length,
      1,
      reason: 'Only app bootstrap may bypass the paywall to the public home.',
    );
  });
}
