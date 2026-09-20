import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BUILD125 HFR zoom parity', () {
    test('camera UI caps zoom at 15x across all reinitialization paths', () {
      final source = File('lib/camera_page.dart').readAsStringSync();

      expect(source, isNot(contains('clamp(minZoom, 10.0)')));
      expect(source, isNot(contains('clamp(newMinZoom, 10.0)')));
      expect(
        RegExp(r'clamp\(minZoom, 15\.0\)').allMatches(source).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        RegExp(r'clamp\(newMinZoom, 15\.0\)').allMatches(source).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('selected Flutter zoom is passed to native HFR capture', () {
      final source = File('lib/camera_page.dart').readAsStringSync();

      expect(source, contains('requestedZoomFactor: savedZoom'));
      expect(
        source,
        contains(
          "probe = await const HCVTemporalFrequencyProbe().captureNative(",
        ),
      );
    });

    test('temporal probe forwards requested zoom over method channel', () {
      final source =
          File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();

      expect(source, contains('double requestedZoomFactor = 1.0'));
      expect(
        source,
        contains("'requestedZoomFactor': requestedZoomFactor"),
      );
    });

    test('native HFR clamps requested zoom to 15x and hardware capability', () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(
        source,
        contains('args?["requestedZoomFactor"] as? Double ?? 1.0'),
      );
      expect(source, contains('captureDevice.maxAvailableVideoZoomFactor'));
      expect(source, contains('captureDevice.activeFormat.videoMaxZoomFactor'));
      expect(
          source, contains('captureDevice.videoZoomFactor = appliedHfrZoom'));
      expect(source, contains('min(15.0,'));
    });

    test('native HFR certifies requested and actually applied zoom', () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(source, contains('"requestedZoomFactor": requestedZoom'));
      expect(
        source,
        contains(
            '"appliedHfrZoomFactor": Double(captureDevice.videoZoomFactor)'),
      );
      expect(source, contains('"hfrZoomMaximum": hfrZoomMaximum'));
      expect(source, contains('"zoomParityExact":'));
    });

    test('BUILD124 multi-evidence decision policy remains unchanged', () {
      final source =
          File('lib/hcv_multi_evidence_display_policy.dart').readAsStringSync();

      expect(source, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
      expect(source, contains('BUILD124_PHOTO_MULTI_EVIDENCE_DISPLAY'));
      expect(source, contains('BUILD124_VIDEO_MULTI_EVIDENCE_DISPLAY'));
      expect(source,
          contains('ABSENCE_OF_DISPLAY_PROOF_IS_NOT_POSITIVE_REALITY_PROOF'));
    });
  });
}
