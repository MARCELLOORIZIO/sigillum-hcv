import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification chooser keeps back navigation in the AppBar', () {
    final source = File('lib/import_page.dart').readAsStringSync();
    expect(source, contains('appBar: AppBar('));
    expect(source, contains('leading: IconButton('));
    expect(source, contains('Icons.arrow_back_rounded'));
    expect(source, contains("_v('verifyText')"));
    expect(source, contains("_v('verifyPhoto')"));
    expect(source, contains("_v('verifyVideo')"));
  });

  test('quick verification gate follows the selected four-language copy', () {
    final source = File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();
    expect(source, contains('VerificationUiCopy.t(widget.languageCode, key)'));
    expect(source, isNot(contains('_isItalian')));
    expect(source, contains("_v('notCertified')"));
    expect(source, contains("_v('idDetected')"));
  });

  test('Registry public result never exposes raw Italian internal status', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    final start = source.indexOf('String get _publicResultDetail');
    final end = source.indexOf('@override\n  Widget build', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final publicResult = source.substring(start, end);
    expect(publicResult, contains("_v('registryNotFound')"));
    expect(publicResult, contains("_v('registryUnavailable')"));
    expect(publicResult, isNot(contains('return status;')));
  });

  test('verification result color follows severity before verified state', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains('_hasSevereVerificationIssue'));
    expect(source, contains('_hasIntermediateVerificationIssue'));
    expect(source, contains('if (_hasSevereVerificationIssue) return Colors.red;'));
    expect(source, contains('if (_hasIntermediateVerificationIssue) return Colors.orange;'));
    expect(source, contains('if (isVerified) return Colors.green;'));
    expect(source, contains('color: _verificationResultColor'));
  });

  test('commercial Registry keeps production first and legacy read compatibility', () {
    final source = File('lib/hcv_registry_service.dart').readAsStringSync();
    expect(source, contains("defaultValue: 'https://sigillum-registry-production.onrender.com'"));
    expect(source, contains("_legacyReadBaseUrl = 'https://hcv-registry-server.onrender.com'"));
    expect(source, contains('_fetchCertificateFromBase(baseUrl, cleaned)'));
    expect(source, contains('_fetchCertificateFromBase(_legacyReadBaseUrl, cleaned)'));
  });
}
