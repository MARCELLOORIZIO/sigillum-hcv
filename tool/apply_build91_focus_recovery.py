from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


swift_path = Path('ios/Runner/AppDelegate.swift')
swift = swift_path.read_text()

helper_marker = '''  private func finishTemporalFrequencyNativeCapture(\n'''
helper = '''  private func resetTemporalFrequencyOpticsForFlutterHandoff(\n    _ device: AVCaptureDevice\n  ) -> [String: Any] {\n    var metadata: [String: Any] = [\n      "requestedFocusMode": "CONTINUOUS_AUTO",\n      "requestedExposureMode": "CONTINUOUS_AUTO",\n      "requestedWhiteBalanceMode": "CONTINUOUS_AUTO",\n      "centerFocusPointRequested": true,\n      "autoFocusRangeRestrictionRequested": "NONE",\n      "resetApplied": false,\n    ]\n\n    do {\n      try device.lockForConfiguration()\n\n      if device.isFocusPointOfInterestSupported {\n        device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)\n      }\n      if device.isAutoFocusRangeRestrictionSupported {\n        device.autoFocusRangeRestriction = .none\n      }\n      if device.isFocusModeSupported(.continuousAutoFocus) {\n        device.focusMode = .continuousAutoFocus\n      }\n\n      if device.isExposurePointOfInterestSupported {\n        device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)\n      }\n      if device.isExposureModeSupported(.continuousAutoExposure) {\n        device.exposureMode = .continuousAutoExposure\n      }\n      if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {\n        device.whiteBalanceMode = .continuousAutoWhiteBalance\n      }\n      device.isSubjectAreaChangeMonitoringEnabled = true\n\n      device.unlockForConfiguration()\n\n      metadata["resetApplied"] = true\n      metadata["focusModeAfterReset"] = focusModeName(device.focusMode)\n      metadata["lensPositionAfterReset"] = Double(device.lensPosition)\n      metadata["exposureModeAfterReset"] = exposureModeName(device.exposureMode)\n      metadata["whiteBalanceModeAfterReset"] = whiteBalanceModeName(device.whiteBalanceMode)\n      metadata["subjectAreaChangeMonitoringEnabled"] = device.isSubjectAreaChangeMonitoringEnabled\n    } catch {\n      metadata["resetError"] = error.localizedDescription\n    }\n    return metadata\n  }\n\n'''
swift = replace_once(swift, helper_marker, helper + helper_marker, 'insert focus handoff helper')

swift = replace_once(
    swift,
    '''  private func finishTemporalFrequencyNativeCapture(\n    session: AVCaptureSession,\n    output: AVCaptureVideoDataOutput,\n    payload: [String: Any],\n    result: @escaping FlutterResult\n  ) {\n''',
    '''  private func finishTemporalFrequencyNativeCapture(\n    session: AVCaptureSession,\n    output: AVCaptureVideoDataOutput,\n    device: AVCaptureDevice,\n    payload: [String: Any],\n    result: @escaping FlutterResult\n  ) {\n''',
    'finish signature',
)

swift = replace_once(
    swift,
    '''    temporalFrequencyNativeQueue.async { [weak self] in\n      output.setSampleBufferDelegate(nil, queue: nil)\n      if session.isRunning {\n        session.stopRunning()\n      }\n      self?.temporalFrequencyNativeCollector = nil\n      self?.temporalFrequencyNativeSession = nil\n      self?.temporalFrequencyNativeBusy = false\n      DispatchQueue.main.async {\n        result(payload)\n      }\n    }\n''',
    '''    temporalFrequencyNativeQueue.async { [weak self] in\n      output.setSampleBufferDelegate(nil, queue: nil)\n      if session.isRunning {\n        session.stopRunning()\n      }\n\n      var finalPayload = payload\n      if let self {\n        // The HFR probe intentionally locks focus while collecting the short\n        // sample. Never hand that locked optical state back to Flutter.\n        finalPayload["cameraHandoffAfterNativeProbe"] =\n          self.resetTemporalFrequencyOpticsForFlutterHandoff(device)\n        self.temporalFrequencyNativeCollector = nil\n        self.temporalFrequencyNativeSession = nil\n        self.temporalFrequencyNativeBusy = false\n      }\n      DispatchQueue.main.async {\n        result(finalPayload)\n      }\n    }\n''',
    'finish body focus reset',
)

# Both normal completion and timeout completion must identify the device that
# was locked by the native HFR probe.
swift_count = swift.count('''            session: session,\n            output: output,\n            payload: payload,\n            result: result\n''')
if swift_count != 2:
    raise SystemExit(f'finish calls: expected 2 matches, found {swift_count}')
swift = swift.replace(
    '''            session: session,\n            output: output,\n            payload: payload,\n            result: result\n''',
    '''            session: session,\n            output: output,\n            device: captureDevice,\n            payload: payload,\n            result: result\n''',
)

swift = replace_once(
    swift,
    '''          let gains = self.clampedWhiteBalanceGains(\n            captureDevice.deviceWhiteBalanceGains,\n            for: device\n          )\n''',
    '''          let gains = self.clampedWhiteBalanceGains(\n            captureDevice.deviceWhiteBalanceGains,\n            for: captureDevice\n          )\n''',
    'white balance physical device',
)

swift = replace_once(
    swift,
    '''      } catch {\n        if let runningSession = self.temporalFrequencyNativeSession,\n           runningSession.isRunning {\n          runningSession.stopRunning()\n        }\n        self.temporalFrequencyNativeCollector = nil\n''',
    '''      } catch {\n        if let runningSession = self.temporalFrequencyNativeSession,\n           runningSession.isRunning {\n          runningSession.stopRunning()\n        }\n        // Error paths must also release the focus lock; otherwise the next\n        // Flutter session can inherit a stale lens position.\n        _ = self.resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)\n        self.temporalFrequencyNativeCollector = nil\n''',
    'error path focus reset',
)

swift_path.write_text(swift)


dart_path = Path('lib/camera_page.dart')
dart = dart_path.read_text()

# Re-arm continuous autofocus/exposure only after zoom and flash are restored.
# This deliberately occurs immediately after the replacement Flutter session is
# initialized, before any BUILD 80 temporal clip or final video starts.
dart = replace_once(
    dart,
    '''      await replacement.setZoomLevel(restoredZoom);\n      try {\n        await replacement.setFlashMode(savedFlash);\n      } catch (_) {}\n\n      controller = replacement;\n''',
    '''      await replacement.setZoomLevel(restoredZoom);\n      try {\n        await replacement.setFlashMode(savedFlash);\n      } catch (_) {}\n\n      // The native HFR probe locks the physical lens for temporal stability.\n      // A newly initialized Flutter controller is not enough to guarantee an\n      // immediate AF scan on the same AVCaptureDevice, so explicitly re-arm\n      // continuous autofocus and re-center AF/AE before returning to capture.\n      try {\n        await replacement.setFocusMode(FocusMode.auto);\n        await replacement.setFocusPoint(null);\n      } catch (_) {}\n      try {\n        await replacement.setExposureMode(ExposureMode.auto);\n        await replacement.setExposurePoint(null);\n      } catch (_) {}\n\n      // Real BUILD 91 samples needed roughly 1-3 seconds to recover focus when\n      // this reset was absent. Give the explicit AF kick a bounded head start;\n      // photo mode then gets the existing 2.4 s temporal clip as extra settle.\n      await Future.delayed(const Duration(milliseconds: 650));\n\n      controller = replacement;\n''',
    'flutter camera focus reset',
)

dart_path.write_text(dart)


native_test = Path('test/native_temporal_frequency_focus_handoff_contract_test.dart')
native_test.write_text(r'''import 'dart:io';

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
''')


dart_test = Path('test/camera_focus_recovery_after_native_probe_test.dart')
dart_test.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter camera explicitly rearms autofocus after native HFR handoff', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final start =
        source.indexOf('  Future<Map<String, dynamic>> _captureTemporalFrequencyNativeIsolated()');
    final end = source.indexOf('  Future<void> _settleCameraAfterLiveProbe()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final handoff = source.substring(start, end);

    final initialized = handoff.indexOf('await replacement.initialize();');
    final zoom = handoff.indexOf('await replacement.setZoomLevel(restoredZoom);');
    final focusMode = handoff.indexOf('await replacement.setFocusMode(FocusMode.auto);');
    final focusPoint = handoff.indexOf('await replacement.setFocusPoint(null);');
    final exposureMode =
        handoff.indexOf('await replacement.setExposureMode(ExposureMode.auto);');
    final exposurePoint = handoff.indexOf('await replacement.setExposurePoint(null);');
    final settle = handoff.indexOf(
      'await Future.delayed(const Duration(milliseconds: 650));',
    );

    expect(initialized, greaterThanOrEqualTo(0));
    expect(zoom, greaterThan(initialized));
    expect(focusMode, greaterThan(zoom));
    expect(focusPoint, greaterThan(focusMode));
    expect(exposureMode, greaterThan(focusPoint));
    expect(exposurePoint, greaterThan(exposureMode));
    expect(settle, greaterThan(exposurePoint));
  });
}
''')

print('BUILD91 focus recovery patch applied')
