import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final camera = File('lib/camera_page.dart').readAsStringSync();
  final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();
  final verifier = File('lib/registry_verify_page.dart').readAsStringSync();
  final publisher =
      File('lib/verified_originals_publish_service.dart').readAsStringSync();
  final copy = File('lib/registry_verify_copy.dart').readAsStringSync();

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

    expect(recovery, contains('recoverPendingSeals()'));
    expect(recovery, contains('_secureVault.list()'));
    expect(recovery, contains('registry.enqueueCertificateFile'));
    expect(recovery, contains('unawaited(_retryPendingRegistryUploads())'));
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
    expect(verifier, contains("availability['commentsDisabled'] == true"));
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
