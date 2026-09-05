from pathlib import Path

path = Path('test/build72_video_reality_and_container_regression_test.dart')
source = path.read_text(encoding='utf-8')

old = """  test('camera stop path serializes finalization before video processing', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains('bool _videoFinalizeInProgress = false;'));
    expect(
      source,
      contains('if (controller == null || _videoFinalizeInProgress) return;'),
    );
    expect(source, contains('_waitForFinalizedVideoContainer(file.path)'));
    expect(source, contains('stableReads >= 3'));
    expect(source, contains('Duration(seconds: 6)'));
    expect(source, contains('copiedSize != sourceSize'));
    expect(source, contains('!ready || _videoFinalizeInProgress'));
  });
"""

new = """  test('camera stop path serializes finalization before video processing', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(
      source,
      contains(
        'if (_captureLifecycle != HCVCaptureLifecycle.recording) return;',
      ),
    );
    expect(
      source,
      contains(
        '_setCaptureLifecycle(HCVCaptureLifecycle.finalizingVideo);',
      ),
    );
    expect(
      source.indexOf(
        '_setCaptureLifecycle(HCVCaptureLifecycle.finalizingVideo);',
      ),
      lessThan(source.indexOf('await controller!.stopVideoRecording();')),
    );
    expect(
      source,
      contains('_setCaptureLifecycle(HCVCaptureLifecycle.processingVideo);'),
    );
    expect(source, contains('_waitForFinalizedVideoContainer(file.path)'));
    expect(source, contains('stableReads >= 3'));
    expect(source, contains('Duration(seconds: 6)'));
    expect(source, contains('copiedSize != sourceSize'));
    expect(source, contains('PopScope('));
    expect(source, contains('canPop: !_captureInteractionLocked'));
  });
"""

if source.count(old) != 1:
    raise SystemExit('BUILD72 legacy stop contract target mismatch')

path.write_text(source.replace(old, new, 1), encoding='utf-8')
