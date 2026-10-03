import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subtitle export no longer asks for monetization consent', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    final start = camera
        .indexOf('Future<_SubtitleExportDecision?> _subtitleExportDecision()');
    final end = camera.indexOf(
        'Future<HCVSecureOriginalRecord?> _ensureSubtitleReferenceForExport()',
        start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final dialog = camera.substring(start, end);
    expect(dialog, contains("_c('subtitleExportTitle')"));
    expect(dialog, isNot(contains('secureOriginalsMonetization')));
    expect(dialog, isNot(contains('SwitchListTile')));
    expect(camera, isNot(contains('monetizationConsent')));

    final publisher =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();
    expect(publisher, contains("'monetizationConsent': false"));
    expect(publisher, contains("'monetizationEnabled': 'false'"));
    expect(publisher, isNot(contains('bool monetizationConsent')));
  });

  test('subtitle verification accepts only a registered authorized derivation',
      () {
    final verifier = File('lib/registry_verify_page.dart').readAsStringSync();

    expect(verifier, contains("availability['authorizedDerivations']"));
    expect(verifier, contains("entry['referenceRole'] != 'DERIVED_REFERENCE'"));
    expect(verifier, contains("entry['editorialImpact'] != 'caption_overlay'"));
    expect(
      verifier,
      contains("'subtitle_burn_in_reference_v1'"),
    );
    expect(
      verifier,
      contains("'AUTHORIZED SUBTITLE DERIVATIVE VERIFIED'"),
    );
    expect(
      verifier,
      contains("audioFingerprintMatches != false"),
      reason: 'authorized captioned video must still preserve certified audio',
    );
    expect(
      verifier,
      contains("_isAuthorizedSubtitleDerivative"),
    );
  });

  test('authorized subtitle copy exists in all four languages', () {
    final copy = File('lib/registry_verify_copy.dart').readAsStringSync();
    final cameraCopy =
        File('lib/camera_ui_extended_copy.dart').readAsStringSync();

    for (final key in <String>[
      'authorizedSubtitleConforming',
      'authorizedSubtitleConformingTitle',
      'authorizedSubtitleConformingDetail',
      'authorizedSubtitleProvenanceState',
      'authorizedSubtitleIntegrityState',
      'authorizedSubtitleSceneState',
      'authorizedSubtitleDerivationState',
    ]) {
      expect(
        RegExp("'$key'").allMatches(copy).length,
        4,
        reason: '$key must exist for IT, EN, ES and RU',
      );
    }

    expect(
      RegExp("'subtitleExportTitle'").allMatches(cameraCopy).length,
      4,
    );
  });
}
