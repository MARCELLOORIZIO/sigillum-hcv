import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capture movement gate', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final probe = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    final geometry =
        File('lib/hcv_scene_geometry_classifier.dart').readAsStringSync();

    test('uses the same movement thresholds as geometry classification', () {
      expect(geometry, contains('bool get movementSufficient'));
      expect(geometry, contains('matchedRegions >= 5'));
      expect(geometry, contains('motionMagnitude >= 0.16'));
      expect(geometry, contains('flowReliability >= 0.46'));
    });

    test('waits for sufficient movement before completing the optical probe', () {
      expect(probe, contains('waitForSufficientMovement'));
      expect(probe, contains('if (geometry.movementSufficient) break'));
      expect(probe, contains('HCVSceneGeometryClassification? geometryOverride'));
      expect(probe, contains('geometryOverride ??'));
    });

    test('photo and video require a second user gesture after probe readiness', () {
      expect(camera, contains("_captureProbeMode != 'photo'"));
      expect(camera, contains("_captureProbeMode != 'video'"));
      expect(camera, contains('await _prepareCaptureProbe(photo: true)'));
      expect(camera, contains('await _prepareCaptureProbe(photo: false)'));
      expect(camera, contains('MOVIMENTO SUFFICIENTE. RIPORTA IL TELEFONO'));
      expect(camera, contains('MOVIMENTO NON SUFFICIENTE. NESSUNO SCATTO ESEGUITO'));
    });

    test('prepared state is visible and capture is disabled during sampling', () {
      expect(camera, contains('!ready || _captureProbeRunning'));
      expect(camera, contains('Icons.check_rounded'));
      expect(camera, contains('_preparedCaptureActionLabel'));
    });
  });
}
