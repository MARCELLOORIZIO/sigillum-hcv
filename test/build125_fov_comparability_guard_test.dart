import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('BUILD125 final HFR FOV comparability guard', () {
    test('pre-HFR native state is snapshotted before Flutter camera dispose',
        () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      final handoff =
          camera.indexOf('_captureTemporalFrequencyNativeIsolated() async');
      final snapshot = camera.indexOf('snapshotNativeCameraState(', handoff);
      final dispose = camera.indexOf('await active.dispose()', snapshot);

      expect(handoff, greaterThanOrEqualTo(0));
      expect(snapshot, greaterThan(handoff));
      expect(dispose, greaterThan(snapshot));
      expect(camera, contains('preHfrCameraState: preHfrCameraState'));
    });

    test('native attestation records real active-format FOV on both sides', () {
      final native = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      final probe =
          File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();

      for (final field in <String>[
        'preHfrVideoFieldOfView',
        'hfrVideoFieldOfView',
        'fieldOfViewDelta',
        'fieldOfViewMatchWithinTolerance',
        'preHfrNativeZoomMatchWithinTolerance',
        'aspectRatioMatch',
        'hfrSpatialComparability',
        'hfrSpatialComparabilityReason',
      ]) {
        expect(native, contains('"$field"'));
        expect(probe, contains("'$field'"));
      }

      expect(native, contains('device.activeFormat.videoFieldOfView'));
      expect(native, contains('selection.format.videoFieldOfView'));
      expect(native, contains('let fieldOfViewToleranceDegrees = 0.0'));
      expect(native, contains('"COMPARABLE"'));
      expect(native, contains('"NOT_COMPARABLE"'));
      expect(native, contains('"UNKNOWN"'));
    });

    test('non-comparable full-frame HFR cannot override a REALITY photo', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          comparability: 'NOT_COMPARABLE',
          fullFrame: true,
        ),
        stillMl: _stillReality(),
        temporalMl: null,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('weak screen video plus non-comparable HFR is non-conclusive', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          comparability: 'NOT_COMPARABLE',
          display: 5,
        ),
        ml: _weakScreenVideo(),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('BUILD125_VIDEO_HFR_FOV_NOT_DECISIONABLE'),
      );
      expect(
        result.reasons,
        contains('ABSENCE_OF_DISPLAY_PROOF_IS_NOT_POSITIVE_REALITY_PROOF'),
      );
    });

    test('UNKNOWN HFR with no independent decision evidence is non-conclusive',
        () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(
          comparability: 'UNKNOWN',
          fullFrame: true,
        ),
        ml: null,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_DECISION_EVIDENCE_UNAVAILABLE'),
      );
    });

    test('missing FOV comparability metadata fails closed', () {
      final hfr = _hfr(comparability: 'COMPARABLE')
        ..remove(
          'hfrSpatialComparability',
        );
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: hfr,
        ml: _weakScreenVideo(),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('BUILD125_VIDEO_HFR_FOV_NOT_DECISIONABLE'),
      );
    });

    test('COMPARABLE full-frame HFR can still promote DISPLAY', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          comparability: 'COMPARABLE',
          fullFrame: true,
        ),
        stillMl: _stillReality(),
        temporalMl: null,
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
    });

    test('strong independent ML still promotes DISPLAY when HFR is unusable',
        () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          comparability: 'NOT_COMPARABLE',
          fullFrame: true,
        ),
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
      expect(result.reasons, contains('BUILD124_PHOTO_STILL_STRONG_DISPLAY'));
    });
  });
}

Map<String, dynamic> _hfr({
  required String comparability,
  bool fullFrame = false,
  int display = 5,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': comparability,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrame,
        'displayLikeCellCount': display,
        'realityLikeCellCount': 0,
        'spatialFamilyCellCount': 9,
        'harmonicAwareSpatialFamilyCellCount': 9,
        'rowTimeFamilyCellCount': 9,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': 6,
        'stableCellCount': 5,
        'medianCellPeriodicityStrength': 0.20,
      },
    };

Map<String, dynamic> _stillReality() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'REALITY_ROOM',
      'screenProbability': 0.08,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 12,
        'contentAreaRiskScore': 10,
      },
    };

Map<String, dynamic> _weakScreenVideo() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.70,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        <String, dynamic>{
          'predictedClass': 'SCREEN_MONITOR',
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 68,
            'contentAreaRiskScore': 68,
          },
        },
        <String, dynamic>{
          'predictedClass': 'SCREEN_MONITOR',
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 64,
            'contentAreaRiskScore': 64,
          },
        },
      ],
    };
