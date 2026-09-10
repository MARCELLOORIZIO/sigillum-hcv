import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared photos keep original filename information', () {
    final source = File('ios/SigillumShareExtension/ShareViewController.swift')
        .readAsStringSync();

    expect(source, contains('provider.suggestedName'));
    expect(source, contains('originalName: suggestedName'));
    expect(source, contains('url.lastPathComponent'));
  });

  test('photo quick gate stays bounded while Registry keeps deep OCR recovery', () {
    final quickGate = File('lib/quick_hcv_media_gate_page.dart')
        .readAsStringSync();
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();

    final quickStart = quickGate.indexOf('Future<void> _runPrecheck() async');
    final idDetected = quickGate.indexOf(
      "_status = _v('idDetected');",
      quickStart,
    );
    expect(quickStart, greaterThanOrEqualTo(0));
    expect(idDetected, greaterThan(quickStart));
    final quickPath = quickGate.substring(quickStart, idDetected);

    expect(quickPath, contains('final isPhoto'));
    expect(quickPath, contains('allowFocusedFallback: true'));
    expect(quickPath, isNot(contains('await _openRegistry();')));

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
      contains('originalError.kind != HCVRegistryFailureKind.notFound'),
    );
  });
}
