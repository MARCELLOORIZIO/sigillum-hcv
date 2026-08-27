import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS photo verification survives limited Photos access without losing exact originals', () {
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(scene, contains('import UniformTypeIdentifiers'));
    expect(scene, contains('private func copyPickerPhotoRepresentation('));
    expect(
      scene,
      contains('provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier)'),
    );
    expect(scene, contains('copyPickerPhotoRepresentation(selection)'));

    // Exact PHAsset bytes remain the preferred path whenever PhotoKit can
    // resolve the user-selected asset, preserving SIGILLUM hash verification.
    expect(scene, contains('PHAssetResource.assetResources(for: asset)'));
    expect(
      scene,
      contains('PHAssetResourceManager.default().writeData('),
    );
    expect(scene, contains('options.isNetworkAccessAllowed = true'));

    // PHPicker itself must not be blocked by read/write Photos authorization:
    // a user-picked image is still readable through its item provider when
    // PhotoKit access is limited or the PHAsset cannot be fetched.
    final pickStart = scene.indexOf(
      'private func pickOriginalPhoto(result: @escaping FlutterResult)',
    );
    final pickEnd = scene.indexOf(
      'private func finishOriginalPhotoPick(_ value: Any?)',
      pickStart,
    );
    expect(pickStart, greaterThanOrEqualTo(0));
    expect(pickEnd, greaterThan(pickStart));
    final pickerBlock = scene.substring(pickStart, pickEnd);
    expect(
      pickerBlock,
      isNot(contains('PHPhotoLibrary.requestAuthorization(for: .readWrite)')),
    );

    final fetchStart = scene.indexOf(
      'let assets = PHAsset.fetchAssets(withLocalIdentifiers:',
    );
    expect(fetchStart, greaterThanOrEqualTo(0));
    final fallbackAfterFetch = scene.indexOf(
      'copyPickerPhotoRepresentation(selection)',
      fetchStart,
    );
    expect(fallbackAfterFetch, greaterThan(fetchStart));

    expect(
      scene,
      isNot(contains('Selected Photos asset was not found')),
    );
    expect(scene, isNot(contains('PHOTO_ASSET_NOT_FOUND')));
  });
}
