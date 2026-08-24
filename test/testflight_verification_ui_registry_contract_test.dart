import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification hub uses top AppBar back navigation and four-language copy', () {
    final source = File('lib/import_page.dart').readAsStringSync();
    expect(source, contains('appBar: AppBar('));
    expect(source, contains("label: Text(_v('verifyText'))"));
    expect(source, contains("label: Text(_v('verifyPhoto'))"));
    expect(source, contains("label: Text(_v('verifyVideo'))"));
    expect(source, isNot(contains('alignment: Alignment.centerLeft')));
  });

  test('Registry public states are localized and severity-colored', () {
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    expect(source, contains("_v('registryNotFoundDetail')"));
    expect(source, contains("_v('registryOriginalHint')"));
    expect(source, contains("_v('notOnline')"));
    expect(source, contains('Color get _overallSeverityColor'));
    expect(source, contains("normalized.contains('forte rischio')"));
    expect(source, contains('_isStrongDisplayRisk || _isInvalidResult || _isMediaNotVerified'));
    expect(source, contains('color: _overallSeverityColor'));
  });

  test('Registry warning copy exists in all supported languages', () {
    final source = File('lib/verification_ui_copy.dart').readAsStringSync();
    expect(RegExp("'registryNotFoundDetail':").allMatches(source).length, 4);
    expect(RegExp("'registryOriginalHint':").allMatches(source).length, 4);
    expect(RegExp("'notOnline':").allMatches(source).length, 4);
    expect(RegExp("'invalidCertificateDetail':").allMatches(source).length, 4);
    expect(RegExp("'mediaNotVerifiedDetail':").allMatches(source).length, 4);
  });
}
