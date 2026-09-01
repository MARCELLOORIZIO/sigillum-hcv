import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS OCR preflights UIKit decoding before invoking ML Kit', () {
    final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();

    expect(
        ocr,
        contains(
            "static const MethodChannel _mediaChannel = MethodChannel('hcv.media')"));
    expect(ocr, contains("'validateImageForOcr'"));
    expect(ocr, contains('if (decodable != true) return null;'));
    expect(ocr, contains('InputImage.fromFilePath(path)'));
    expect(
      ocr.indexOf("'validateImageForOcr'"),
      lessThan(ocr.indexOf('InputImage.fromFilePath(path)')),
    );

    expect(scene, contains('call.method == "validateImageForOcr"'));
    expect(scene, contains('UIImage(contentsOfFile: path)'));
    expect(scene, contains('result(image != nil)'));
  });

  test(
      'share extension rejects undecodable image representations before handoff',
      () {
    final share = File(
      'ios/SigillumShareExtension/ShareViewController.swift',
    ).readAsStringSync();

    expect(share, contains('private func isImageType(_ type: String) -> Bool'));
    expect(share, contains('UIImage(contentsOfFile: url.path) == nil'));
    expect(share,
        contains('provider.loadItem(forTypeIdentifier: type, options: nil)'));
    expect(share, contains('let image = UIImage(data: data)'));
    expect(share, contains('let image = UIImage(data: swiftData)'));
  });
}
