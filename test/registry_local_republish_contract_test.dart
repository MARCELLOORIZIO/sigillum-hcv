import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry verification contains local signed-certificate recovery', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains('_fetchCertificateWithLocalRecovery'));
    expect(source, contains('retryPendingUploads'));
    expect(source, contains('uploadCertificateFile(localCertificate.path)'));
    expect(source, contains("lower.endsWith('.hcv')"));
  });
}
