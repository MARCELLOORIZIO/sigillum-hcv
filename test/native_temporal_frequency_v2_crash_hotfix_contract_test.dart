import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native V2 detaches Flutter preview before camera disposal', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final detach = source.indexOf('controller = null;');
    final endOfFrame = source.indexOf('WidgetsBinding.instance.endOfFrame');
    final dispose = source.indexOf('await active.dispose();');
    expect(detach, greaterThanOrEqualTo(0));
    expect(endOfFrame, greaterThan(detach));
    expect(dispose, greaterThan(endOfFrame));
    expect(source, contains('Duration(milliseconds: 650)'));
  });

  test('native V2 high speed capture resolves physical camera device', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(source, contains('temporalFrequencyPhysicalDevice'));
    expect(source, contains('device.isVirtualDevice'));
    expect(source, contains('.builtInWideAngleCamera'));
    expect(
        source,
        contains(
            'let physicalDevice = temporalFrequencyPhysicalDevice(for: device)'));
  });

  test(
      'native V2 prefers low pressure high speed format and discards late buffers',
      () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(source, contains('var bestArea: Int64 = Int64.max'));
    expect(source, contains('area < bestArea'));
    expect(source, contains('output.alwaysDiscardsLateVideoFrames = true'));
  });
}
