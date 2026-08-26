import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text certification saves signed text claims and HCVPACK', () {
    final source = File('lib/text_cert_page.dart').readAsStringSync();
    expect(source, contains("HCVTextIntegrity.fromText(text)"));
    expect(source, contains("'textIntegrity': textIntegrity.toJson()"));
    expect(source, contains('HCVTextPackage.create('));
    expect(source, contains('packagePath = finalPackagePath'));
    expect(source, contains('HCVTextArtifactStore.outputDirectory()'));
  });

  test(
    'published social text uses visible HCV-ID and has a verification page',
    () {
      final source = File('lib/text_cert_page.dart').readAsStringSync();
      final verifier = File('lib/text_social_verify_page.dart')
          .readAsStringSync();
      expect(source, contains('HCVTextIntegrity.buildSocialText'));
      expect(source, contains('VERIFICA TESTO PUBBLICATO'));
      expect(source, contains('TextSocialVerifyPage('));
      expect(verifier, contains('_registry.fetchCertificate(id)'));
      expect(verifier, contains('HCVTextPackage.read(packagePath)'));
      expect(verifier, contains('_verifier.verifyFile(tempFile.path)'));
    },
  );

  test('iOS text HCVPACK picker stays selectable and validates extension after selection', () {
    final verifier = File('lib/text_social_verify_page.dart')
        .readAsStringSync();
    expect(verifier, contains('if (Platform.isIOS)'));
    expect(verifier, contains('type: FileType.any'));
    expect(
      verifier,
      contains("p.extension(packagePath).toLowerCase() != '.hcvpack'"),
    );
    expect(verifier, contains("allowedExtensions: const ['hcvpack']"));
    expect(verifier, contains('Select an HCVPACK file (.hcvpack).'));
  });

  test('text workflow patch cannot alter camera or display classifiers', () {
    final patch = File('tool/apply_text_social_verification.py')
        .readAsStringSync();
    expect(patch, isNot(contains("Path('lib/camera_page.dart')")));
    expect(patch, isNot(contains('hcv_live_screen_probe')));
    expect(patch, isNot(contains('hcv_display_risk_fusion')));
    expect(patch, isNot(contains('hcv_scene_geometry_classifier')));
  });
}
