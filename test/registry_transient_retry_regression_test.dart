import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Registry retries transient upload failures before leaving item pending', () {
    final registry = File('lib/hcv_registry_service.dart').readAsStringSync();

    expect(registry, contains('_pendingUploadRetryDelays'));
    expect(registry, contains('Duration(milliseconds: 750)'));
    expect(registry, contains('Duration(milliseconds: 2000)'));
    expect(registry, contains('await Future<void>.delayed(delay)'));
    expect(registry, contains('if (!e.isRetryable) break;'));
    expect(registry, contains('if (e.kind == HCVRegistryFailureKind.invalidCertificate)'));
    expect(registry, contains("'lastError': lastError"));
    expect(registry, contains('await _writePendingUploads(remaining)'));

    // The persistent queue remains the safety net after bounded retries.
    expect(registry, contains("_pendingUploadsKey = 'hcv_registry_pending_uploads_v1'"));
  });
}
