import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capture movement gate without detector changes', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final probe = File('lib/hcv_live_screen_probe_core.dart').readAsStringSync();
    final geometry =
        File('lib/hcv_scene_geometry_classifier.dart').readAsStringSync();

    test('monitor probe remains the original implementation', () {
      expect(probe, isNot(contains('waitForSufficientMovement')));
      expect(probe, isNot(contains('geometryOverride')));
      expect(
        probe,
        contains('final geometry = _analyzeGeometry(<_FrameStats>['),
      );
      expect(geometry, isNot(contains('movementSufficient')));
    });

    test('movement gate only reads the original probe result', () {
      expect(
        camera,
        contains(
          'final analysis = await _analyzeLiveScreenProbeWithoutFlash();',
        ),
      );
      expect(
        camera,
        contains("final rawGeometry = analysis['geometryChallenge'];"),
      );
      expect(camera, contains('matchedRegions >= 5'));
      expect(camera, contains('motionMagnitude >= 0.16'));
      expect(camera, contains('flowReliability >= 0.46'));
      expect(camera, isNot(contains('geometryOverride')));
    });

    test(
      'insufficient movement never captures and sufficient movement needs a second tap',
      () {
        expect(camera, contains("_captureProbeMode != 'photo'"));
        expect(camera, contains("_captureProbeMode != 'video'"));
        expect(
          camera,
          contains(
            'MOVIMENTO NON SUFFICIENTE. NESSUNO SCATTO ESEGUITO',
          ),
        );
        expect(
          camera,
          contains('MOVIMENTO SUFFICIENTE. RIPORTA IL TELEFONO'),
        );
      },
    );

    test('probe instruction appears only in the upper status badge', () {
      expect(camera, contains('child: _statusBadge()'));
      expect(camera, isNot(contains('_preparedCaptureActionLabel')));
      expect(
        camera,
        isNot(contains('? _physicalProbeStatus')),
      );
    });
  });
}
