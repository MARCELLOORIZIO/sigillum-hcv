import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HCV imports are gated before legacy verification pages', () {
    final router = File('lib/hcv_import_router_page.dart').readAsStringSync();

    expect(router, contains("import 'hcvpack_provenance_gate_page.dart';"));
    expect(router, contains("import 'hcv_file_provenance_gate_page.dart';"));
    expect(router, contains('HCVPackProvenanceGatePage('));
    expect(router, contains('HCVFileProvenanceGatePage('));
    expect(router, isNot(contains("import 'hcvpack_player_page.dart';")));
    expect(router, isNot(contains("import 'verify_page.dart';")));
  });

  test('registry provenance verifier binds exact certificate and content', () {
    final source = File('lib/hcv_registry_provenance.dart').readAsStringSync();

    for (final token in <String>[
      'SIGILLUM_REGISTRY_VERIFIED',
      'LEGACY_REGISTRY_RECORD',
      'REGISTRY_ATTESTATION_INVALID',
      'certificateSha256',
      'contentSha256',
      'accountSubjectHash',
      'creatorId',
      'deviceKeyFingerprint',
      'identityVerified',
      'registeredAt',
      'bindingVersion',
      'attestationSha256',
      'registryCertificateSha256 != localCertificateSha256',
      'registeredContentSha256 != contentSha256',
      'registeredCreatorId != creatorId',
      'registeredDeviceFingerprint != deviceKeyFingerprint',
      'expectedAttestationSha256 != attestationSha256',
    ]) {
      expect(source, contains(token), reason: 'missing provenance contract: $token');
    }
  });

  test('HCVPACK cannot reach HUMAN VERIFIED player without registry v2', () {
    final source =
        File('lib/hcvpack_provenance_gate_page.dart').readAsStringSync();

    final gate = source.indexOf('if (provenance.registryVerifiedV2)');
    final legacyPlayer = source.indexOf('HCVPackPlayerPage(', gate);
    expect(gate, greaterThanOrEqualTo(0));
    expect(legacyPlayer, greaterThan(gate));
    expect(source, contains('HCV INTEGRITY VERIFIED'));
    expect(source, contains('PROVENIENZA NON VERIFICATA'));
  });

  test('standalone HCV cannot reach old VALID page without registry v2', () {
    final source =
        File('lib/hcv_file_provenance_gate_page.dart').readAsStringSync();

    final gate = source.indexOf('if (provenance.registryVerifiedV2)');
    final verifyPage = source.indexOf('VerifyPage(', gate);
    expect(gate, greaterThanOrEqualTo(0));
    expect(verifyPage, greaterThan(gate));
    expect(source, contains('HCV INTEGRITY VERIFIED'));
    expect(source, contains('PROVENIENZA NON VERIFICATA'));
  });
}
