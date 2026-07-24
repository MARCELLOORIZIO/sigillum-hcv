import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sigillum_iphone/hcv_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recovery automatically binds the locally stored legacy Stripe session',
      () async {
    SharedPreferences.setMockInitialValues({
      'hcv_kyc_session_id': 'vs_legacy_session_123456',
      'hcv_kyc_legal_name': 'Verified Creator',
    });

    final requests = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final body = jsonDecode(raw) as Map<String, dynamic>;
      requests.add({'path': request.uri.path, 'body': body});
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/identity/kyc/recover') {
        request.response.write(jsonEncode({'ok': true, 'found': false}));
      } else if (request.uri.path == '/api/identity/kyc/bind') {
        request.response.write(jsonEncode({
          'ok': true,
          'found': true,
          'legacyMigration': true,
          'sessionId': 'vs_legacy_session_123456',
          'provider': 'stripe_identity',
          'status': 'verified',
          'verified': true,
          'verifiedOutputs': {
            'legalName': 'Verified Creator',
            'country': 'IT',
          },
        }));
      } else {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({'error': 'NOT_FOUND'}));
      }
      await request.response.close();
    });

    try {
      final registry = HCVRegistryService(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      final result = await registry.recoverKycSession(
        creatorId: 'ACC-DETERMINISTIC',
        creatorName: 'Local iPhone Creator',
        deviceKeyFingerprint: 'device-fingerprint',
        publicKey: const {
          'modulus': 'LOCAL_DEV_PUBLIC_KEY',
          'exponent': 'LOCAL_DEV',
        },
      );

      expect(result['found'], isTrue);
      expect(result['legacyMigration'], isTrue);
      expect(
        requests.map((request) => request['path']),
        <String>[
          '/api/identity/kyc/recover',
          '/api/identity/kyc/bind',
        ],
      );
      final bindBody = requests.last['body'] as Map<String, dynamic>;
      expect(bindBody['sessionId'], 'vs_legacy_session_123456');
      expect(bindBody['accountId'], 'ACC-DETERMINISTIC');
      expect(bindBody['creatorName'], 'Verified Creator');
      expect(bindBody['signature'], isNotEmpty);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test('generic local creator names never trigger legacy binding', () async {
    SharedPreferences.setMockInitialValues({
      'hcv_kyc_session_id': 'vs_legacy_session_123456',
    });

    var requestCount = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      requestCount++;
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'ok': true, 'found': false}));
      await request.response.close();
    });

    try {
      final registry = HCVRegistryService(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      final result = await registry.recoverKycSession(
        creatorId: 'ACC-DETERMINISTIC',
        creatorName: 'Local iPhone Creator',
        deviceKeyFingerprint: 'device-fingerprint',
        publicKey: const {
          'modulus': 'LOCAL_DEV_PUBLIC_KEY',
          'exponent': 'LOCAL_DEV',
        },
      );

      expect(result['found'], isFalse);
      expect(requestCount, 1);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
