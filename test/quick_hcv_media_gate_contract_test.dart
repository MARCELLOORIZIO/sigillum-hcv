import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo and video use one-frame HCV precheck before Registry verification', () {
    final router = File('lib/hcv_import_router_page.dart').readAsStringSync();
    final gate = File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();

    expect(router, contains("import 'quick_hcv_media_gate_page.dart';"));
    expect(router, contains('QuickHcvMediaGatePage('));
    expect(gate, contains("'seconds': 0.2"));
    expect(gate, isNot(contains("'seconds': 0.8")));
    expect(gate, contains("import 'verification_ui_copy.dart';"));
    expect(
      gate,
      contains(
        'String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);',
      ),
    );
    expect(gate, contains("_status = _v('notCertified');"));
    expect(gate, contains("_status = _v('idDetected');"));
    expect(gate, isNot(contains('_isItalian')));
    expect(gate, contains('cropHeight'));
    expect(gate, contains('width: 1280'));
    expect(gate, isNot(contains('/private/var/mobile/')));
  });
}
