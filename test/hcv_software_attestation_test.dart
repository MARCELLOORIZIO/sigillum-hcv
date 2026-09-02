import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_software_attestation.dart';

void main() {
  test('D3 binds a valid Git SHA-1 into the software attestation', () {
    const commit = '1fe680665ac1cec7a4e749149413cd63a45fe0c7';
    final attestation = HCVSoftwareAttestation.fromValues(
      sourceCommit: commit.toUpperCase(),
      edition: 'user',
    );

    expect(attestation['type'], 'SIGILLUM_SOFTWARE_ATTESTATION');
    expect(attestation['version'], 1);
    expect(attestation['status'], 'BOUND');
    expect(attestation['sourceCommit'], commit);
    expect(attestation['sourceCommitAlgorithm'], 'GIT_SHA1');
    expect(attestation['edition'], 'user');
    expect(HCVSoftwareAttestation.isValid(attestation), isTrue);
  });

  test('D3 accepts a future Git SHA-256 identifier', () {
    final commit = List<String>.filled(64, 'a').join();
    final attestation = HCVSoftwareAttestation.fromValues(
      sourceCommit: commit,
      edition: 'user',
    );

    expect(attestation['status'], 'BOUND');
    expect(attestation['sourceCommitAlgorithm'], 'GIT_SHA256');
    expect(HCVSoftwareAttestation.isValid(attestation), isTrue);
  });

  test('D3 marks missing or malformed source identity as unbound', () {
    final attestation = HCVSoftwareAttestation.fromValues(
      sourceCommit: 'not-a-git-commit',
      edition: 'dev',
    );

    expect(attestation['status'], 'UNBOUND');
    expect(attestation.containsKey('sourceCommit'), isFalse);
    expect(attestation.containsKey('sourceCommitAlgorithm'), isFalse);
    expect(HCVSoftwareAttestation.isValid(attestation), isTrue);
  });

  test('D3 rejects inconsistent attestation payloads', () {
    final malformed = <String, dynamic>{
      'type': HCVSoftwareAttestation.schema,
      'version': HCVSoftwareAttestation.schemaVersion,
      'status': 'BOUND',
      'bindingMethod': HCVSoftwareAttestation.bindingMethod,
      'sourceCommit': 'invalid',
      'sourceCommitAlgorithm': 'GIT_SHA1',
      'edition': 'user',
    };

    expect(HCVSoftwareAttestation.isValid(malformed), isFalse);
  });
}
