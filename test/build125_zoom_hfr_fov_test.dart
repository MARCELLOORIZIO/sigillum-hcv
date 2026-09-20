import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('BUILD125 zoom/HFR field of view', () {
    test('real native probe channel receives the user requested zoom', () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      final probe = File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();

      expect(camera, contains('requestedZoomFactor: savedZoom'));
      expect(probe, contains("'requestedZoomFactor': requestedZoomFactor"));
      expect(probe, contains("'nativeHfrEffectiveZoomFactor'"));
      expect(probe, contains("'zoomFieldOfViewComparable'"));
      expect(camera, contains('"nativeHfrZoomFieldOfViewComparable"'));
      expect(camera, contains('"captureZoomFactor"'));
    });

    test('zoom limit is capped dynamically at 15 rather than fixed 10', () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      expect(camera, isNot(contains('clamp(minZoom, 10.0)')));
      expect(camera, isNot(contains('clamp(newMinZoom, 10.0)')));
      expect(camera, contains('deviceMaxZoom.clamp(minZoom, 15.0)'));
      expect(camera, contains('deviceMaxZoom.clamp(newMinZoom, 15.0)'));
    });

    test('native session applies zoom after selecting high speed format', () {
      final native = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      final format = native.indexOf('captureDevice.activeFormat = selection.format');
      final apply = native.indexOf('captureDevice.videoZoomFactor = CGFloat(appliedNativeZoom)');
      final metadata = native.indexOf('"nativeHfrEffectiveZoomFactor": nativeHfrEffectiveZoom');

      expect(format, greaterThan(-1));
      expect(apply, greaterThan(format));
      expect(metadata, greaterThan(apply));
      expect(native, contains('"physicalDeviceSubstitutionUsed": physicalDeviceSubstituted'));
      expect(native, contains('"zoomFieldOfViewComparable": zoomComparable'));
      expect(native, contains('"nativeHfrMaximumZoomFactor": maximumNativeZoom'));
      expect(native, contains('"nativeHfrZoomClamped"'));
    });

    test('HFR full frame on mismatched FOV cannot override REALITY photo', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(comparable: false),
        stillMl: _stillReality(),
        temporalMl: null,
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('HFR 5-of-9 on mismatched FOV cannot promote screen-like video', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(comparable: false, fullFrame: false),
        ml: _weakScreenVideo(),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.reasons, contains('ABSENCE_OF_DISPLAY_PROOF_IS_NOT_POSITIVE_REALITY_PROOF'));
    });

    test('matched HFR still promotes physical full-frame display', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(comparable: true),
        stillMl: _stillReality(),
        temporalMl: null,
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('strong independent ML can still prove DISPLAY if HFR mismatches', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(comparable: false),
        stillMl: <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': 0.99,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 99,
            'contentAreaRiskScore': 90,
          },
        },
        temporalMl: null,
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('baseline historical HFR without zoom metadata is compatible', () {
      final probe = _hfr(comparable: true)
        ..remove('zoomFieldOfViewComparable');
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: probe,
        stillMl: _stillReality(),
        temporalMl: null,
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });
  });
}

Map<String, dynamic> _hfr({required bool comparable, bool fullFrame = true}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'zoomFieldOfViewComparable': comparable,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrame,
        'displayLikeCellCount': 5,
        'realityLikeCellCount': 0,
        'spatialFamilyCellCount': 9,
        'harmonicAwareSpatialFamilyCellCount': 9,
        'rowTimeFamilyCellCount': 9,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': 6,
        'stableCellCount': 5,
        'medianCellPeriodicityStrength': 0.18,
      },
    };

Map<String, dynamic> _stillReality() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'REALITY_ROOM',
      'screenProbability': 0.1,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 10,
        'contentAreaRiskScore': 10,
      },
    };

Map<String, dynamic> _weakScreenVideo() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.71,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (final score in <int>[71, 64])
          <String, dynamic>{
            'predictedClass': 'SCREEN_MONITOR',
            'signals': <String, dynamic>{'fullFrameRiskScore': score},
          },
      ],
    };
