from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one match, found {count}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/camera_page.dart',
    '''    // The native high-speed session must own the camera exclusively. BUILD 87\n    // proved that changing activeFormat underneath an initialized Flutter\n    // CameraController is unsafe. Release the Flutter AVCaptureSession first.\n    try {\n      await active.dispose();\n    } catch (_) {}\n    await Future.delayed(const Duration(milliseconds: 300));\n''',
    '''    // The native high-speed session must own the camera exclusively. Detach\n    // CameraPreview from the controller BEFORE disposing its native texture.\n    // Keeping a disposed controller mounted during the AVFoundation handoff can\n    // crash the iOS camera pipeline before Dart can receive an exception.\n    controller = null;\n    if (mounted) {\n      setState(() {\n        ready = false;\n      });\n      await WidgetsBinding.instance.endOfFrame;\n    }\n    try {\n      await active.dispose();\n    } catch (_) {}\n    // Give the Flutter camera plugin time to release AVCaptureSession/device\n    // ownership before the isolated native session changes high-speed format.\n    await Future.delayed(const Duration(milliseconds: 650));\n''',
)

replace_once(
    'ios/Runner/AppDelegate.swift',
    '''  private func temporalFrequencyFormat(\n    for device: AVCaptureDevice,\n    requestedMaxFps: Double\n  ) -> (format: AVCaptureDevice.Format, fps: Double)? {\n''',
    '''  private func temporalFrequencyPhysicalDevice(\n    for device: AVCaptureDevice\n  ) -> AVCaptureDevice {\n    // High-frame-rate activeFormat changes are safer on a physical camera than\n    // on Apple's virtual dual/triple camera devices. Preserve front/back\n    // position but resolve the physical wide-angle constituent when available.\n    if device.isVirtualDevice,\n       let wide = AVCaptureDevice.default(\n         .builtInWideAngleCamera,\n         for: .video,\n         position: device.position\n       ) {\n      return wide\n    }\n    return device\n  }\n\n  private func temporalFrequencyFormat(\n    for device: AVCaptureDevice,\n    requestedMaxFps: Double\n  ) -> (format: AVCaptureDevice.Format, fps: Double)? {\n''',
)

replace_once(
    'ios/Runner/AppDelegate.swift',
    '''      var bestFormat: AVCaptureDevice.Format?\n      var bestArea: Int64 = 0\n''',
    '''      var bestFormat: AVCaptureDevice.Format?\n      var bestArea: Int64 = Int64.max\n''',
)

replace_once(
    'ios/Runner/AppDelegate.swift',
    '''        // High-speed formats are typically 720p/1080p. Prefer the largest\n        // native frame that still supports the exact requested tier.\n        if bestFormat == nil || area > bestArea {\n''',
    '''        // The probe needs temporal fidelity, not maximum video resolution.\n        // Prefer the smallest adequate native format to reduce pixel-buffer\n        // pressure and sample-processing latency at 120/240 fps.\n        if bestFormat == nil || area < bestArea {\n''',
)

replace_once(
    'ios/Runner/AppDelegate.swift',
    '''        let output = AVCaptureVideoDataOutput()\n        output.alwaysDiscardsLateVideoFrames = false\n''',
    '''        let output = AVCaptureVideoDataOutput()\n        // Never allow an expensive high-speed analysis callback to build an\n        // unbounded CVPixelBuffer backlog. Timestamp analysis will reveal any\n        // dropped sample instead of risking process termination.\n        output.alwaysDiscardsLateVideoFrames = true\n''',
)

replace_once(
    'ios/Runner/AppDelegate.swift',
    '''    case "captureTemporalFrequencyNative":\n      captureTemporalFrequencyNative(device: device, call: call, result: result)\n''',
    '''    case "captureTemporalFrequencyNative":\n      let physicalDevice = temporalFrequencyPhysicalDevice(for: device)\n      captureTemporalFrequencyNative(\n        device: physicalDevice,\n        call: call,\n        result: result\n      )\n''',
)

Path('test/native_temporal_frequency_v2_crash_hotfix_contract_test.dart').write_text(r'''import 'dart:io';

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
    expect(source, contains('let physicalDevice = temporalFrequencyPhysicalDevice(for: device)'));
  });

  test('native V2 prefers low pressure high speed format and discards late buffers', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(source, contains('var bestArea: Int64 = Int64.max'));
    expect(source, contains('area < bestArea'));
    expect(source, contains('output.alwaysDiscardsLateVideoFrames = true'));
  });
}
''', encoding='utf-8')
