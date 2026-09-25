import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vault is bound to authenticated server account as well as Creator', () {
    final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();

    expect(vault, contains('ownerAccountSubjectHash'));
    expect(vault, contains('SECURE_VAULT_ACCOUNT_CONTEXT_UNAVAILABLE'));
    expect(vault, contains('SECURE_VAULT_ACCOUNT_MISMATCH'));
    expect(vault, contains("sigillum.auth.account.id.v1"));
    expect(auth, contains("accountIdStoreKey = 'sigillum.auth.account.id.v1'"));
    expect(auth, contains("raw['id']"));
    expect(
        auth, contains('HCVSecureStore.write(accountIdStoreKey, accountId)'));
    expect(auth, contains('HCVSecureStore.delete(accountIdStoreKey)'));
  });

  test('plaintext lifecycle stays out of iOS Documents and is crash-cleaned',
      () {
    final watermark =
        File('lib/hcv_location_video_watermark.dart').readAsStringSync();
    final package = File('lib/hcv_package.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final engine = File('lib/hcv_engine.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(watermark, contains('getApplicationSupportDirectory()'));
    expect(
        package, contains('final outputDir = await getTemporaryDirectory()'));
    expect(camera, contains('CAMERA_SOURCE_PLAINTEXT_DELETE_FAILED'));
    expect(
        engine, contains('if (await logFile.exists()) await logFile.delete()'));
    expect(
      engine,
      contains('await _attachCaptureProvenance(await getTemporaryDirectory())'),
    );
    expect(main, contains('purgeMaterializedPlaintext()'));
  });

  test('reference reuse is hash-bound and HCVPACK hash is device-signed', () {
    final source =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();

    expect(source, contains('originalContentSha256 != record.mediaSha256'));
    expect(source, contains('serverHcvpackSha256 != record.hcvpackSha256'));
    expect(source, contains('derivedFrom != record.mediaSha256'));
    expect(source, contains('SIGILLUM_HCVPACK_BINDING_V1'));
    expect(source, contains('X-Sigillum-Hcvpack-Signature'));
    expect(source, contains('HCVKeystoreSigner.sign(packageStatement)'));
  });

  test('withdrawal remains local-pending until platform confirms takedown', () {
    final source =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();

    final status = source.indexOf("takedown != 'COMPLETED'");
    final clear = source.indexOf('await vault.clearReference(record.hcvId)');
    expect(status, greaterThanOrEqualTo(0));
    expect(clear, greaterThan(status));
  });

  test('current in-memory video package pipeline has a hard size ceiling', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    expect(camera, contains('_maxSecureVideoBytes = 200 * 1024 * 1024'));
    expect(camera, contains('VIDEO_EXCEEDS_SECURE_PIPELINE_LIMIT_200_MIB'));
  });

  test('Photos permission text no longer claims canonical originals are saved',
      () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('copie derivate'));
    expect(plist, contains('L’originale certificato resta'));
    expect(
      plist,
      isNot(contains('SIGILLUM salva video verificati nella libreria')),
    );
  });
  test(
      'protected originals show secure previews and direct protected selection',
      () {
    final page = File('lib/secure_originals_page.dart').readAsStringSync();
    final preview =
        File('lib/hcv_secure_preview_service.dart').readAsStringSync();
    final verified =
        File('lib/verified_originals_page.dart').readAsStringSync();
    final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();

    expect(page, contains('FutureBuilder<File?>'));
    expect(page, contains('_recordDate(record)'));
    expect(page, contains('selectionMode'));
    expect(preview, contains('sigillum_secure_previews'));
    expect(preview, contains('FFmpegKit.execute'));
    expect(preview, contains('copyResize'));
    expect(vault, contains("'sigillum_secure_previews'"));
    expect(verified, contains('_pickProtected'));
    expect(verified, contains('SecureOriginalsPage('));
    expect(verified, contains('selectionMode: true'));
  });

  test('HCVPACK binding signature interpolates actual record values', () {
    final source =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();
    expect(
        source,
        contains(
            r'SIGILLUM_HCVPACK_BINDING_V1|${record.hcvId}|${record.mediaSha256}|${record.hcvpackSha256}'));
    expect(
        source,
        isNot(contains(
            r'SIGILLUM_HCVPACK_BINDING_V1|\${record.hcvId}|\${record.mediaSha256}|\${record.hcvpackSha256}')));
  });
}
