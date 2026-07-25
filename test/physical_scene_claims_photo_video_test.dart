import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo and video both sign physical scene evidence', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    final photoStart = source.indexOf('"captureType": "PHOTO"');
    expect(photoStart, greaterThanOrEqualTo(0));
    final photoEnd = source.indexOf('engine.stop();', photoStart);
    expect(photoEnd, greaterThan(photoStart));
    final photoClaims = source.substring(photoStart, photoEnd);

    final videoStart = source.indexOf('"captureMode": "STANDARD"');
    expect(videoStart, greaterThanOrEqualTo(0));
    final videoEnd = source.indexOf('engine.stop();', videoStart);
    expect(videoEnd, greaterThan(videoStart));
    final videoClaims = source.substring(videoStart, videoEnd);

    expect(photoClaims, contains('"physicalSceneClass"'));
    expect(photoClaims, contains('"geometryChallenge"'));
    expect(videoClaims, contains('"physicalSceneClass"'));
    expect(videoClaims, contains('"geometryChallenge"'));
  });
}
