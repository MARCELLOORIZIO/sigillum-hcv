import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD127 hard negatives are appended to TRAIN only', () {
    final source = File('ml/prepare_dataset.py').readAsStringSync();
    expect(source, contains('--hard-negatives'));
    expect(source, contains('splitRole'));
    expect(source, contains('TRAIN_ONLY'));
    expect(source, contains('/ "train"'));
    expect(source, isNot(contains('/ "val" / class_name / f"hardneg_')));
    expect(source, isNot(contains('/ "test" / class_name / f"hardneg_')));
  });

  test('BUILD127 reference set protects balanced retraining contract', () {
    final manifest = File(
      'ml/hard_negative_sets/build127_texture_hard_negatives_20260921.json',
    ).readAsStringSync();
    expect(manifest, contains('"sourcePhotoCount": 14'));
    expect(manifest, contains('"sourceVideoCount": 2'));
    expect(manifest, contains('"derivedImageCount": 34'));
    expect(manifest, contains('"splitRole": "TRAIN_ONLY"'));
    expect(manifest, contains('HCV-581449500C1846FC'));
    expect(manifest, contains('HCV-CEB513D87E9B4F7D'));
    expect(manifest, contains('HCV-E32D8FB7FB924117'));
    expect(manifest, contains('HCV-5C3AC7391A834F99'));
  });

  test('BUILD127 keeps the bundled ML fallback set before balanced retraining',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('- assets/ml/sigillum_screen_replay_v2.tflite'),
    );
    expect(
      pubspec,
      contains('- assets/ml/sigillum_screen_replay_v3_multihead.tflite'),
    );
    expect(
      pubspec,
      contains('- assets/ml/sigillum_screen_replay_v1.tflite'),
    );
  });
}
