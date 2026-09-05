import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'native illumination probe locks exposure and uses OFF ON OFF torch phases',
      () {
    final s = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(s, contains('captureIlluminationResponseNative'));
    expect(s, contains('ISOLATED_NATIVE_TORCH_OFF_ON_OFF_LOCKED_EXPOSURE'));
    expect(s, contains('captureDevice.setExposureModeCustom'));
    expect(s, contains('captureDevice.setTorchModeOn(level: torchLevel)'));
    expect(RegExp(r'collector\.setPhase\([012]\)').allMatches(s).length, 3);
    expect(
        s,
        contains(
            'resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)'));
  });
}
