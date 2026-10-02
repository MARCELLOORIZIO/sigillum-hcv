import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public verifier prioritizes signed official-copy V3 over legacy similarity',
      () {
    final verifier = File('lib/registry_verify_page.dart').readAsStringSync();
    final copy = File('lib/registry_verify_copy.dart').readAsStringSync();

    expect(
      verifier,
      contains("import 'hcv_reference_visual_fingerprint_v3.dart';"),
    );
    expect(
      verifier,
      contains("import 'verified_originals_publish_service.dart';"),
    );
    expect(
      verifier,
      contains('_matchesOfficialReferenceVisualFingerprint'),
    );
    expect(
      verifier,
      contains("availability['referenceVisualFingerprint']"),
    );
    expect(
      verifier,
      contains('HCVReferenceVisualFingerprintV3.compare'),
    );

    final forensicDecision = verifier.indexOf('if (forensicVerified)');
    final v3Decision = verifier.indexOf('HCVReferenceVisualVerdict.modified');
    final legacyDecision = verifier.indexOf(
      'videoFingerprintMatches == true',
      v3Decision,
    );
    expect(forensicDecision, greaterThanOrEqualTo(0));
    expect(v3Decision, greaterThan(forensicDecision));
    expect(legacyDecision, greaterThan(v3Decision));

    expect(verifier, contains("'OFFICIAL COPY VERIFIED'"));
    expect(verifier, contains("'OFFICIAL COPY MODIFIED'"));
    expect(verifier, contains("'OFFICIAL COPY INCONCLUSIVE'"));

    for (final key in <String>[
      'officialReferenceConforming',
      'officialReferenceModified',
      'officialReferenceInconclusive',
    ]) {
      expect(RegExp("'$key'").allMatches(copy).length, 4);
    }
  });
}
