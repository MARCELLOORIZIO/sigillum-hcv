import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification picker patch enforces Files and Photos split', () {
    final patch = File(
      'tool/apply_media_specific_verification_picker_fix_20260822.py',
    ).readAsStringSync();

    expect(patch, contains("import 'package:image_picker/image_picker.dart';"));
    expect(
      patch,
      contains("allowedExtensions: const ['hcvpack', 'hcv', 'txt', 'pdf']"),
    );
    expect(patch, contains('pickImage(source: ImageSource.gallery)'));
    expect(patch, contains('pickVideo(source: ImageSource.gallery)'));
    expect(patch, contains('onPressed: pickDocument'));
    expect(patch, contains('onPressed: pickPhoto'));
    expect(patch, contains('onPressed: pickVideo'));
    expect(
      patch,
      contains(
        "if 'type: FileType.any' in source:\n    raise RuntimeError('generic FileType.any picker still present in verification page')",
      ),
    );
  });
}
