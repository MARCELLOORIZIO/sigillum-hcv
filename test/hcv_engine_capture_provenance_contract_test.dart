import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HCVEngine binds D2 provenance before root payload and signature', () {
    final source = File('lib/hcv_engine.dart').readAsStringSync();

    expect(source, contains("import 'hcv_capture_provenance.dart';"));
    expect(source, contains('claims["captureSource"] != "HCV_CAMERA"'));
    expect(source, contains('hcvId: hcvId'));
    expect(source, contains('sessionId: sessionId'));
    expect(source, contains('"provenance": binding.toClaim(hcvId: hcvId)'));

    final attachIdentity = source.indexOf('await _attachIdentity();');
    final attachProvenance =
        source.indexOf('await _attachCaptureProvenance(dir);');
    final computeRoot = source.indexOf('final rootHash = _computeRootHash();');
    final buildPayload =
        source.indexOf('final signedPayload = _buildSignedPayload(');
    final signPayload = source.indexOf('HCVKeystoreSigner.sign(canonical)');

    expect(attachIdentity, greaterThanOrEqualTo(0));
    expect(attachProvenance, greaterThan(attachIdentity));
    expect(computeRoot, greaterThan(attachProvenance));
    expect(buildPayload, greaterThan(computeRoot));
    expect(signPayload, greaterThan(buildPayload));
  });

  test('D2 integration does not modify camera capture orchestration', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(camera, isNot(contains("import 'hcv_capture_provenance.dart';")));
    expect(
        camera, contains('final hash = sha256.convert(fileBytes).toString();'));
    expect(camera,
        contains('final videoHash = sha256.convert(videoBytes).toString();'));
    expect(camera, contains('"captureSource": "HCV_CAMERA"'));
    expect(camera,
        contains('"captureCreatedAt": capturedAt.toUtc().toIso8601String()'));
    expect(
      camera,
      contains(
        '"captureCreatedAt": effectiveCapturedAt.toUtc().toIso8601String()',
      ),
    );
  });
}
