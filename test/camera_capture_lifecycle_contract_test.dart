import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_capture_lifecycle.dart';

void main() {
  test('capture lifecycle has one interaction policy', () {
    expect(HCVCaptureLifecycle.idle.interactionLocked, isFalse);
    expect(HCVCaptureLifecycle.idle.captureButtonEnabled, isTrue);
    expect(HCVCaptureLifecycle.idle.captureSettingsMutable, isTrue);
    expect(HCVCaptureLifecycle.idle.canStopRecording, isFalse);

    expect(HCVCaptureLifecycle.recording.interactionLocked, isTrue);
    expect(HCVCaptureLifecycle.recording.captureButtonEnabled, isTrue);
    expect(HCVCaptureLifecycle.recording.captureSettingsMutable, isFalse);
    expect(HCVCaptureLifecycle.recording.canStopRecording, isTrue);

    for (final state in <HCVCaptureLifecycle>[
      HCVCaptureLifecycle.preparingVideo,
      HCVCaptureLifecycle.finalizingVideo,
      HCVCaptureLifecycle.processingVideo,
      HCVCaptureLifecycle.capturingPhoto,
      HCVCaptureLifecycle.processingPhoto,
    ]) {
      expect(state.interactionLocked, isTrue, reason: state.name);
      expect(state.captureButtonEnabled, isFalse, reason: state.name);
      expect(state.captureSettingsMutable, isFalse, reason: state.name);
      expect(state.canStopRecording, isFalse, reason: state.name);
    }
  });

  test('camera source enforces lifecycle before first async capture work', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains('PopScope('));
    expect(source, contains('canPop: !_captureInteractionLocked'));
    expect(source, isNot(contains('_videoFinalizeInProgress')));
    expect(source, isNot(matches(RegExp(r'\brecording\s*=\s*(true|false)'))));

    final start = source.indexOf('Future<void> start() async');
    final preparing = source.indexOf(
      '_setCaptureLifecycle(HCVCaptureLifecycle.preparingVideo);',
      start,
    );
    final startLocation = source.indexOf(
      'final captureLocation = await _locationForCapture();',
      start,
    );
    expect(preparing, greaterThan(start));
    expect(startLocation, greaterThan(preparing));

    final stop = source.indexOf('Future<void> stop() async');
    final finalizing = source.indexOf(
      '_setCaptureLifecycle(HCVCaptureLifecycle.finalizingVideo);',
      stop,
    );
    final stopRecording = source.indexOf(
      'await controller!.stopVideoRecording();',
      stop,
    );
    expect(finalizing, greaterThan(stop));
    expect(stopRecording, greaterThan(finalizing));

    final photo = source.indexOf('Future<void> takePhoto() async');
    final capturingPhoto = source.indexOf(
      '_setCaptureLifecycle(HCVCaptureLifecycle.capturingPhoto);',
      photo,
    );
    final photoLocation = source.indexOf(
      'final captureLocation = await _locationForCapture();',
      photo,
    );
    expect(capturingPhoto, greaterThan(photo));
    expect(photoLocation, greaterThan(capturingPhoto));
  });

  test('capture controls are guarded', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(
      source,
      contains('if (_captureInteractionLocked || _locationBusy) return;'),
    );
    expect(
      source,
      contains(
        'Future<void> switchCamera() async {\n    if (_captureInteractionLocked) return;',
      ),
    );
    expect(
      source,
      contains(
        'Future<void> toggleFlash() async {\n    if (_captureInteractionLocked) return;',
      ),
    );
    expect(
      source,
      contains(
        'Future<void> setZoom(double zoom) async {\n    if (_captureInteractionLocked) return;',
      ),
    );
    expect(
      source,
      contains('onPressed: _captureInteractionLocked ? null : toggleFlash'),
    );
    expect(
      source,
      contains('onPressed: _captureInteractionLocked ? null : switchCamera'),
    );
  });
}
