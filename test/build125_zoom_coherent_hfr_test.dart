import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BUILD125 zoom-coherent HFR contract', () {
    test('user-facing zoom cap is 15x everywhere camera is initialized', () {
      final source = File('lib/camera_page.dart').readAsStringSync();

      expect(source, isNot(contains('clamp(minZoom, 10.0)')));
      expect(source, isNot(contains('clamp(newMinZoom, 10.0)')));
      expect(
        RegExp(r'clamp\((?:newMinZoom|minZoom), 15\.0\)')
            .allMatches(source)
            .length,
        greaterThanOrEqualTo(3),
      );
    });

    test('native HFR receives the zoom selected by the user', () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      final probe =
          File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();

      expect(
        camera,
        contains('requestedZoomFactor: savedZoom'),
      );
      expect(
        probe,
        contains("'requestedZoomFactor': requestedZoomFactor"),
      );
    });

    test('HFR zoom is applied after high-speed activeFormat selection', () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      final formatIndex =
          source.indexOf('captureDevice.activeFormat = selection.format');
      final zoomIndex = source
          .indexOf('captureDevice.videoZoomFactor = CGFloat(clampedZoom)');

      expect(formatIndex, greaterThanOrEqualTo(0));
      expect(zoomIndex, greaterThan(formatIndex));
      expect(source, contains('captureDevice.minAvailableVideoZoomFactor'));
      expect(source, contains('captureDevice.maxAvailableVideoZoomFactor'));
    });

    test('certificate exposes requested effective and clamped HFR zoom', () {
      final dart =
          File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
      final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      for (final field in <String>[
        'requestedZoomFactor',
        'effectiveZoomFactor',
        'hfrMinAvailableZoomFactor',
        'hfrMaxAvailableZoomFactor',
        'zoomClampedForHfr',
        'zoomMatchWithinTolerance',
        'zoomSpatialEquivalence',
      ]) {
        expect(dart, contains("'$field'"));
        expect(swift, contains('"$field"'));
      }
    });

    test('physical-device substitution is attested against original device',
        () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(
        source,
        contains(
          'physicalDeviceSubstitutionUsed =\n          captureDevice.uniqueID != device.uniqueID',
        ),
      );
      expect(
        source,
        isNot(
          contains(
            'let physicalDevice = temporalFrequencyPhysicalDevice(for: device)',
          ),
        ),
      );
      expect(
        source,
        contains('captureTemporalFrequencyNative(\n        device: device,'),
      );
    });

    test('BUILD124 thresholds remain while HFR gains a final FOV guard', () {
      final source =
          File('lib/hcv_multi_evidence_display_policy.dart').readAsStringSync();

      expect(source, contains('BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY'));
      expect(source, contains('BUILD124_PHOTO_MULTI_EVIDENCE_DISPLAY'));
      expect(source, contains('BUILD124_VIDEO_MULTI_EVIDENCE_DISPLAY'));
      expect(source, contains('still.probability >= 0.90'));
      expect(source, contains('aggregate.probability >= 0.80'));
      expect(source, contains('aggregate.probability >= 0.65'));
      expect(source, contains("probe['hfrSpatialComparability'] == 'COMPARABLE'"));
    });
  });
}
