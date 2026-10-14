import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subtitle-save uses the captioned status independent of generated filename', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('Future<bool> saveContentToGallery(String path, {bool isCaptionedVideo = false}) async {'));
    expect(source, contains("final isCaptioned = isCaptionedVideo || lower.contains('_sottotitolato');"));
    expect(source, contains('saveContentToGallery(clear.path, isCaptionedVideo: true)'));
    expect(source, contains("? _c('captionedSavedPhotos')"));
    expect(source, contains("? _c('captionedAvailableFiles')"));
  });
}
