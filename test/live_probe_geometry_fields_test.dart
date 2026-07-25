import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live probe includes geometry metrics needed for field tests', () {
    final source = File('lib/hcv_scene_geometry_classifier.dart').readAsStringSync();
    for (final field in <String>[
      'motionMagnitude',
      'flowReliability',
      'directionCoherence',
      'depthDispersion',
      'planarCoherence',
      'matchedRegions',
    ]) {
      expect(source, contains(field));
    }
  });
}
