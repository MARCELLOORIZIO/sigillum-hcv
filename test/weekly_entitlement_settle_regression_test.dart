import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verified Apple purchase waits for active or grace server entitlement', () {
    final account =
        File('lib/commercial_account_service.dart').readAsStringSync();

    expect(account, contains('_appleVerificationRetryDelays'));
    expect(account, contains('Duration(milliseconds: 4000)'));
    expect(account, contains('Duration(milliseconds: 8000)'));
    expect(account, contains("final status = result['status']?.toString() ?? '';"));
    expect(
      account,
      contains(
        "if (result['verified'] == true &&\n            (status == 'active' || status == 'grace'))",
      ),
    );

    // Authenticity alone must never grant Creator access. A verified-but-
    // inactive response keeps being reconciled for the bounded retry window.
    expect(
      account,
      isNot(contains(
        "if (result['verified'] == true) {\n          return result;",
      )),
    );
    expect(
      account,
      contains("'verified': false,\n          'status': 'inactive'"),
    );
    expect(
      account,
      isNot(contains("'verified': true,\n          'status': 'active'")),
    );
  });
}
