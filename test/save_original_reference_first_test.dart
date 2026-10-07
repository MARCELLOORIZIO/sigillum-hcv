import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save original is reference-first and deletes the clear temporary file', () {
    final source = File('lib/secure_originals_page.dart').readAsStringSync();

    final methodStart = source.indexOf(
      'Future<void> _saveOriginal(HCVSecureOriginalRecord record)',
    );
    final methodEnd = source.indexOf(
      'Future<void> _openOfficialCopy',
      methodStart,
    );
    expect(methodStart, greaterThanOrEqualTo(0));
    expect(methodEnd, greaterThan(methodStart));

    final method = source.substring(methodStart, methodEnd);
    final ensure = method.indexOf('await _publisher.ensureReference(record);');
    final materialize = method.indexOf(
      "materializeOriginal(refreshed, purpose: 'save')",
    );
    final nativeSave = method.indexOf('invokeMethod<bool>');
    final saveMethodName = method.indexOf("'saveMedia'", nativeSave);
    final cleanup = method.indexOf('await _vault.deleteMaterialized(clear);');

    expect(ensure, greaterThanOrEqualTo(0));
    expect(materialize, greaterThan(ensure));
    expect(nativeSave, greaterThan(materialize));
    expect(saveMethodName, greaterThan(nativeSave));
    expect(cleanup, greaterThan(saveMethodName));
  });

  test('iOS native save bridge uses Photos add-only authorization', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('import Photos'));
    expect(source, contains('name: "hcv.photoLibrary"'));
    expect(source, contains('PHPhotoLibrary.requestAuthorization(for: .addOnly)'));
    expect(
      source,
      contains('PHAssetChangeRequest.creationRequestForAssetFromImage'),
    );
    expect(
      source,
      contains('PHAssetChangeRequest.creationRequestForAssetFromVideo'),
    );
  });
}
