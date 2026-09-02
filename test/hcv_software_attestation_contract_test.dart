import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('D3 software identity is injected before HCV certificate signing', () {
    final engine = File('lib/hcv_engine.dart').readAsStringSync();
    final releaseBuilder =
        File('tool/build_testflight_ipa_rc2_20260825.sh').readAsStringSync();

    expect(engine, contains("import 'hcv_software_attestation.dart';"));
    expect(
      engine,
      contains('"softwareAttestation": HCVSoftwareAttestation.current()'),
    );
    expect(engine, contains('_attachSoftwareAttestation();'));

    final attachIndex = engine.indexOf('_attachSoftwareAttestation();');
    final payloadIndex = engine.indexOf('final signedPayload = _buildSignedPayload(');
    expect(attachIndex, greaterThanOrEqualTo(0));
    expect(payloadIndex, greaterThan(attachIndex));

    expect(releaseBuilder, contains(r'BUILD_COMMIT="$(git rev-parse HEAD)"'));
    expect(
      releaseBuilder,
      contains(r'--dart-define=GIT_COMMIT="$BUILD_COMMIT"'),
    );
  });
}
