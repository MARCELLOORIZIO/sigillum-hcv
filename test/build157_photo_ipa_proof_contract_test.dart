import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed IPA proof includes PHOTO model alongside V1 V2 V3', () {
    final script = File('tool/build_testflight_ipa_rc2_20260825.sh').readAsStringSync();
    for (final model in [
      'sigillum_screen_replay_v1.tflite',
      'sigillum_screen_replay_v2.tflite',
      'sigillum_screen_replay_v3_multihead.tflite',
      'sigillum_photo_framing_v1.tflite',
    ]) {
      expect(RegExp(RegExp.escape(model)).allMatches(script).length, greaterThanOrEqualTo(2), reason: 'Model must be included in source hash and packaged IPA byte comparison: $model');
    }
    expect(script, contains(r'cmp -s "$SOURCE_FILE" "$BUILT_FILE"'));
    expect(script, contains('BUILT_MODEL_MISMATCH'));
  });
}
