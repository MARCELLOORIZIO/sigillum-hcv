import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native HFR probe uses physical device and AVFrameRateRange duration', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final start = source.indexOf('  private func captureTemporalFrequencyNative(');
    final end = source.indexOf('  private func handleCameraProbeCall(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final capture = source.substring(start, end);

    expect(
      capture,
      contains('let captureDevice = self.temporalFrequencyPhysicalDevice(for: device)'),
    );
    expect(capture, contains('AVCaptureDeviceInput(device: captureDevice)'));
    expect(capture, contains('captureDevice.activeFormat = selection.format'));
    expect(capture, contains('let frameDuration = selection.range.minFrameDuration'));
    expect(
      capture,
      contains('captureDevice.activeVideoMinFrameDuration = frameDuration'),
    );
    expect(
      capture,
      contains('captureDevice.activeVideoMaxFrameDuration = frameDuration'),
    );
    expect(capture, isNot(contains('1.0 / selection.fps')));
    expect(capture, isNot(contains('session.sessionPreset = .inputPriority')));
    expect(capture, contains('physicalDeviceSubstitutionUsed'));
  });

  test('format selector carries the exact AVFrameRateRange into capture', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final start = source.indexOf('  private func temporalFrequencyFormat(');
    final end = source.indexOf('  private func finishTemporalFrequencyNativeCapture(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final selector = source.substring(start, end);

    expect(
      selector,
      contains('(format: AVCaptureDevice.Format, range: AVFrameRateRange, fps: Double)?'),
    );
    expect(selector, contains('bestRange = range'));
    expect(selector, contains('bestRange.maxFrameRate'));
  });
}
