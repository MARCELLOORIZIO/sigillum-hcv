import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo and video both sign physical scene evidence', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(RegExp(r'"physicalSceneClass"').allMatches(source).length, 2);
    expect(RegExp(r'"geometryChallenge"').allMatches(source).length, 2);
  });
}
