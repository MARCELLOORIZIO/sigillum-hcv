import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RC2 photo HCVPACK v3 is media-neutral and legacy v2 remains readable', () {
    final package = File('lib/hcv_package.dart').readAsStringSync();
    final player = File('lib/hcvpack_player_page.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(package, contains('Future<String> createPhotoPackage({'));
    expect(package, contains("'version': 3"));
    expect(package, contains("'mediaType': 'photo'"));
    expect(package, contains("'contentFile': contentFile"));
    expect(package, contains("'contentSha256': contentSha256"));
    expect(camera, contains('createPhotoPackage('));
    expect(camera, contains('photoPath: publishedPhoto'));

    expect(player, contains('version != 2 && version != 3'));
    expect(player, contains('meta["videoFile"] != "video.mp4"'));
    expect(player, contains('meta["contentSha256"] != contentSha256'));
    expect(player, contains("contentFile.startsWith('photo.')"));
  });

  test('iOS photo verification reads the original Photos asset resource', () {
    final importPage = File('lib/import_page.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(importPage, contains("MethodChannel('hcv.media')"));
    expect(importPage, contains('Platform.isIOS'));
    expect(importPage, contains("invokeMethod<String>('pickOriginalPhoto')"));

    expect(scene, contains('PHPickerViewControllerDelegate'));
    expect(scene, contains('call.method == "pickOriginalPhoto"'));
    expect(scene, contains('PHAssetResource.assetResources(for: asset)'));
    expect(scene, contains('PHAssetResourceManager.default().writeData('));
    expect(scene, contains('options.isNetworkAccessAllowed = true'));
  });
}
