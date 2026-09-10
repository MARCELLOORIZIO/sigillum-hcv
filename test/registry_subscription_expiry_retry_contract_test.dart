import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Registry exposes session and subscription failures explicitly', () {
    final source = File('lib/hcv_registry_service.dart').readAsStringSync();

    expect(source, contains('res.statusCode == 401'));
    expect(source, contains('Sessione Creator scaduta.'));
    expect(source, contains('res.statusCode == 402'));
    expect(source, contains('Abbonamento Creator non attivo.'));
  });

  test('401 and 402 abort retry loop instead of becoming generic pending', () {
    final source = File('lib/hcv_registry_service.dart').readAsStringSync();
    final retryStart = source.indexOf('Future<HCVRegistryRetryReport> _retryPendingUploadsUnlocked() async');
    final authGuard = source.indexOf('if (e.statusCode == 401 || e.statusCode == 402)', retryStart);
    final genericRetry = source.indexOf('if (!e.isRetryable) break;', retryStart);

    expect(retryStart, greaterThanOrEqualTo(0));
    expect(authGuard, greaterThan(retryStart));
    expect(source.indexOf('rethrow;', authGuard), greaterThan(authGuard));
    expect(genericRetry, greaterThan(authGuard));
  });

  test('Certificate remains persistently queued before a retry attempt', () {
    final source = File('lib/hcv_registry_service.dart').readAsStringSync();

    expect(source, contains("static const _pendingUploadsKey = 'hcv_registry_pending_uploads_v1';"));
    expect(source, contains('await _writePendingUploads(pending);'));
    expect(source, contains('Future<HCVRegistryRetryReport> retryPendingUploads()'));
  });
}
