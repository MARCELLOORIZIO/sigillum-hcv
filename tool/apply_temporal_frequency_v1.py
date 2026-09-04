from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# iOS native bridge: configure the same camera device for a disposable
# high-frame-rate / short-shutter clip, then restore its exact format and modes.
# ---------------------------------------------------------------------------
app_path = Path("ios/Runner/AppDelegate.swift")
app = app_path.read_text()
app = replace_once(app, "import Flutter\n", "import AVFoundation\nimport Flutter\n", "AVFoundation import")
app = replace_once(
    app,
    "  private var storeKit2PriceChannel: FlutterMethodChannel?\n",
    "  private var storeKit2PriceChannel: FlutterMethodChannel?\n  private var cameraProbeChannel: FlutterMethodChannel?\n",
    "camera channel property",
)

native_block = r'''
  private func cameraProbeDevice(uniqueID: String) -> AVCaptureDevice? {
    let deviceTypes: [AVCaptureDevice.DeviceType] = [
      .builtInWideAngleCamera,
      .builtInTelephotoCamera,
      .builtInUltraWideCamera,
      .builtInDualCamera,
      .builtInDualWideCamera,
      .builtInTripleCamera,
      .builtInTrueDepthCamera,
    ]
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: deviceTypes,
      mediaType: .video,
      position: .unspecified
    )
    return discovery.devices.first(where: { $0.uniqueID == uniqueID })
  }

  private func exposureModeName(_ mode: AVCaptureDevice.ExposureMode) -> String {
    switch mode {
    case .locked: return "LOCKED"
    case .autoExpose: return "AUTO_EXPOSE"
    case .continuousAutoExposure: return "CONTINUOUS_AUTO"
    case .custom: return "CUSTOM"
    @unknown default: return "UNKNOWN"
    }
  }

  private func focusModeName(_ mode: AVCaptureDevice.FocusMode) -> String {
    switch mode {
    case .locked: return "LOCKED"
    case .autoFocus: return "AUTO_FOCUS"
    case .continuousAutoFocus: return "CONTINUOUS_AUTO"
    @unknown default: return "UNKNOWN"
    }
  }

  private func whiteBalanceModeName(_ mode: AVCaptureDevice.WhiteBalanceMode) -> String {
    switch mode {
    case .locked: return "LOCKED"
    case .autoWhiteBalance: return "AUTO_WHITE_BALANCE"
    case .continuousAutoWhiteBalance: return "CONTINUOUS_AUTO"
    @unknown default: return "UNKNOWN"
    }
  }

  private func cameraProbeState(_ device: AVCaptureDevice) -> [String: Any] {
    let duration = CMTimeGetSeconds(device.exposureDuration)
    let minDuration = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
    let maxDuration = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
    let activeMinFrame = CMTimeGetSeconds(device.activeVideoMinFrameDuration)
    let activeMaxFrame = CMTimeGetSeconds(device.activeVideoMaxFrameDuration)
    let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    let formatIndex = device.formats.firstIndex(where: { $0 === device.activeFormat }) ?? -1
    let formatMaxFps = device.activeFormat.videoSupportedFrameRateRanges
      .map { $0.maxFrameRate }
      .max() ?? 0.0
    let gains = device.deviceWhiteBalanceGains
    return [
      "deviceUniqueId": device.uniqueID,
      "zoomFactor": Double(device.videoZoomFactor),
      "activeFormatIndex": formatIndex,
      "activeFormatWidth": Int(dimensions.width),
      "activeFormatHeight": Int(dimensions.height),
      "activeFormatMaxSupportedFrameRate": formatMaxFps,
      "activeVideoMinFrameDurationSeconds": activeMinFrame.isFinite ? activeMinFrame : 0.0,
      "activeVideoMaxFrameDurationSeconds": activeMaxFrame.isFinite ? activeMaxFrame : 0.0,
      "exposureMode": exposureModeName(device.exposureMode),
      "exposureDurationSeconds": duration.isFinite ? duration : 0.0,
      "iso": Double(device.iso),
      "minISO": Double(device.activeFormat.minISO),
      "maxISO": Double(device.activeFormat.maxISO),
      "minExposureDurationSeconds": minDuration.isFinite ? minDuration : 0.0,
      "maxExposureDurationSeconds": maxDuration.isFinite ? maxDuration : 0.0,
      "focusMode": focusModeName(device.focusMode),
      "lensPosition": Double(device.lensPosition),
      "whiteBalanceMode": whiteBalanceModeName(device.whiteBalanceMode),
      "whiteBalanceRedGain": Double(gains.redGain),
      "whiteBalanceGreenGain": Double(gains.greenGain),
      "whiteBalanceBlueGain": Double(gains.blueGain),
    ]
  }

  private func cameraProbeDevice(
    from call: FlutterMethodCall,
    result: FlutterResult
  ) -> AVCaptureDevice? {
    guard
      let args = call.arguments as? [String: Any],
      let uniqueID = args["deviceUniqueId"] as? String,
      !uniqueID.isEmpty
    else {
      result(FlutterError(
        code: "CAMERA_PROBE_INVALID_ARGUMENTS",
        message: "Missing iOS camera unique identifier",
        details: nil
      ))
      return nil
    }
    guard let device = cameraProbeDevice(uniqueID: uniqueID) else {
      result(FlutterError(
        code: "CAMERA_PROBE_DEVICE_NOT_FOUND",
        message: "The active iOS camera device could not be resolved",
        details: uniqueID
      ))
      return nil
    }
    return device
  }

  private func clampedWhiteBalanceGains(
    _ gains: AVCaptureDevice.WhiteBalanceGains,
    for device: AVCaptureDevice
  ) -> AVCaptureDevice.WhiteBalanceGains {
    let maxGain = device.maxWhiteBalanceGain
    return AVCaptureDevice.WhiteBalanceGains(
      redGain: min(maxGain, max(1.0, gains.redGain)),
      greenGain: min(maxGain, max(1.0, gains.greenGain)),
      blueGain: min(maxGain, max(1.0, gains.blueGain))
    )
  }

  private func handleCameraProbeCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let device = cameraProbeDevice(from: call, result: result) else {
      return
    }

    switch call.method {
    case "snapshotCameraState":
      result(cameraProbeState(device))

    case "configureTemporalFrequencyProbe":
      let args = call.arguments as? [String: Any]
      let requestedMaxFps = max(30.0, min(240.0, args?["targetMaxFps"] as? Double ?? 240.0))
      var selectedFormat: AVCaptureDevice.Format?
      var selectedFps = 0.0
      var selectedArea: Int64 = 0

      for format in device.formats {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        if dimensions.width < 640 || dimensions.height < 480 { continue }
        let maximum = format.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0.0
        if maximum <= 0 { continue }
        let candidateFps = min(requestedMaxFps, maximum)
        let area = Int64(dimensions.width) * Int64(dimensions.height)
        if candidateFps > selectedFps + 0.01 ||
           (abs(candidateFps - selectedFps) <= 0.01 && area > selectedArea) {
          selectedFormat = format
          selectedFps = candidateFps
          selectedArea = area
        }
      }

      guard let format = selectedFormat, selectedFps > 0 else {
        result(FlutterError(
          code: "HIGH_FPS_FORMAT_UNAVAILABLE",
          message: "No usable video format was found for the temporal frequency probe",
          details: nil
        ))
        return
      }

      do {
        try device.lockForConfiguration()
        device.activeFormat = format
        let frameDuration = CMTimeMakeWithSeconds(
          1.0 / selectedFps,
          preferredTimescale: 1_000_000_000
        )
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
        if device.isExposureModeSupported(.continuousAutoExposure) {
          device.exposureMode = .continuousAutoExposure
        }
        if device.isFocusModeSupported(.continuousAutoFocus) {
          device.focusMode = .continuousAutoFocus
        }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
          device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        device.unlockForConfiguration()
        var state = cameraProbeState(device)
        state["configuredFrameRate"] = selectedFps
        state["requestedTargetMaxFps"] = requestedMaxFps
        result(state)
      } catch {
        result(FlutterError(
          code: "HIGH_FPS_CONFIGURATION_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      }

    case "lockTemporalProbeOptics":
      do {
        try device.lockForConfiguration()
        if device.isFocusModeSupported(.locked) {
          device.setFocusModeLocked(lensPosition: device.lensPosition, completionHandler: nil)
        }
        if device.isWhiteBalanceModeSupported(.locked) {
          let gains = clampedWhiteBalanceGains(device.deviceWhiteBalanceGains, for: device)
          device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        }
        device.unlockForConfiguration()
        result(cameraProbeState(device))
      } catch {
        result(FlutterError(
          code: "OPTICS_LOCK_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      }

    case "applyShortExposure":
      guard
        let args = call.arguments as? [String: Any],
        let requestedDuration = args["targetDurationSeconds"] as? Double,
        requestedDuration > 0
      else {
        result(FlutterError(
          code: "INVALID_EXPOSURE_DURATION",
          message: "A positive target exposure duration is required",
          details: nil
        ))
        return
      }

      let currentDuration = max(
        CMTimeGetSeconds(device.exposureDuration),
        CMTimeGetSeconds(device.activeFormat.minExposureDuration)
      )
      let minimumDuration = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
      let maximumDuration = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
      let adaptiveShortDuration = currentDuration / 4.0
      let targetDurationSeconds = min(
        maximumDuration,
        max(minimumDuration, min(requestedDuration, adaptiveShortDuration))
      )
      let currentISO = max(device.iso, device.activeFormat.minISO)
      let exposureCompensation = currentDuration / max(targetDurationSeconds, 0.000001)
      let compensatedISO = min(
        device.activeFormat.maxISO,
        max(device.activeFormat.minISO, currentISO * Float(exposureCompensation))
      )
      let targetDuration = CMTimeMakeWithSeconds(
        targetDurationSeconds,
        preferredTimescale: 1_000_000_000
      )

      do {
        try device.lockForConfiguration()
        guard device.isExposureModeSupported(.custom) else {
          device.unlockForConfiguration()
          result(FlutterError(
            code: "CUSTOM_EXPOSURE_UNSUPPORTED",
            message: "Custom shutter/ISO exposure is unavailable on this camera",
            details: nil
          ))
          return
        }
        device.setExposureModeCustom(duration: targetDuration, iso: compensatedISO, completionHandler: nil)
        device.unlockForConfiguration()
        var state = cameraProbeState(device)
        state["requestedExposureDurationSeconds"] = requestedDuration
        state["baselineExposureDurationSeconds"] = currentDuration
        state["baselineISO"] = Double(currentISO)
        state["isoCompensationClamped"] = compensatedISO >= device.activeFormat.maxISO - 0.5
        result(state)
      } catch {
        result(FlutterError(
          code: "SHORT_EXPOSURE_CONFIGURATION_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      }

    case "restoreCameraState":
      guard
        let args = call.arguments as? [String: Any],
        let state = args["state"] as? [String: Any]
      else {
        result(FlutterError(
          code: "CAMERA_STATE_MISSING",
          message: "Original camera state is required for restore",
          details: nil
        ))
        return
      }

      do {
        try device.lockForConfiguration()

        if let formatIndex = state["activeFormatIndex"] as? Int,
           formatIndex >= 0,
           formatIndex < device.formats.count {
          device.activeFormat = device.formats[formatIndex]
        }
        if let minFrameSeconds = state["activeVideoMinFrameDurationSeconds"] as? Double,
           minFrameSeconds > 0 {
          device.activeVideoMinFrameDuration = CMTimeMakeWithSeconds(
            minFrameSeconds,
            preferredTimescale: 1_000_000_000
          )
        }
        if let maxFrameSeconds = state["activeVideoMaxFrameDurationSeconds"] as? Double,
           maxFrameSeconds > 0 {
          device.activeVideoMaxFrameDuration = CMTimeMakeWithSeconds(
            maxFrameSeconds,
            preferredTimescale: 1_000_000_000
          )
        }

        let originalExposure = state["exposureMode"] as? String ?? "CONTINUOUS_AUTO"
        if originalExposure == "CUSTOM" && device.isExposureModeSupported(.custom) {
          let durationSeconds = state["exposureDurationSeconds"] as? Double ?? 0.01
          let requestedISO = Float(state["iso"] as? Double ?? Double(device.iso))
          let restoredISO = min(device.activeFormat.maxISO, max(device.activeFormat.minISO, requestedISO))
          let duration = CMTimeMakeWithSeconds(durationSeconds, preferredTimescale: 1_000_000_000)
          device.setExposureModeCustom(duration: duration, iso: restoredISO, completionHandler: nil)
        } else if originalExposure == "LOCKED" && device.isExposureModeSupported(.locked) {
          device.exposureMode = .locked
        } else if originalExposure == "AUTO_EXPOSE" && device.isExposureModeSupported(.autoExpose) {
          device.exposureMode = .autoExpose
        } else if device.isExposureModeSupported(.continuousAutoExposure) {
          device.exposureMode = .continuousAutoExposure
        }

        let originalFocus = state["focusMode"] as? String ?? "CONTINUOUS_AUTO"
        if originalFocus == "LOCKED" && device.isFocusModeSupported(.locked) {
          let lens = Float(state["lensPosition"] as? Double ?? Double(device.lensPosition))
          device.setFocusModeLocked(lensPosition: min(1.0, max(0.0, lens)), completionHandler: nil)
        } else if originalFocus == "AUTO_FOCUS" && device.isFocusModeSupported(.autoFocus) {
          device.focusMode = .autoFocus
        } else if device.isFocusModeSupported(.continuousAutoFocus) {
          device.focusMode = .continuousAutoFocus
        }

        let originalWhiteBalance = state["whiteBalanceMode"] as? String ?? "CONTINUOUS_AUTO"
        if originalWhiteBalance == "LOCKED" && device.isWhiteBalanceModeSupported(.locked) {
          let gains = AVCaptureDevice.WhiteBalanceGains(
            redGain: Float(state["whiteBalanceRedGain"] as? Double ?? 1.0),
            greenGain: Float(state["whiteBalanceGreenGain"] as? Double ?? 1.0),
            blueGain: Float(state["whiteBalanceBlueGain"] as? Double ?? 1.0)
          )
          device.setWhiteBalanceModeLocked(
            with: clampedWhiteBalanceGains(gains, for: device),
            completionHandler: nil
          )
        } else if originalWhiteBalance == "AUTO_WHITE_BALANCE" && device.isWhiteBalanceModeSupported(.autoWhiteBalance) {
          device.whiteBalanceMode = .autoWhiteBalance
        } else if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
          device.whiteBalanceMode = .continuousAutoWhiteBalance
        }

        device.unlockForConfiguration()
        result(cameraProbeState(device))
      } catch {
        result(FlutterError(
          code: "CAMERA_STATE_RESTORE_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

'''
marker = "  @available(iOS 15.0, *)\n  private func trustedStorefrontCurrency(\n"
app = replace_once(app, marker, native_block + marker, "native bridge insertion")

engine_marker = "    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)\n\n    let channel = FlutterMethodChannel(\n"
camera_channel = r'''    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let cameraChannel = FlutterMethodChannel(
      name: "hcv.cameraProbe",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    cameraChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(
          code: "CAMERA_PROBE_UNAVAILABLE",
          message: "Camera probe bridge is unavailable",
          details: nil
        ))
        return
      }
      self.handleCameraProbeCall(call, result: result)
    }
    cameraProbeChannel = cameraChannel

    let channel = FlutterMethodChannel(
'''
app = replace_once(app, engine_marker, camera_channel, "camera channel registration")
app_path.write_text(app)


# ---------------------------------------------------------------------------
# Dart integration. BUILD 80 display fusion remains byte-for-byte untouched;
# the new probe is only captured and serialized into HCV claims.
# ---------------------------------------------------------------------------
camera_path = Path("lib/camera_page.dart")
camera = camera_path.read_text()
camera = replace_once(
    camera,
    "import 'hcv_temporal_capture_probe.dart';\n",
    "import 'hcv_temporal_capture_probe.dart';\nimport 'hcv_temporal_frequency_probe.dart';\n",
    "frequency probe import",
)
camera = replace_once(
    camera,
    "  Map<String, dynamic>? pendingLiveScreenProbe;\n",
    "  Map<String, dynamic>? pendingLiveScreenProbe;\n  HCVTemporalFrequencyClip? pendingTemporalFrequencyClip;\n  Map<String, dynamic>? pendingTemporalFrequencyProbe;\n",
    "pending frequency fields",
)

camera = replace_once(
    camera,
    "    pendingLiveScreenProbe = null;\n    pendingVideoLocation = captureLocation;\n    lastLiveSignals = null;\n",
    "    pendingLiveScreenProbe = null;\n    pendingTemporalFrequencyClip = null;\n    pendingTemporalFrequencyProbe = null;\n    pendingVideoLocation = captureLocation;\n    lastLiveSignals = null;\n",
    "video pending reset",
)

old_start_probe = '''      // VIDEO starts on the user's first REC tap. There is no disposable
      // pre-capture clip and no parallax/geometry gate; display evidence comes
      // from the actual recorded video during post-capture analysis.
      await _settleCameraAfterLiveProbe();
      await controller!.startVideoRecording();
'''
new_start_probe = '''      // BUILD 80 remains the decision baseline. A separate high-speed,
      // short-shutter clip is captured only for shadow physical research and
      // is never supplied to displayRisk fusion.
      const frequencyProbeEngine = HCVTemporalFrequencyProbe();
      try {
        pendingTemporalFrequencyClip =
            await frequencyProbeEngine.capture(controller!);
      } catch (e) {
        pendingTemporalFrequencyProbe = HCVTemporalFrequencyProbe.unavailable(
          'VIDEO_TEMPORAL_FREQUENCY_CAPTURE_FAILED',
          error: e,
        );
      }

      await _settleCameraAfterLiveProbe();
      await controller!.startVideoRecording();
'''
camera = replace_once(camera, old_start_probe, new_start_probe, "video shadow pre-probe")

camera = replace_once(
    camera,
    "    } catch (e) {\n      pendingVideoCapturedAt = null;\n      pendingVideoLocation = null;\n      pendingLiveScreenProbe = null;\n",
    "    } catch (e) {\n      pendingVideoCapturedAt = null;\n      pendingVideoLocation = null;\n      pendingLiveScreenProbe = null;\n      if (pendingTemporalFrequencyClip != null) {\n        await const HCVTemporalFrequencyProbe()\n            .discard(pendingTemporalFrequencyClip!.path);\n      }\n      pendingTemporalFrequencyClip = null;\n      pendingTemporalFrequencyProbe = null;\n",
    "video start failure cleanup",
)

camera = replace_once(
    camera,
    "      await _waitForFinalizedVideoContainer(file.path);\n\n      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();\n",
    "      await _waitForFinalizedVideoContainer(file.path);\n\n      if (pendingTemporalFrequencyClip != null) {\n        pendingTemporalFrequencyProbe =\n            await const HCVTemporalFrequencyProbe()\n                .analyzeCapturedClip(pendingTemporalFrequencyClip!);\n        pendingTemporalFrequencyClip = null;\n      }\n      pendingTemporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(\n        'VIDEO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',\n      );\n\n      final capturedAt = pendingVideoCapturedAt ?? DateTime.now();\n",
    "video shadow analysis after stop",
)

stop_catch = "      pendingVideoCapturedAt = null;\n      pendingVideoLocation = null;\n      pendingLiveScreenProbe = null;\n      try {\n        lastLiveSignals = await liveSignals.stopAndBuildSummary();\n"
stop_catch_new = "      pendingVideoCapturedAt = null;\n      pendingVideoLocation = null;\n      pendingLiveScreenProbe = null;\n      if (pendingTemporalFrequencyClip != null) {\n        await const HCVTemporalFrequencyProbe()\n            .discard(pendingTemporalFrequencyClip!.path);\n      }\n      pendingTemporalFrequencyClip = null;\n      pendingTemporalFrequencyProbe = null;\n      try {\n        lastLiveSignals = await liveSignals.stopAndBuildSummary();\n"
camera = replace_once(camera, stop_catch, stop_catch_new, "video stop failure cleanup")

camera = replace_once(
    camera,
    "    const temporalProbeEngine = HCVTemporalCaptureProbe();\n    HCVTemporalCaptureClip? temporalClip;\n    Map<String, dynamic>? temporalProbe;\n",
    "    const temporalProbeEngine = HCVTemporalCaptureProbe();\n    const frequencyProbeEngine = HCVTemporalFrequencyProbe();\n    HCVTemporalCaptureClip? temporalClip;\n    HCVTemporalFrequencyClip? frequencyClip;\n    Map<String, dynamic>? temporalProbe;\n    Map<String, dynamic>? temporalFrequencyProbe;\n",
    "photo frequency locals",
)

photo_status_block = '''      setState(() {
        status = _c('takingPhoto');
        result = null;
      });

      try {
        temporalClip = await temporalProbeEngine.capture(
'''
photo_status_new = '''      setState(() {
        status = _c('takingPhoto');
        result = null;
      });

      try {
        frequencyClip = await frequencyProbeEngine.capture(controller!);
      } catch (e) {
        temporalFrequencyProbe = HCVTemporalFrequencyProbe.unavailable(
          'PHOTO_TEMPORAL_FREQUENCY_CAPTURE_FAILED',
          error: e,
        );
      }

      try {
        temporalClip = await temporalProbeEngine.capture(
'''
camera = replace_once(camera, photo_status_block, photo_status_new, "photo frequency capture")

camera = replace_once(
    camera,
    "      final savedPhotoPath = await savePhotoToDocuments(file.path);\n\n      if (temporalClip != null) {\n",
    "      final savedPhotoPath = await savePhotoToDocuments(file.path);\n\n      if (frequencyClip != null) {\n        temporalFrequencyProbe =\n            await frequencyProbeEngine.analyzeCapturedClip(frequencyClip);\n        frequencyClip = null;\n      }\n      temporalFrequencyProbe ??= HCVTemporalFrequencyProbe.unavailable(\n        'PHOTO_TEMPORAL_FREQUENCY_NOT_AVAILABLE',\n      );\n\n      if (temporalClip != null) {\n",
    "photo frequency analysis",
)

camera = replace_once(
    camera,
    '        "liveScreenProbe": liveScreenProbe,\n        "physicalSceneClass": liveScreenProbe["sceneClass"] ?? "UNKNOWN",\n',
    '        "liveScreenProbe": liveScreenProbe,\n        "temporalFrequencyProbe": temporalFrequencyProbe,\n        "physicalSceneClass": liveScreenProbe["sceneClass"] ?? "UNKNOWN",\n',
    "photo frequency claim",
)

camera = replace_once(
    camera,
    "    } catch (e) {\n      if (temporalClip != null) {\n        await temporalProbeEngine.discard(temporalClip.path);\n      }\n",
    "    } catch (e) {\n      if (frequencyClip != null) {\n        await frequencyProbeEngine.discard(frequencyClip.path);\n      }\n      if (temporalClip != null) {\n        await temporalProbeEngine.discard(temporalClip.path);\n      }\n",
    "photo frequency failure cleanup",
)

camera = replace_once(
    camera,
    "    final liveScreenProbe = pendingLiveScreenProbe;\n    pendingLiveScreenProbe = null;\n    final effectiveCapturedAt = capturedAt ?? DateTime.now();\n",
    "    final liveScreenProbe = pendingLiveScreenProbe;\n    pendingLiveScreenProbe = null;\n    final temporalFrequencyProbe = pendingTemporalFrequencyProbe;\n    pendingTemporalFrequencyProbe = null;\n    final effectiveCapturedAt = capturedAt ?? DateTime.now();\n",
    "video frequency claim capture",
)

camera = replace_once(
    camera,
    '      "liveScreenProbe": liveScreenProbe,\n      "physicalSceneClass": liveScreenProbe?["sceneClass"] ?? "UNKNOWN",\n',
    '      "liveScreenProbe": liveScreenProbe,\n      "temporalFrequencyProbe": temporalFrequencyProbe,\n      "physicalSceneClass": liveScreenProbe?["sceneClass"] ?? "UNKNOWN",\n',
    "video frequency claim",
)

camera_path.write_text(camera)

# Contract check: the new probe must never be inserted into either display-risk
# analysis list. This is deliberately textual and fail-closed.
if "screenReplayAnalyses = [\n      temporalFrequencyProbe" in camera:
    raise SystemExit("Temporal frequency probe leaked into display fusion")
if "screenReplayAnalyses = [\n        temporalFrequencyProbe" in camera:
    raise SystemExit("Temporal frequency probe leaked into photo display fusion")

print("Temporal frequency V1 patch materialized successfully")
