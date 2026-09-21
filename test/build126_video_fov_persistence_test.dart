import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  group('BUILD126 recording FOV attestation', () {
    test('recording camera matches the pre-HFR HFR geometry', () {
      final attested = HCVTemporalFrequencyProbe.attestVideoRecordingGeometry(
        _hfr(),
        _recordingState(),
      );
      expect(attested['hfrSpatialComparability'], 'COMPARABLE');
      expect(attested['videoRecordingSpatialComparability'], 'COMPARABLE');
      expect(attested['recordingFieldOfViewDelta'], 0.0);
      expect(attested['recordingZoomMatchWithinTolerance'], true);
      expect(attested['recordingAspectRatioMatch'], true);
      expect(attested['recordingCameraState'], _recordingState());
    });

    test('4:3 recorded video cannot reuse 16:9 HFR even at same zoom', () {
      final attested = HCVTemporalFrequencyProbe.attestVideoRecordingGeometry(
        _hfr(),
        _recordingState(width: 640, height: 480, fov: 65.35665130615234),
      );
      expect(attested['hfrSpatialComparability'], 'NOT_COMPARABLE');
      expect(
        attested['hfrSpatialComparabilityReason'],
        'RECORDING_ACTIVE_FORMAT_FOV_MISMATCH',
      );
    });

    test('same FOV but different aspect ratio is not comparable', () {
      final attested = HCVTemporalFrequencyProbe.attestVideoRecordingGeometry(
        _hfr(),
        _recordingState(width: 640, height: 480),
      );
      expect(attested['hfrSpatialComparability'], 'NOT_COMPARABLE');
      expect(
        attested['hfrSpatialComparabilityReason'],
        'RECORDING_ACTIVE_FORMAT_ASPECT_RATIO_MISMATCH',
      );
    });

    test('recording lens substitution is not comparable', () {
      final attested = HCVTemporalFrequencyProbe.attestVideoRecordingGeometry(
        _hfr(),
        _recordingState(device: 'camera-B'),
      );
      expect(attested['hfrSpatialComparability'], 'NOT_COMPARABLE');
      expect(
        attested['hfrSpatialComparabilityReason'],
        'RECORDING_PHYSICAL_DEVICE_MISMATCH',
      );
    });

    test('recording zoom mismatch is not comparable', () {
      final attested = HCVTemporalFrequencyProbe.attestVideoRecordingGeometry(
        _hfr(),
        _recordingState(zoom: 5),
      );
      expect(attested['hfrSpatialComparability'], 'NOT_COMPARABLE');
      expect(
        attested['hfrSpatialComparabilityReason'],
        'RECORDING_NATIVE_ZOOM_MISMATCH',
      );
    });

    test('unknown REC state never proves HFR comparable', () {
      final attested = HCVTemporalFrequencyProbe.attestVideoRecordingGeometry(
        _hfr(),
        null,
      );
      expect(attested['hfrSpatialComparability'], 'UNKNOWN');
      expect(
        attested['hfrSpatialComparabilityReason'],
        'RECORDING_CAMERA_STATE_MISSING_OR_INCOMPLETE',
      );
    });

    test('already mismatched HFR cannot be promoted by a matching REC state',
        () {
      final attested = HCVTemporalFrequencyProbe.attestVideoRecordingGeometry(
        _hfr()..['hfrSpatialComparability'] = 'NOT_COMPARABLE',
        _recordingState(),
      );
      expect(attested['hfrSpatialComparability'], 'NOT_COMPARABLE');
      expect(
        attested['videoRecordingSpatialComparability'],
        'NOT_COMPARABLE',
      );
    });

    test('missing legacy HFR metadata remains unknown rather than promoted',
        () {
      final attested = HCVTemporalFrequencyProbe.attestVideoRecordingGeometry(
        <String, dynamic>{'analysisStatus': 'ANALYZED'},
        _recordingState(),
      );
      expect(attested['videoRecordingSpatialComparability'], 'UNKNOWN');
    });
  });

  group('BUILD126 video-specific policy regression from archive 77', () {
    test('TV: corroborated comparable HFR still warns DISPLAY', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(),
        ml: _videoMl(<double>[0.7282, 0.6794, 0.6479]),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('TV: three persistent suspicious frames with FOV mismatch are NC', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr()
          ..['hfrSpatialComparability'] = 'NOT_COMPARABLE',
        ml: _videoMl(<double>[0.7282, 0.6794, 0.6479]),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('BUILD125_VIDEO_HFR_FOV_NOT_DECISIONABLE'),
      );
    });

    test('selfie: isolated moderate screen frame does not escalate video', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr()
          ..['hfrSpatialComparability'] = 'NOT_COMPARABLE',
        ml: _videoMl(
          <double>[0.6539, 0.2274, 0.0416, 0.0217, 0.0159],
          screenFrames: 1,
        ),
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('strong independently persistent ML still warns with HFR mismatch',
        () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr()
          ..['hfrSpatialComparability'] = 'NOT_COMPARABLE',
        ml: _videoMl(<double>[0.9668, 0.9701, 0.9612], fullFrameRisk: 97),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY'),
      );
    });
  });

  group('BUILD126 end-to-end camera/claim contracts', () {
    test('video uses high camera preset and checks geometry during REC', () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      expect(
        camera,
        contains('ResolutionPreset _resolutionPresetForMode(bool isPhotoMode)'),
      );
      expect(camera, contains('return ResolutionPreset.high;'));
      expect(
        camera,
        isNot(contains('ResolutionPreset.high : ResolutionPreset.medium')),
      );
      final recording =
          camera.indexOf('await controller!.startVideoRecording()');
      final snapshot = camera.indexOf('snapshotNativeCameraState(', recording);
      final attestation =
          camera.indexOf('attestVideoRecordingGeometry(', recording);
      expect(recording, greaterThanOrEqualTo(0));
      expect(snapshot, greaterThan(recording));
      expect(attestation, greaterThan(snapshot));
    });

    test('NON_CONCLUSIVE video cannot publish REDUCED scene risk', () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      expect(
        camera,
        contains('displayRiskDecision == "NON_CONCLUSIVE"'),
      );
      expect(camera, contains('"LIVE_CAPTURE_SCENE_INCONCLUSIVE"'));
    });
  });
}

Map<String, dynamic> _hfr() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': 'COMPARABLE',
      'physicalCaptureDeviceUniqueId': 'camera-A',
      'hfrVideoFieldOfView': 70.29109191894531,
      'effectiveZoomFactor': 8.564003944396973,
      'configuredHighSpeedFormatWidth': 1280,
      'configuredHighSpeedFormatHeight': 720,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'displayLikeCellCount': 6,
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

Map<String, dynamic> _recordingState({
  String device = 'camera-A',
  int width = 1280,
  int height = 720,
  double fov = 70.29109191894531,
  double zoom = 8.564003944396973,
}) =>
    <String, dynamic>{
      'deviceUniqueId': device,
      'activeFormatWidth': width,
      'activeFormatHeight': height,
      'activeFormatVideoFieldOfView': fov,
      'zoomFactor': zoom,
    };

Map<String, dynamic> _videoMl(
  List<double> probabilities, {
  int? screenFrames,
  int fullFrameRisk = 73,
}) {
  final n = screenFrames ?? probabilities.length;
  return <String, dynamic>{
    'analysisStatus': 'ANALYZED',
    'predictedClass': 'SCREEN_MONITOR',
    'screenProbability': probabilities.first,
    'videoFrameAnalyses': <Map<String, dynamic>>[
      for (var i = 0; i < probabilities.length; i++)
        <String, dynamic>{
          'predictedClass': i < n ? 'SCREEN_MONITOR' : 'REALITY_OUTDOOR',
          'signals': <String, dynamic>{
            'fullFrameRiskScore': i < n ? fullFrameRisk : 0,
          },
        },
    ],
  };
}
