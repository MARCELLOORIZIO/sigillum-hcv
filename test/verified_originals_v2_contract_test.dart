import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical camera media is sealed instead of exported to Photos', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(camera, contains("import 'hcv_secure_media_vault.dart';"));
    expect(camera, contains('await _secureVault.seal('));
    expect(camera, contains("mediaType: 'photo'"));
    expect(camera, contains("mediaType: 'video'"));
    expect(camera, contains('expectedMediaSha256: hash'));
    expect(camera, contains('expectedMediaSha256: videoHash'));

    expect(
      camera,
      isNot(contains('await saveContentToGallery(publishedPhoto);')),
    );
    expect(
      camera,
      isNot(contains('await saveContentToGallery(savedVideoPath);')),
    );
  });

  test('secure vault uses authenticated AES-256-GCM and Keychain-backed secret',
      () {
    final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();

    expect(vault, contains('AesGcm.with256bits()'));
    expect(vault, contains("HCVSecureStore.read(_masterKeyStoreKey)"));
    expect(vault, contains("HCVSecureStore.write(_masterKeyStoreKey"));
    expect(vault, contains("static const int _chunkSize = 4 * 1024 * 1024"));
    expect(vault, contains('mac: Mac(macBytes)'));
    expect(vault, contains('SECURE_VAULT_PLAINTEXT_HASH_MISMATCH'));
    expect(vault,
        contains('if (await destination.exists()) await destination.delete()'));
    expect(vault, contains("throw StateError('SECURE_VAULT_HCV_CONFLICT')"));
    expect(vault, contains('final mediaTag = mediaHash.substring(0, 16)'));
    expect(vault, contains('if (!committed)'));
    expect(vault, contains('await media.delete();'));
    expect(vault, contains('await pack.delete();'));
  });

  test('social export is fail closed behind the official reference', () {
    final page = File('lib/secure_originals_page.dart').readAsStringSync();
    final publisher =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();

    final referenceIndex = page.indexOf('await _publisher.ensureReference(');
    final socialMaterializeIndex =
        page.indexOf("purpose: 'social'", referenceIndex);
    final shareIndex =
        page.indexOf('Share.shareXFiles(', socialMaterializeIndex);

    expect(referenceIndex, greaterThanOrEqualTo(0));
    expect(socialMaterializeIndex, greaterThan(referenceIndex));
    expect(shareIndex, greaterThan(socialMaterializeIndex));

    expect(publisher, contains("'hcvpackSha256': record.hcvpackSha256"));
    expect(publisher, contains('/api/verified-originals/publish/'));
    expect(publisher, isNot(contains('www.googleapis.com')));
    expect(publisher, isNot(contains('YOUTUBE_CLIENT_SECRET')));
  });

  test('display-risk classifier is evidence, not a publication gate', () {
    final page = File('lib/secure_originals_page.dart').readAsStringSync();
    final publisher =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();

    for (final source in [page, publisher]) {
      expect(source,
          isNot(contains("displayRiskDecision == 'NO_DISPLAY_EVIDENCE'")));
      expect(source, isNot(contains('STRONG_DISPLAY_RISK')));
      expect(source, isNot(contains('NON_CONCLUSIVE')));
    }
  });

  test('Verified Originals accepts file selection as well as HCV-ID', () {
    final source = File('lib/verified_originals_page.dart').readAsStringSync();

    expect(source, contains('FilePicker.platform.pickFiles('));
    expect(source, contains('HCVImportRouterPage('));
    expect(source, contains("_t('voSelectFile')"));
    expect(source, contains("_t('voFindId')"));
  });

  test('legacy per-file publication page is no longer linked from Creator home',
      () {
    final home = File('lib/user_home_page.dart').readAsStringSync();

    expect(home, contains('SecureOriginalsPage(languageCode: languageCode)'));
    expect(home, isNot(contains('VerifiedOriginalsConsentPage')));
    expect(home, isNot(contains('verified_originals_consent_page.dart')));
  });

  test('caption workflow materializes encrypted video only temporarily', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(camera, contains("purpose: 'caption-source'"));
    expect(
      camera,
      contains('await _secureVault.deleteMaterialized(materializedSource)'),
    );
    expect(camera, contains("_secureOriginalRecord?.mediaType == 'video'"));
  });

  test('published reference can be withdrawn without deleting HCV verification',
      () {
    final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();
    final publisher =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();
    final page = File('lib/secure_originals_page.dart').readAsStringSync();

    expect(vault, contains('Future<void> clearReference(String hcvId) async'));
    expect(
      publisher,
      contains(r'/api/verified-originals/consents/${record.hcvId}/withdraw'),
    );
    expect(publisher, contains('await vault.clearReference(record.hcvId)'));
    expect(page, contains("_t('secureOriginalsWithdraw')"));
    expect(page, contains('await _publisher.withdrawReference(record)'));
  });

  test('account removal erases the local encrypted vault and its key', () {
    final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();
    final profile = File('lib/commercial_profile_page.dart').readAsStringSync();

    expect(vault, contains('Future<void> wipeLocalVault() async'));
    expect(vault, contains('await HCVSecureStore.delete(_masterKeyStoreKey)'));
    expect(profile,
        contains('await const HCVSecureMediaVault().wipeLocalVault()'));
  });

  test('new closed-chain user copy exists in all four languages', () {
    final copy = File('lib/sigillum_localization.dart').readAsStringSync();

    for (final key in <String>[
      'secureOriginalsTitle',
      'secureOriginalsShareDisclosure',
      'secureOriginalsRightsConfirm',
      'secureOriginalsPublishingReference',
      'secureOriginalsShareBlocked',
      'verifiedOriginalsSubtitle',
      'verifiedOriginalsAction',
      'voPageTitle',
      'voSelectFile',
      'voSubscriptionRequired',
    ]) {
      expect(
        RegExp("'$key'").allMatches(copy).length,
        4,
        reason: '$key must exist for IT, EN, ES and RU',
      );
    }
  });
}
