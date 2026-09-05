import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native HFR capture cannot leave the physical lens focus locked', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    final helperStart =
        source.indexOf('  private func resetTemporalFrequencyOpticsForFlutterHandoff(');
    final helperEnd = source.indexOf(
      '  private func finishTemporalFrequencyNativeCapture(',
      helperStart,
    );
    expect(helperStart, greaterThanOrEqualTo(0));
    expect(helperEnd, greaterThan(helperStart));
    final helper = source.substring(helperStart, helperEnd);

    expect(helper, contains('device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)'));
    expect(helper, contains('device.autoFocusRangeRestriction = .none'));
    expect(helper, contains('device.focusMode = .continuousAutoFocus'));
    expect(helper, contains('device.exposureMode = .continuousAutoExposure'));
    expect(helper, contains('device.whiteBalanceMode = .continuousAutoWhiteBalance'));
    expect(helper, contains('device.isSubjectAreaChangeMonitoringEnabled = true'));
  });

  test('normal, timeout and error handoffs reset optics', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final captureStart =
        source.indexOf('  private func captureTemporalFrequencyNative(');
    final captureEnd = source.indexOf(
      '  private func handleCameraProbeCall(',
      captureStart,
    );
    expect(captureStart, greaterThanOrEqualTo(0));
    expect(captureEnd, greaterThan(captureStart));
    final capture = source.substring(captureStart, captureEnd);

    expect(
      source,
      contains('self.resetTemporalFrequencyOpticsForFlutterHandoff(device)'),
    );
    expect(
      capture,
      contains('_ = self.resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)'),
    );
    expect(
      RegExp(r'device: captureDevice,').allMatches(capture).length,
      2,
    );
    expect(source, contains('cameraHandoffAfterNativeProbe'));
  });
}
