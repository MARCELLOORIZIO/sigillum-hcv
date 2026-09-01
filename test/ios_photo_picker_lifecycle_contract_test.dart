import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS original-photo picker cannot remain globally busy after selection', () {
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(scene, contains('private func takePendingOriginalPhotoResult() -> FlutterResult?'));
    expect(scene, contains('pendingOriginalPhotoResult = nil'));
    expect(scene, contains('PHOTO_PICK_STALE_RESET'));
    expect(scene, contains('presenter.presentedViewController is PHPickerViewController'));

    final delegateStart = scene.indexOf(
      'func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult])',
    );
    expect(delegateStart, greaterThanOrEqualTo(0));
    final delegateBlock = scene.substring(delegateStart);
    final takeIndex = delegateBlock.indexOf('takePendingOriginalPhotoResult()');
    final resolveIndex = delegateBlock.indexOf('resolveOriginalPhotoSelection(');
    expect(takeIndex, greaterThanOrEqualTo(0));
    expect(resolveIndex, greaterThan(takeIndex));

    expect(
      scene,
      contains('resolveOriginalPhotoSelection(results, result: flutterResult)'),
    );
    expect(
      scene,
      contains('copyPickerPhotoRepresentation(selection, result: result)'),
    );
  });
}
