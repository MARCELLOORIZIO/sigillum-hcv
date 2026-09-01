import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo verification retries alternate OCR IDs only after Registry 404', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();
    final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

    expect(ocr, contains('extractCandidatesFromImage(String path)'));
    expect(ocr, contains('rankConsensusCandidates(detections)'));

    expect(
      registry,
      contains('_fetchCertificateWithPhotoOcrRecovery(String hcvId)'),
    );
    expect(
      registry,
      contains('originalError.kind != HCVRegistryFailureKind.notFound'),
    );
    expect(
      registry,
      contains('await HCVMediaIdOcr.extractCandidatesFromImage(path)'),
    );
    expect(registry, contains('if (candidate == hcvId) continue;'));
    expect(registry, contains('return await _fetchCertificate(candidate);'));
    expect(
      registry,
      contains(
        'final resolved = await _fetchCertificateWithPhotoOcrRecovery(hcvId);',
      ),
    );

    final helperStart = registry.indexOf(
      '_fetchCertificateWithPhotoOcrRecovery(String hcvId)',
    );
    final helperEnd = registry.indexOf('int _hexDistance', helperStart);
    expect(helperStart, greaterThanOrEqualTo(0));
    expect(helperEnd, greaterThan(helperStart));
    final helper = registry.substring(helperStart, helperEnd);

    expect(helper, contains("lower.endsWith('.jpg')"));
    expect(helper, contains("lower.endsWith('.jpeg')"));
    expect(helper, contains("lower.endsWith('.png')"));
    expect(helper, isNot(contains("lower.endsWith('.mp4')")));
  });
}
