from pathlib import Path

probe_path = Path('lib/hcv_temporal_frequency_probe.dart')
text = probe_path.read_text()

start_marker = "      configuredState = await _invokeMap('configureTemporalFrequencyProbe', {\n"
end_marker = "      await Future.delayed(const Duration(milliseconds: 70));\n"
start = text.find(start_marker)
if start < 0:
    raise SystemExit('frequency configure block start not found')
end = text.find(end_marker, start)
if end < 0:
    raise SystemExit('frequency configure block end not found')
end += len(end_marker)

replacement = """      // Session-safety hotfix: never mutate AVCaptureDevice.activeFormat or
      // active frame durations behind Flutter camera's active AVCaptureSession.
      // BUILD 87 crashed on both PHOTO and VIDEO because the plugin controller
      // retained outputs configured for its original format while the native
      // bridge changed the device format underneath it.
      configuredState = Map<String, dynamic>.from(originalState);
      configuredState['configurationMode'] =
          'PLUGIN_ACTIVE_FORMAT_PRESERVED_SESSION_SAFE';
      configuredState['requestedTargetMaxFps'] = targetMaxFps;
      configuredState['configuredFrameRate'] = null;
      configuredState['highFpsFormatMutationSkipped'] = true;

      // Keep only the previously validated physical intervention: short shutter.
      // The actual encoded cadence is measured from the disposable clip rather
      // than forcing a new device format/frame duration while Flutter owns it.
      shortExposureState = await _invokeMap('applyShortExposure', {
        'deviceUniqueId': uniqueId,
        'targetDurationSeconds': requestedShortExposureSeconds,
      });
      if (shortExposureState == null) {
        throw StateError('SHORT_EXPOSURE_UNAVAILABLE');
      }
      await Future.delayed(const Duration(milliseconds: 70));
"""
text = text[:start] + replacement + text[end:]

old_restore = """        try {
          await _channel.invokeMethod<void>('restoreCameraState', {
            'deviceUniqueId': uniqueId,
            'state': originalState,
          });
        } catch (_) {}
"""
new_restore = """        try {
          // Do not allow restoreCameraState to reassign activeFormat or frame
          // durations either. Only exposure/focus/WB/zoom state is restored.
          final sessionSafeRestoreState = Map<String, dynamic>.from(originalState)
            ..remove('activeFormatIndex')
            ..remove('activeVideoMinFrameDurationSeconds')
            ..remove('activeVideoMaxFrameDurationSeconds');
          await _channel.invokeMethod<void>('restoreCameraState', {
            'deviceUniqueId': uniqueId,
            'state': sessionSafeRestoreState,
          });
        } catch (_) {}
"""
if text.count(old_restore) != 1:
    raise SystemExit(f'restore block expected once, found {text.count(old_restore)}')
text = text.replace(old_restore, new_restore, 1)
probe_path.write_text(text)

contract = Path('test/frequency_probe_session_safety_contract_test.dart')
contract.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frequency probe never mutates active camera format behind Flutter session', () {
    final source = File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
    expect(source, isNot(contains("'configureTemporalFrequencyProbe'")));
    expect(source, isNot(contains("'lockTemporalProbeOptics'")));
    expect(source, contains("'applyShortExposure'"));
    expect(source, contains("'PLUGIN_ACTIVE_FORMAT_PRESERVED_SESSION_SAFE'"));
    expect(source, contains("..remove('activeFormatIndex')"));
    expect(source, contains("..remove('activeVideoMinFrameDurationSeconds')"));
    expect(source, contains("..remove('activeVideoMaxFrameDurationSeconds')"));
    expect(source, contains('await controller.startVideoRecording()'));
  });

  test('frequency probe remains shadow-only', () {
    final source = File('lib/hcv_temporal_frequency_probe.dart').readAsStringSync();
    expect(source, contains("'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL'"));
    expect(source, contains("'productionDecisionChanged': false"));
  });
}
""")
