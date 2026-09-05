import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

void main() {
  test('V2 probe is native, consecutive and permanently shadow-only', () {
    final source =
        File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
    expect(source, contains('captureTemporalFrequencyNative'));
    expect(source, contains('SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2'));
    expect(source, contains('ISOLATED_NATIVE_AVCAPTURESESSION_CMSAMPLEBUFFER'));
    expect(source, contains('SHADOW_ONLY_NEVER_DECISIONAL'));
    expect(source, contains("'encodedVideoUsed': false"));
    expect(source, contains("'ffmpegUsed': false"));
    expect(source, isNot(contains('startVideoRecording()')));
    expect(source, isNot(contains('FFmpegKit')));
  });

  test('camera releases Flutter controller before isolated native capture', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final helperStart =
        source.indexOf('_captureTemporalFrequencyNativeIsolated');
    expect(helperStart, greaterThanOrEqualTo(0));
    final helper = source.substring(
        helperStart,
        source.indexOf(
            'Future<void> _settleCameraAfterLiveProbe', helperStart));
    expect(helper.indexOf('await active.dispose()'), greaterThanOrEqualTo(0));
    expect(helper.indexOf('captureNative('),
        greaterThan(helper.indexOf('await active.dispose()')));
    expect(helper, contains('CameraController('));
    expect(helper, contains('await replacement.initialize()'));
  });

  test('iOS native path requests real 240 120 60 tiers and CMSampleBuffers',
      () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('[240.0, 120.0, 60.0]'));
    expect(swift, contains('AVCaptureVideoDataOutputSampleBufferDelegate'));
    expect(swift, contains('CMSampleBufferGetPresentationTimeStamp'));
    expect(
        swift, contains('device.activeVideoMinFrameDuration = frameDuration'));
    expect(
        swift, contains('device.activeVideoMaxFrameDuration = frameDuration'));
    expect(swift, contains('setExposureModeCustom'));
    expect(swift, contains('shortExposureVerified'));
  });

  test('unavailable V2 evidence cannot change production decision', () {
    final unavailable = HCVTemporalFrequencyProbe.unavailable('TEST');
    expect(unavailable['decisionRole'], 'SHADOW_ONLY_NEVER_DECISIONAL');
    expect(unavailable['productionDecisionChanged'], false);
  });
}
