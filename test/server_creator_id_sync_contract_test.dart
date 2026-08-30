import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server creator ID is persisted as the account identity source', () {
    final identity = File('lib/hcv_identity.dart').readAsStringSync();
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();

    expect(identity, contains('Future<void> saveCreatorId(String creatorId)'));
    expect(identity, contains("await prefs.setString(_creatorIdKey, normalized);"));

    expect(auth, contains('Future<void> _syncServerCreatorId('));
    expect(auth, contains("final creatorId = raw['creatorId']?.toString().trim() ?? '';"));
    expect(auth, contains('await HCVIdentity().saveCreatorId(creatorId);'));

    final restore = auth.indexOf("_request('GET', '/api/auth/session'");
    final login = auth.indexOf("'POST',\n      '/api/auth/login'");
    final syncCalls = RegExp(r'await _syncServerCreatorId\(response\);')
        .allMatches(auth)
        .map((match) => match.start)
        .toList();

    expect(restore, greaterThanOrEqualTo(0));
    expect(login, greaterThanOrEqualTo(0));
    expect(syncCalls.length, greaterThanOrEqualTo(3));
    expect(syncCalls.any((position) => position > restore), isTrue);
    expect(syncCalls.any((position) => position > login), isTrue);
  });

  test('server sync does not change the device signing key', () {
    final identity = File('lib/hcv_identity.dart').readAsStringSync();
    final start = identity.indexOf('Future<void> saveCreatorId');
    final end = identity.indexOf('Future<void> saveCreatorName', start);
    final method = identity.substring(start, end);

    expect(method, isNot(contains('HCVKeystoreSigner')));
    expect(method, isNot(contains('_deviceIdKey')));
    expect(method, contains('_creatorIdKey'));
  });
}
