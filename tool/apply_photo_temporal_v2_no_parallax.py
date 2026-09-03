from pathlib import Path

CAMERA = Path('lib/camera_page.dart')
source = CAMERA.read_text(encoding='utf-8')
original = source

capture_end = '''      } catch (e) {
        temporalProbe = _photoTemporalV2Unavailable(
          'PHOTO_TEMPORAL_CAPTURE_FAILED',
          error: e,
        );
      }

      await _settleCameraAfterLiveProbe();
'''
flash_restore = '''      } catch (e) {
        temporalProbe = _photoTemporalV2Unavailable(
          'PHOTO_TEMPORAL_CAPTURE_FAILED',
          error: e,
        );
      }

      // The technical temporal clip is always captured with flash disabled.
      // Restore the user's selected photo flash/torch before the real still.
      if (currentFlashMode != FlashMode.off &&
          controller!.value.isInitialized) {
        try {
          await controller!.setFlashMode(currentFlashMode);
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (_) {}
      }

      await _settleCameraAfterLiveProbe();
'''
if capture_end not in source:
    raise SystemExit('Missing Temporal V2 capture-end block for flash restore')
source = source.replace(capture_end, flash_restore, 1)

photo_error = '''    } catch (e) {
      setState(() {
        status = '${_c('photoError')}: $e';
      });
    }
  }
'''
photo_error_with_cleanup = '''    } catch (e) {
      if (temporalClip != null) {
        await temporalProbeEngine.discard(temporalClip.path);
      }
      setState(() {
        status = '${_c('photoError')}: $e';
      });
    }
  }
'''
if photo_error not in source:
    raise SystemExit('Missing photo error block for temporal clip cleanup')
source = source.replace(photo_error, photo_error_with_cleanup, 1)

for expected in (
    "PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT",
    "await temporalProbeEngine.capture(",
    "await controller!.takePicture();",
    "await controller!.startVideoRecording();",
    "await controller!.setFlashMode(currentFlashMode);",
    "await temporalProbeEngine.discard(temporalClip.path);",
):
    if expected not in source:
        raise SystemExit(f'Missing required Temporal V2 token: {expected}')

if source == original:
    raise SystemExit('No follow-up changes produced')

CAMERA.write_text(source, encoding='utf-8')
print('Temporal V2 follow-up applied: flash restore + temporary clip cleanup')
