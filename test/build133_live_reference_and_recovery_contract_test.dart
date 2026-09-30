import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final camera = File('lib/camera_page.dart').readAsStringSync();
  final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();
  final verifier = File('lib/registry_verify_page.dart').readAsStringSync();
  final publisher =
      File('lib/verified_originals_publish_service.dart').readAsStringSync();
  final copy = File('lib/registry_verify_copy.dart').readAsStringSync();
  final audioFingerprint =
      File('lib/hcv_audio_fingerprint.dart').readAsStringSync();
  final secureOriginals =
      File('lib/secure_originals_page.dart').readAsStringSync();
  final manualCompare =
      File('lib/manual_reference_compare_page.dart').readAsStringSync();
  final officialCopyPage =
      File('lib/verified_originals_page.dart').readAsStringSync();

  test('photo and video stage recovery before Registry queue and vault seal',
      () {
    final photoStage = camera.indexOf(
      'await _secureVault.stagePendingSeal(\n'
      "          hcvId: preparedHcvId,",
    );
    final photoQueue = camera.indexOf(
      'await registry.enqueueCertificateFile(File(hcv).absolute.path);',
      photoStage,
    );
    final photoSeal = camera.indexOf(
      'final secured = await _secureVault.seal(',
      photoQueue,
    );

    expect(photoStage, greaterThanOrEqualTo(0));
    expect(photoQueue, greaterThan(photoStage));
    expect(photoSeal, greaterThan(photoQueue));

    final videoStage = camera.indexOf(
      'await _secureVault.stagePendingSeal(\n'
      "        hcvId: detectedId,",
    );
    final videoQueue = camera.indexOf(
      'await registry.enqueueCertificateFile(File(hcv).absolute.path);',
      videoStage,
    );
    final videoSeal = camera.indexOf(
      'final secured = await _secureVault.seal(',
      videoQueue,
    );

    expect(videoStage, greaterThanOrEqualTo(0));
    expect(videoQueue, greaterThan(videoStage));
    expect(videoSeal, greaterThan(videoQueue));
  });

  test('recovery re-enqueues certificates after a hard-kill seal recovery', () {
    final recoveryStart =
        camera.indexOf('Future<void> _recoverPendingSecureOriginals()');
    final recoveryEnd = camera.indexOf(
        'Future<void> _retryPendingRegistryUploads()', recoveryStart);
    final recovery = camera.substring(recoveryStart, recoveryEnd);

    expect(recovery, contains('final beforeIds ='));
    expect(recovery, contains('recoverPendingSeals()'));
    expect(recovery, contains('_secureVault.list()'));
    expect(
      recovery,
      contains('.where((record) => !beforeIds.contains(record.hcvId))'),
    );
    expect(recovery, contains('registry.enqueueCertificateFile'));
    expect(recovery, contains('unawaited(_retryPendingRegistryUploads())'));
  });

  test('Protected Originals recovery also restores the Registry outbox', () {
    final reloadStart = secureOriginals.indexOf('Future<void> _reload()');
    final reloadEnd = secureOriginals.indexOf(
      'Future<void> _retryRecoveredRegistryUploads()',
      reloadStart,
    );
    final reload = secureOriginals.substring(reloadStart, reloadEnd);

    expect(reload, contains('final beforeIds ='));
    expect(reload, contains('recoverPendingSeals()'));
    expect(
      reload,
      contains('records.where((record) => !beforeIds.contains(record.hcvId))'),
    );
    expect(reload, contains('_registry.enqueueCertificateFile'));
    expect(reload, contains('unawaited(_retryRecoveredRegistryUploads())'));

    final retryStart = secureOriginals.indexOf(
      'Future<void> _retryRecoveredRegistryUploads()',
    );
    final retryEnd = secureOriginals.indexOf(
      'Future<void> _view(',
      retryStart,
    );
    final retry = secureOriginals.substring(retryStart, retryEnd);
    expect(retry, contains('_registry.retryPendingUploads()'));
  });

  test('vault exposes durable staging and clears deterministic stale journals',
      () {
    expect(vault, contains('Future<void> stagePendingSeal({'));
    final sealStart = vault.indexOf('Future<HCVSecureOriginalRecord> seal({');
    final sealEnd =
        vault.indexOf('Future<int> recoverPendingSeals()', sealStart);
    final seal = vault.substring(sealStart, sealEnd);

    expect(seal, contains('await stagePendingSeal('));
    expect(
      seal.indexOf('await stagePendingSeal('),
      lessThan(seal.indexOf('final mediaHash = await _sha256File(media);')),
    );
    expect(
      seal,
      contains(
        "await _removePendingSeal(cleanId);\n"
        "      throw StateError('SECURE_VAULT_HCV_CONFLICT');",
      ),
    );

    final recoveryStart = vault.indexOf('Future<int> recoverPendingSeals()');
    final recoveryEnd = vault.indexOf(
      'Future<List<HCVSecureOriginalRecord>> list()',
      recoveryStart,
    );
    final recovery = vault.substring(recoveryStart, recoveryEnd);
    expect(recovery, contains('await _removePendingSeal(hcvId);'));
  });

  test(
      'social verification requires a live YouTube reference before V3 verdict',
      () {
    expect(
      publisher,
      contains(
        "'/api/verified-originals/\$hcvId/verification-reference'",
      ),
    );
    expect(verifier, contains('.verificationReference(hcvId)'));
    expect(verifier, contains("availability['youtubeLive'] == true"));
    expect(
      verifier,
      isNot(contains("availability['commentsDisabled'] == true")),
    );
    expect(verifier, contains("result = 'OFFICIAL REFERENCE UNAVAILABLE';"));
    expect(
      verifier,
      contains("value == 'OFFICIAL COPY VERIFIED'"),
    );
    expect(
      verifier,
      contains("'verificationTiming'"),
    );
  });

  test('protected original export fails closed when live reference is stale',
      () {
    final ensureStart = publisher.indexOf(
      'Future<VerifiedOriginalPublishResult> ensureReference(',
    );
    final ensureEnd = publisher.indexOf(
      'Future<VerifiedSubtitlePublishResult> ensureSubtitleReference(',
      ensureStart,
    );
    final method = publisher.substring(ensureStart, ensureEnd);

    final publicLookup = method.indexOf('publicAvailability(record.hcvId)');
    final liveLookup = method.indexOf('verificationReference(record.hcvId)');
    final existingReference = method.indexOf('_existingReference(record)');

    expect(publicLookup, greaterThanOrEqualTo(0));
    expect(liveLookup, greaterThan(publicLookup));
    expect(method, contains("live['youtubeLive'] == true"));
    expect(
      method,
      isNot(contains("live['commentsDisabled'] == true")),
    );
    expect(
      method,
      contains("StateError('REFERENCE_PLATFORM_UNAVAILABLE')"),
    );
    expect(existingReference, greaterThan(liveLookup));
  });

  test('HCVPACK export revalidates the live YouTube reference', () {
    final packStart = camera.indexOf('Future<void> sharePackage() async');
    final packEnd =
        camera.indexOf('String get _createdContentLabel', packStart);
    final method = camera.substring(packStart, packEnd);

    final localReferenceGate = method.indexOf('!securedRecord.hasReference');
    final liveReferenceGate =
        method.indexOf('_publisher.verificationReference(securedRecord.hcvId)');
    final materialize = method.indexOf('materializeHcvpack(');
    final share = method.indexOf('Share.shareXFiles(', materialize);

    expect(packStart, greaterThanOrEqualTo(0));
    expect(localReferenceGate, greaterThanOrEqualTo(0));
    expect(liveReferenceGate, greaterThan(localReferenceGate));
    expect(method, contains("live['youtubeLive'] == true"));
    expect(
      method,
      isNot(contains("live['commentsDisabled'] == true")),
    );
    expect(materialize, greaterThan(liveReferenceGate));
    expect(share, greaterThan(materialize));
  });

  test('extensionless Messenger media is routed by magic bytes', () {
    final router = File('lib/hcv_import_router_page.dart').readAsStringSync();

    expect(router, contains('_normalizeExtensionlessMedia(path)'));
    expect(router, contains('bytes[0] == 0xff'));
    expect(router, contains('bytes[1] == 0xd8'));
    expect(router, contains('bytes[2] == 0xff'));
    expect(router, contains('bytes[0] == 0x89'));
    expect(router, contains('bytes[1] == 0x50'));
    expect(router, contains('bytes[2] == 0x4e'));
    expect(router, contains('bytes[3] == 0x47'));
    expect(router, contains('bytes[4] == 0x66'));
    expect(router, contains('bytes[5] == 0x74'));
    expect(router, contains('bytes[6] == 0x79'));
    expect(router, contains('bytes[7] == 0x70'));
    expect(router, contains("extension = '.jpg'"));
    expect(router, contains("extension = '.png'"));
    expect(router, contains("extension = '.mp4'"));
  });

  test('manual comparison remains subscriber-only and live-reference gated',
      () {
    expect(
      publisher,
      contains(
          'Future<Map<String, dynamic>> entitledLiveReference(String hcvId)'),
    );
    final methodStart = publisher.indexOf(
      'Future<Map<String, dynamic>> entitledLiveReference(String hcvId)',
    );
    final methodEnd = publisher.indexOf(
      'Future<String> _ensureConsent',
      methodStart,
    );
    final entitled = publisher.substring(methodStart, methodEnd);
    expect(entitled, contains('verificationReference(hcvId)'));
    expect(entitled, contains("live['youtubeLive'] == true"));
    expect(
      entitled,
      isNot(contains("live['commentsDisabled'] == true")),
    );
    expect(entitled, contains("'/api/verified-originals/\$hcvId/view'"));
    expect(entitled, contains('authenticated: true'));

    expect(
      manualCompare,
      contains('CommercialAccountService().billingStatus()'),
    );
    expect(
      manualCompare,
      contains("billing['status']?.toString() != 'active'"),
    );
    expect(
      manualCompare,
      contains('_publisher.entitledLiveReference(widget.hcvId)'),
    );
    expect(manualCompare, contains('VideoPlayerController.file(media)'));
    expect(manualCompare, contains('target = Uri.https('));
    expect(manualCompare, contains("'t':"));
    expect(manualCompare, contains('LaunchMode.externalApplication'));

    expect(verifier, contains('ManualReferenceComparePage('));
    expect(verifier, contains("_r('manualCompareAction')"));
    expect(
      officialCopyPage,
      contains('_publisher.entitledLiveReference(id)'),
    );
  });

  test('manual comparison copy is localized in all four languages', () {
    for (final key in <String>[
      'manualCompareTitle',
      'manualCompareAction',
      'manualCompareSubscriberOnly',
      'manualCompareIntro',
      'manualCompareAutomaticVerdict',
      'manualCompareLocalTitle',
      'manualCompareOfficialTitle',
      'manualCompareVideoHelp',
      'manualComparePhotoHelp',
      'manualCompareOpenOfficial',
      'manualCompareOpenAtTime',
      'manualCompareSubscriptionRequired',
      'manualCompareReferenceUnavailable',
      'manualCompareMediaUnavailable',
      'manualCompareLoadError',
      'manualCompareOpenError',
    ]) {
      expect(
        RegExp("'$key'").allMatches(copy).length,
        4,
        reason: 'Expected four localized entries for $key',
      );
    }
  });

  test('audio fingerprint extraction is capped to the analyzed window', () {
    expect(audioFingerprint, contains('_maxAnalyzedSeconds = 15.0'));
    expect(audioFingerprint, contains("-t \$_maxAnalyzedSeconds"));
    expect(audioFingerprint, contains('_maxFrames = 29'));
    expect(audioFingerprint, contains('_hopSamples = sampleRate ~/ 2'));
  });

  test('new live-reference UI copy is localized in all four languages', () {
    for (final key in <String>[
      'officialReferenceConformingTitle',
      'officialReferenceModifiedTitle',
      'officialReferenceInconclusiveTitle',
      'officialReferenceUnavailableTitle',
      'officialReferenceUnavailable',
      'officialReferenceUnavailableDetail',
      'verificationTiming',
      'techReferenceVerification',
    ]) {
      expect(
        RegExp("'$key'").allMatches(copy).length,
        4,
        reason: 'Expected four localized entries for $key',
      );
    }
  });
}
