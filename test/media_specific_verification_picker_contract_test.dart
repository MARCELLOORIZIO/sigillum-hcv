import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification uses Files for documents and Photos for photo/video', () {
    final source = File('lib/import_page.dart').readAsStringSync();

    expect(source, contains("import 'package:image_picker/image_picker.dart';"));
    expect(source, contains("allowedExtensions: const ['hcvpack', 'hcv', 'txt', 'pdf']"));
    expect(source, contains('pickImage(source: ImageSource.gallery)'));
    expect(source, contains('pickVideo(source: ImageSource.gallery)'));
    expect(source, contains('onPressed: pickDocument'));
    expect(source, contains('onPressed: pickPhoto'));
    expect(source, contains('onPressed: pickVideo'));
    expect(source, isNot(contains('type: FileType.any')));
  });
}
