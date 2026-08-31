import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Registry queue mutations are serialized across service instances', () {
    final source = File('lib/hcv_registry_service.dart').readAsStringSync();

    expect(
      source,
      contains('static Future<void> _queueTail = Future<void>.value();'),
    );
    expect(source, contains('Future<T> _withQueueLock<T>'));
    expect(
      source,
      contains(
        'return _withQueueLock(() => _enqueueCertificateFileUnlocked(hcvPath));',
      ),
    );
    expect(
      source,
      contains('return _withQueueLock(_retryPendingUploadsUnlocked);'),
    );
  });

  test('successful upload is confirmed from the primary Registry before dequeue', () {
    final source = File('lib/hcv_registry_service.dart').readAsStringSync();

    expect(source, contains('await _confirmCertificatePublished(hcvId);'));
    expect(
      source,
      contains('await _fetchCertificateFromBase(baseUrl, hcvId)'),
    );
    expect(source, contains("final confirmedId = _extractHcvId(certificate);"));
    expect(source, contains('if (confirmedId != hcvId)'));
    expect(
      source,
      contains('Upload accettato, ma $hcvId non è ancora leggibile dal Registry primario'),
    );
  });
}
