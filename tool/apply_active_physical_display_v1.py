from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:120]!r}')
    if text.count(old) != 1:
        raise SystemExit(f'pattern not unique in {path}: {text.count(old)}')
    p.write_text(text.replace(old, new, 1))

# 1) Allow the physical acquisition engine to run 1x-only for VIDEO.
replace_once(
    'lib/hcv_display_microtexture_probe.dart',
    '  Future<Map<String, dynamic>> capture(CameraController controller) async {',
    '  Future<Map<String, dynamic>> capture(\n'
    '    CameraController controller, {\n'
    '    bool includeZoomProbe = true,\n'
    '  }) async {',
)

old_zoom = """      await _invokeMap('setContinuousAutoExposure', {
        'deviceUniqueId': uniqueId,
      });
      await controller.setZoomLevel(tenX);
      await Future.delayed(_zoomSettle);
      await phase('NORMAL_10X', tenX, 'CONTINUOUS_AUTO');

      await _invokeMap('applyShortExposure', {
        'deviceUniqueId': uniqueId,
        'targetDurationSeconds': _requestedShortExposure,
      });
      await Future.delayed(_exposureSettle);
      await phase('SHORT_10X', tenX, 'CUSTOM_SHORT');
"""
new_zoom = """      if (includeZoomProbe) {
        await _invokeMap('setContinuousAutoExposure', {
          'deviceUniqueId': uniqueId,
        });
        await controller.setZoomLevel(tenX);
        await Future.delayed(_zoomSettle);
        await phase('NORMAL_10X', tenX, 'CONTINUOUS_AUTO');

        await _invokeMap('applyShortExposure', {
          'deviceUniqueId': uniqueId,
          'targetDurationSeconds': _requestedShortExposure,
        });
        await Future.delayed(_exposureSettle);
        await phase('SHORT_10X', tenX, 'CUSTOM_SHORT');
      }
"""
replace_once('lib/hcv_display_microtexture_probe.dart', old_zoom, new_zoom)
replace_once(
    'lib/hcv_display_microtexture_probe.dart',
    "        'targetZoom': tenX,\n",
    "        'targetZoom': includeZoomProbe ? tenX : oneX,\n"
    "        'probeMode': includeZoomProbe ? 'PHOTO_1X_10X' : 'VIDEO_1X_ONLY',\n",
)

# 2) Add a disposable 1x normal/short-shutter probe for VIDEO before the real REC.
marker = """  /// Analyzes the unchanged BUILD 80 clip and, independently, the new shadow
"""
method = """  Future<Map<String, dynamic>> captureActiveVideoPhysicalProbe(
    CameraController controller,
  ) async {
    final engine = const HCVDisplayMicrotextureShadowProbe();
    Map<String, dynamic>? capture;
    try {
      capture = await engine.capture(controller, includeZoomProbe: false);
      final analysis = await engine.analyzeCapture(capture);
      final deleted = await engine.discardCapture(capture);
      return {
        'type': 'SIGILLUM_VIDEO_PHYSICAL_PRECAPTURE_PROBE_V1',
        'analysisStatus': analysis['analysisStatus'] ?? 'NOT_ANALYZED',
        'decisionRole': 'ACTIVE_PHYSICAL_DISCRIMINATOR',
        'capture': _redactShadowPath(capture),
        'analysis': analysis,
        'temporaryVideoDeletedAfterAnalysis': deleted,
        'recordedVideoContainsProbe': false,
        'zoomVisibleInRecordedVideo': false,
        'probeZoom': '1X_ONLY',
      };
    } catch (error) {
      if (capture != null) {
        await engine.discardCapture(capture);
      }
      return {
        'type': 'SIGILLUM_VIDEO_PHYSICAL_PRECAPTURE_PROBE_V1',
        'analysisStatus': 'NOT_ANALYZED',
        'decisionRole': 'ACTIVE_PHYSICAL_DISCRIMINATOR',
        'reason': 'VIDEO_PHYSICAL_PRECAPTURE_PROBE_FAILED',
        'error': error.toString(),
        'recordedVideoContainsProbe': false,
      };
    }
  }

"""
replace_once('lib/hcv_temporal_capture_probe.dart', marker, method + marker)

# 3) Wire active decision gate into PHOTO and VIDEO.
replace_once(
    'lib/camera_page.dart',
    "import 'hcv_display_risk_fusion.dart';\n",
    "import 'hcv_display_risk_fusion.dart';\nimport 'hcv_physical_display_discriminator.dart';\n",
)
replace_once(
    'lib/camera_page.dart',
    "  Map<String, dynamic>? pendingLiveScreenProbe;\n",
    "  Map<String, dynamic>? pendingLiveScreenProbe;\n"
    "  Map<String, dynamic>? pendingVideoPhysicalDisplayProbe;\n",
)
replace_once(
    'lib/camera_page.dart',
    "    pendingLiveScreenProbe = null;\n    pendingVideoLocation = captureLocation;\n",
    "    pendingLiveScreenProbe = null;\n"
    "    pendingVideoPhysicalDisplayProbe = null;\n"
    "    pendingVideoLocation = captureLocation;\n",
)
replace_once(
    'lib/camera_page.dart',
    """      // VIDEO starts on the user's first REC tap. There is no disposable
      // pre-capture clip and no parallax/geometry gate; display evidence comes
      // from the actual recorded video during post-capture analysis.
      await _settleCameraAfterLiveProbe();
      await controller!.startVideoRecording();
""",
    """      // Active physical VIDEO gate: a disposable 1x-only normal/short-shutter
      // probe runs before the real recording. It is deleted and never appears in
      // the user's recorded video. No 10x zoom is used for VIDEO.
      pendingVideoPhysicalDisplayProbe =
          await const HCVTemporalCaptureProbe().captureActiveVideoPhysicalProbe(
        controller!,
      );
      await _settleCameraAfterLiveProbe();
      await controller!.startVideoRecording();
""",
)
replace_once(
    'lib/camera_page.dart',
    "      pendingLiveScreenProbe = null;\n      setState(() {\n        recording = false;\n",
    "      pendingLiveScreenProbe = null;\n"
    "      pendingVideoPhysicalDisplayProbe = null;\n"
    "      setState(() {\n        recording = false;\n",
)

old_photo = """      final displayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(
        screenReplayAnalyses,
      );
      final detectedScreenReplayRisk = displayRisk.risk;
"""
new_photo = """      final baseDisplayRisk = combinePhotoDisplayRiskFromPreCaptureEvidence(
        screenReplayAnalyses,
      );
      final photoPhysicalAnalysis =
          HCVPhysicalDisplayDiscriminator.analysisFromPhotoTemporalProbe(
        temporalProbe,
      );
      final physicalDisplayDiscriminator =
          HCVPhysicalDisplayDiscriminator.evaluate(photoPhysicalAnalysis);
      final displayRisk = HCVPhysicalDisplayDiscriminator.apply(
        base: baseDisplayRisk,
        physicalAnalysis: photoPhysicalAnalysis,
      );
      final detectedScreenReplayRisk = displayRisk.risk;
"""
replace_once('lib/camera_page.dart', old_photo, new_photo)
replace_once(
    'lib/camera_page.dart',
    '        "displayRiskEvidence": displayRisk.toJson(),\n        "aiProofLevel": "STILL_IMAGE_CAPTURE_V1",\n',
    '        "displayRiskEvidence": displayRisk.toJson(),\n'
    '        "physicalDisplayDiscriminator": physicalDisplayDiscriminator,\n'
    '        "aiProofLevel": "STILL_IMAGE_CAPTURE_V1",\n',
)

replace_once(
    'lib/camera_page.dart',
    """    final liveScreenProbe = pendingLiveScreenProbe;
    pendingLiveScreenProbe = null;
    final effectiveCapturedAt = capturedAt ?? DateTime.now();
""",
    """    final liveScreenProbe = pendingLiveScreenProbe;
    pendingLiveScreenProbe = null;
    final videoPhysicalDisplayProbe = pendingVideoPhysicalDisplayProbe;
    pendingVideoPhysicalDisplayProbe = null;
    final effectiveCapturedAt = capturedAt ?? DateTime.now();
""",
)
old_video = """    final displayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
    );
    final detectedScreenReplayRisk = displayRisk.risk;
"""
new_video = """    final baseDisplayRisk = combineVideoDisplayRiskFromCaptureEvidence(
      screenReplayAnalyses,
    );
    final videoPhysicalAnalysisRaw = videoPhysicalDisplayProbe?['analysis'];
    final videoPhysicalAnalysis = videoPhysicalAnalysisRaw is Map
        ? Map<String, dynamic>.from(videoPhysicalAnalysisRaw)
        : null;
    final physicalDisplayDiscriminator =
        HCVPhysicalDisplayDiscriminator.evaluate(videoPhysicalAnalysis);
    final displayRisk = HCVPhysicalDisplayDiscriminator.apply(
      base: baseDisplayRisk,
      physicalAnalysis: videoPhysicalAnalysis,
    );
    final detectedScreenReplayRisk = displayRisk.risk;
"""
replace_once('lib/camera_page.dart', old_video, new_video)
replace_once(
    'lib/camera_page.dart',
    '      "displayRiskEvidence": displayRisk.toJson(),\n      "aiProofLevel": "PASSIVE_LIVE_CAPTURE_V1",\n',
    '      "displayRiskEvidence": displayRisk.toJson(),\n'
    '      "physicalDisplayDiscriminator": physicalDisplayDiscriminator,\n'
    '      "physicalDisplayProbe": videoPhysicalDisplayProbe,\n'
    '      "aiProofLevel": "ACTIVE_PHYSICAL_PLUS_PASSIVE_LIVE_CAPTURE_V1",\n',
)

print('ACTIVE_PHYSICAL_DISPLAY_V1_PATCH_APPLIED')
