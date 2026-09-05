from pathlib import Path
import subprocess


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file_path = Path(path)
    source = file_path.read_text(encoding='utf-8')
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    file_path.write_text(source.replace(old, new, 1), encoding='utf-8')


# BUILD72: keep the actual container-finalization guarantees while replacing
# the removed implementation-detail boolean with the unified lifecycle states.
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

# The post-HFR controller is intentionally snapshotted as activeController.
# These tests still verify direct first-tap recording; only the variable name
# changed as part of the lifecycle/race hardening.
replace_once(
    'test/camera_ready_video_evidence_contract_test.dart',
    "expect(camera, contains('await controller!.startVideoRecording();'));",
    "expect(camera, contains('await activeController.startVideoRecording();'));",
    'camera-ready direct recording contract',
)

replace_once(
    'test/video_native_capture_writer_stability_contract_test.dart',
    "expect(camera, contains('await controller!.startVideoRecording();'));",
    "expect(camera, contains('await activeController.startVideoRecording();'));",
    'native writer direct recording contract',
)
replace_once(
    'test/video_native_capture_writer_stability_contract_test.dart',
    """    final analysis = camera.indexOf(
      'await temporalProbeEngine.analyzeCapturedClip(temporalClip)',
      still,
    );
""",
    """    final analysis = camera.indexOf(
      'temporalProbeEngine.analyzeCapturedClip(',
      still,
    );
""",
    'photo temporal analysis formatting contract',
)
replace_once(
    'test/video_native_capture_writer_stability_contract_test.dart',
    """  test('video stop failure clears recording UI state', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    expect(camera, contains('pendingVideoCapturedAt = null;'));
    expect(camera, contains('recording = false;'));
  });
""",
    """  test('video stop failure clears recording UI state', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final stop = camera.indexOf('Future<void> stop() async');
    final nextMethod = camera.indexOf(
      'Map<String, dynamic> _photoTemporalV2Unavailable',
      stop,
    );
    final stopSource = camera.substring(stop, nextMethod);

    expect(stopSource, contains('pendingVideoCapturedAt = null;'));
    expect(
      stopSource,
      contains('_setCaptureLifecycle(HCVCaptureLifecycle.idle);'),
    );
    expect(camera, isNot(contains('_videoFinalizeInProgress')));
  });
""",
    'stop failure lifecycle reset contract',
)

replace_once(
    'test/prelaunch_ui_camera_refinement_contract_test.dart',
    "final record = source.indexOf('await controller!.startVideoRecording();');",
    "final record = source.indexOf('await activeController.startVideoRecording();');",
    'prelaunch first REC contract',
)

replace_once(
    'test/mixed_scene_monitor_regression_test.dart',
    """    final analysis = camera.indexOf(
      'await temporalProbeEngine.analyzeCapturedClip(temporalClip)',
      photo,
    );
""",
    """    final analysis = camera.indexOf(
      'temporalProbeEngine.analyzeCapturedClip(',
      photo,
    );
""",
    'mixed-scene temporal analysis formatting contract',
)

replace_once(
    'test/ios_video_watermark_archive42_contract_test.dart',
    "expect(camera, contains('await controller!.startVideoRecording();'));",
    "expect(camera, contains('await activeController.startVideoRecording();'));",
    'archive42 recording orchestration contract',
)

# These files are intentionally part of the validated lifecycle migration and
# must remain staged when the workflow later stages the generated source files.
subprocess.run(
    [
        'git',
        'add',
        'test/camera_ready_video_evidence_contract_test.dart',
        'test/video_native_capture_writer_stability_contract_test.dart',
        'test/prelaunch_ui_camera_refinement_contract_test.dart',
        'test/mixed_scene_monitor_regression_test.dart',
        'test/ios_video_watermark_archive42_contract_test.dart',
    ],
    check=True,
)

print('Migrated BUILD72 and lifecycle-dependent legacy camera contracts')
