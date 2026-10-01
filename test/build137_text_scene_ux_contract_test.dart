import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BUILD137 text and social scene UX', () {
    final textPage = File('lib/text_cert_page.dart').readAsStringSync();
    final textVerify =
        File('lib/text_social_verify_page.dart').readAsStringSync();
    final verifier =
        File('lib/registry_verify_page.dart').readAsStringSync();
    final copy = File('lib/verification_ui_copy.dart').readAsStringSync();

    test('published-text verification and reset are above generated file paths', () {
      expect(textPage, contains('Widget _verificationAndResetActions()'));
      final actions = textPage.indexOf('_verificationAndResetActions(),');
      final createdFiles = textPage.indexOf('_createdFilesCard(),');
      expect(actions, greaterThanOrEqualTo(0));
      expect(createdFiles, greaterThan(actions));
      expect(textPage, contains('VERIFICA TESTO PUBBLICATO'));
      expect(textPage, contains("label: Text(_t('newText'))"));
    });

    test('text verification remains Registry/hash based and does not publish to YouTube', () {
      expect(textPage, contains('HCVTextIntegrity.fromText(text)'));
      expect(textVerify, contains('_registry.fetchCertificate(id)'));
      expect(textVerify, contains('HCVTextIntegrity.comparePublishedText'));
      expect(textPage.toLowerCase(), isNot(contains('youtube')));
      expect(textVerify.toLowerCase(), isNot(contains('youtube')));
      expect(textVerify, isNot(contains('ManualReferenceComparePage')));
    });

    test('verified official social copy shows signed scene assessment of original', () {
      expect(
        verifier,
        contains(
          '_isNonExactPhotoOrVideo && _isOfficialReferenceVerified',
        ),
      );
      expect(verifier, contains("_v('originalScene')"));
      expect(verifier, contains("_v('originalSceneHint')"));
      expect(verifier, contains("_v('originalSceneCopyQualifier')"));
      expect(
        verifier,
        contains(
          "_isNonExactPhotoOrVideo && !_canShowCertifiedOriginalScene",
        ),
      );
    });

    test('original scene copy is complete in all selectable languages', () {
      for (final key in <String>[
        "'originalScene':",
        "'originalSceneHint':",
        "'originalSceneCopyQualifier':",
      ]) {
        expect(RegExp(RegExp.escape(key)).allMatches(copy).length, 4);
      }
    });
  });
}
