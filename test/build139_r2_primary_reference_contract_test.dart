import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final publisher =
      File('lib/verified_originals_publish_service.dart').readAsStringSync();
  final reference =
      File('lib/verified_originals_reference.dart').readAsStringSync();
  final vault = File('lib/hcv_secure_media_vault.dart').readAsStringSync();
  final verifier = File('lib/registry_verify_page.dart').readAsStringSync();
  final camera = File('lib/camera_page.dart').readAsStringSync();
  final originals = File('lib/secure_originals_page.dart').readAsStringSync();
  final discovery = File('lib/verified_originals_page.dart').readAsStringSync();
  final manual =
      File('lib/manual_reference_compare_page.dart').readAsStringSync();
  final viewer =
      File('lib/verified_reference_viewer_page.dart').readAsStringSync();

  test('R2 reference model accepts private short-lived references only', () {
    expect(reference, contains("platform == 'r2'"));
    expect(
      reference,
      contains("referenceAccess == 'SHORT_LIVED_AUTHORIZATION'"),
    );
    expect(reference, contains("!json.containsKey('publicUrl')"));
    expect(reference, contains("!json.containsKey('platformPostId')"));
    expect(reference, contains('bool get isPrivateR2'));
  });

  test('publisher uses provider-neutral live gate and authenticated R2 read',
      () {
    expect(publisher, contains("live['referenceLive'] == true"));
    expect(publisher, contains("live['youtubeLive'] == true"));
    expect(
      publisher,
      contains("'/api/verified-originals/$hcvId/read-authorization'"),
    );
    expect(
      publisher,
      contains("'/api/verified-originals/reference-read/'"),
    );
    expect(publisher, contains("'Bearer $token'"));
    expect(publisher, contains('sha256.bind(target.openRead()).first'));
    expect(
      publisher,
      contains("StateError('REFERENCE_DOWNLOADED_SHA256_MISMATCH')"),
    );
  });

  test('vault no longer requires a permanent public URL for R2', () {
    final start = vault.indexOf('bool get hasReference');
    final end = vault.indexOf('Map<String, dynamic> toJson()', start);
    final hasReference = vault.substring(start, end);
    expect(hasReference, contains('publicationId'));
    expect(hasReference, contains('referenceSha256'));
    expect(hasReference, isNot(contains('referenceUrl')));
    expect(vault, contains('String? referenceUrl'));
  });

  test('verification and HCVPACK export use provider-neutral live status', () {
    expect(verifier, contains("availability['referenceLive'] == true"));
    expect(verifier, contains("availability['youtubeLive'] == true"));
    expect(verifier, contains("availability['providerCheckMs']"));
    expect(camera, contains("live['referenceLive'] == true"));
    expect(camera, contains("live['youtubeLive'] == true"));
  });

  test('R2 official references stay inside SIGILLUM', () {
    expect(
      discovery,
      contains('_publisher.materializeEntitledReference(id)'),
    );
    expect(
      originals,
      contains('_publisher.materializeEntitledReference(record.hcvId)'),
    );
    expect(
      manual,
      contains('_publisher.materializeEntitledReference(widget.hcvId)'),
    );
    expect(discovery, contains('VerifiedReferenceViewerPage('));
    expect(originals, contains('VerifiedReferenceViewerPage('));
    expect(manual, contains('VerifiedReferenceViewerPage('));
    expect(viewer, contains('VideoPlayerController.file(widget.file)'));
    expect(viewer, contains('Image.file('));
    expect(viewer, contains('_deleteTemporaryReference()'));
  });
}
