import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restored unpaid sessions return to public home only at bootstrap', () {
    final source = File('lib/commercial_gate.dart').readAsStringSync();

    expect(source, contains('this.initialBillingMode = false'));
    expect(
      source,
      contains(
        'returnToLandingIfUnpaid: !widget.initialBillingMode',
      ),
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
      'returnToLandingIfUnpaid: !widget.initialBillingMode'
          .allMatches(source)
          .length,
      1,
      reason:
          'Ordinary app bootstrap returns unpaid sessions to public home, while an explicit premium-feature entry opens billing.',
    );
    expect(
      source,
      contains('this.returnAfterSubscriptionActivation = false'),
    );
    expect(
      source,
      contains('serverActive && widget.returnAfterSubscriptionActivation'),
    );
  });
}
