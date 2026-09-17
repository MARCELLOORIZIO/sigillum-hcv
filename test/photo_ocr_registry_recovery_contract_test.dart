import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo Registry recovery is 404-driven, OCR-first and bounded', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();
    final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();

    expect(ocr, contains('extractCandidatesFromImage(String path)'));
    expect(ocr, contains('buildRegistryRecoveryVariants('));
    expect(ocr, contains("'0' => 'C'"));
    expect(ocr, contains("'C' => '0'"));
    expect(ocr, contains('maxVariants = 16'));

    expect(registry, contains('_fetchCertificateExact('));
    expect(
      registry,
      contains('_fetchCertificateWithPhotoOcrRecovery(String hcvId)'),
    );
    expect(
      registry,
      contains('await HCVMediaIdOcr.extractCandidatesFromImage(path)'),
    );
    expect(
      registry,
      contains('HCVMediaIdOcr.buildRegistryRecoveryVariants('),
    );
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
    expect(helper, contains('return await _fetchCertificateExact(hcvId);'));
    expect(helper, contains('candidateError.kind == HCVRegistryFailureKind.notFound'));
    expect(helper, contains('maxVariants: 16'));
    expect(helper, isNot(contains('_b8Variants(')));
    expect(helper, isNot(contains('_fetchCertificate(candidate)')));

    final firstExact = helper.indexOf('_fetchCertificateExact(hcvId)');
    final robustOcr = helper.indexOf('extractCandidatesFromImage(path)');
    final boundedVariants = helper.indexOf('buildRegistryRecoveryVariants(');
    final pendingRetry = helper.indexOf('registry.retryPendingUploads()');
    expect(firstExact, greaterThanOrEqualTo(0));
    expect(robustOcr, greaterThan(firstExact));
    expect(boundedVariants, greaterThan(robustOcr));
    expect(pendingRetry, greaterThan(boundedVariants));

    // Video/text keep their existing path; this fix is PHOTO-only.
    expect(
      helper,
      contains('return await _fetchCertificateWithLocalRecovery(hcvId);'),
    );
  });
}
