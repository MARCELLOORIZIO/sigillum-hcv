import AVFoundation
import CoreVideo
import Flutter
import Foundation
import StoreKit
import UIKit


private final class HCVTemporalFrequencyNativeCollector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let targetFrameCount: Int
  private let rowBins: Int
  private let completion: ([String: Any]) -> Void
  private let lock = NSLock()
  private var frames: [[[Double]]] = []
  private var timestamps: [Double] = []
  private var frameLuma: [Double] = []
  private var finished = false

  init(
    targetFrameCount: Int,
    rowBins: Int,
    completion: @escaping ([String: Any]) -> Void
  ) {
    self.targetFrameCount = targetFrameCount
    self.rowBins = rowBins
    self.completion = completion
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    lock.lock()
    let shouldProcess = !finished && frames.count < targetFrameCount
    lock.unlock()
    guard shouldProcess,
          CMSampleBufferDataIsReady(sampleBuffer),
          let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let extracted = rowProfiles(from: pixelBuffer) else {
      return
    }

    let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    guard pts.isFinite else { return }

    var completedPayload: [String: Any]?
    lock.lock()
    if !finished {
      frames.append(extracted.profiles)
      timestamps.append(pts)
      frameLuma.append(extracted.meanLuma)
      if frames.count >= targetFrameCount {
        finished = true
        completedPayload = snapshotLocked()
      }
    }
    lock.unlock()

    if let completedPayload {
      completion(completedPayload)
    }
  }

  func snapshotAndFinish() -> [String: Any] {
    lock.lock()
    finished = true
    let snapshot = snapshotLocked()
    lock.unlock()
    return snapshot
  }

  private func snapshotLocked() -> [String: Any] {
    return [
      "frames": frames,
      "frameTimestampsSeconds": timestamps,
      "frameLuma": frameLuma,
      "frameCount": frames.count,
    ]
  }

  private func rowProfiles(
    from pixelBuffer: CVPixelBuffer
  ) -> (profiles: [[Double]], meanLuma: Double)? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
          let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
      return nil
    }

    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    guard width >= 3, height >= 3, bytesPerRow >= width else { return nil }

    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    var result: [[Double]] = []
    result.reserveCapacity(9)
    var total = 0.0
    var totalCount = 0

    for gridRow in 0..<3 {
      for gridColumn in 0..<3 {
        let x0 = width * gridColumn / 3
        let x1 = width * (gridColumn + 1) / 3
        let y0 = height * gridRow / 3
        let y1 = height * (gridRow + 1) / 3
        let xStep = max(1, (x1 - x0) / 16)
        var profile: [Double] = []
        profile.reserveCapacity(rowBins)

        for bin in 0..<rowBins {
          let by0 = y0 + (y1 - y0) * bin / rowBins
          let next = y0 + (y1 - y0) * (bin + 1) / rowBins
          let by1 = min(y1, max(by0 + 1, next))
          var sum = 0.0
          var count = 0
          if by0 < y1 {
            for y in by0..<by1 {
              var x = x0
              while x < x1 {
                sum += Double(bytes[y * bytesPerRow + x]) / 255.0
                count += 1
                x += xStep
              }
            }
          }
          let value = count > 0 ? sum / Double(count) : 0.0
          profile.append(value)
          total += value
          totalCount += 1
        }
        result.append(profile)
      }
    }

    return (result, totalCount > 0 ? total / Double(totalCount) : 0.0)
  }
}


private final class HCVIlluminationResponseNativeCollector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let maxFramesPerPhase: Int
  private let lock = NSLock()
  private var phase = -1
  private var phaseFrames: [[[Double]]] = [[], [], []]

  init(maxFramesPerPhase: Int = 12) {
    self.maxFramesPerPhase = maxFramesPerPhase
  }

  func setPhase(_ value: Int) {
    lock.lock()
    phase = value
    lock.unlock()
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard CMSampleBufferDataIsReady(sampleBuffer),
          let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let cells = cellMeans(from: pixelBuffer) else { return }
    lock.lock()
    let current = phase
    if current >= 0 && current < 3 && phaseFrames[current].count < maxFramesPerPhase {
      phaseFrames[current].append(cells)
    }
    lock.unlock()
  }

  func snapshot() -> [[[Double]]] {
    lock.lock()
    let copy = phaseFrames
    lock.unlock()
    return copy
  }

  private func cellMeans(from pixelBuffer: CVPixelBuffer) -> [Double]? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
          let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    guard width >= 6, height >= 6, bytesPerRow >= width else { return nil }
    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    var result: [Double] = []
    result.reserveCapacity(9)
    for gridRow in 0..<3 {
      for gridColumn in 0..<3 {
        let x0 = width * gridColumn / 3
        let x1 = width * (gridColumn + 1) / 3
        let y0 = height * gridRow / 3
        let y1 = height * (gridRow + 1) / 3
        let xStep = max(1, (x1 - x0) / 24)
        let yStep = max(1, (y1 - y0) / 24)
        var sum = 0.0
        var count = 0
        var y = y0
        while y < y1 {
          var x = x0
          while x < x1 {
            sum += Double(bytes[y * bytesPerRow + x]) / 255.0
            count += 1
            x += xStep
          }
          y += yStep
        }
        result.append(count > 0 ? sum / Double(count) : 0.0)
      }
    }
    return result
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var storeKit2PriceChannel: FlutterMethodChannel?
  private var cameraProbeChannel: FlutterMethodChannel?
  private let temporalFrequencyNativeQueue = DispatchQueue(
    label: "hcv.temporalFrequency.native",
    qos: .userInitiated
  )
  private let temporalFrequencySampleQueue = DispatchQueue(
    label: "hcv.temporalFrequency.samples",
    qos: .userInteractive
  )
  private let temporalFrequencyFinishLock = NSLock()
  private var temporalFrequencyNativeBusy = false
  private var temporalFrequencyResultDelivered = false
  private var temporalFrequencyNativeSession: AVCaptureSession?
  private var temporalFrequencyNativeCollector: HCVTemporalFrequencyNativeCollector?
  private var illuminationResponseNativeBusy = false
  private var illuminationResponseNativeSession: AVCaptureSession?
  private var illuminationResponseNativeCollector: HCVIlluminationResponseNativeCollector?
  private var storefrontUpdatesTask: Task<Void, Never>?
  private var storefrontBaselineFingerprint = ""
  private var storefrontSessionFresh = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }


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

  private func temporalFrequencyPhysicalDevice(
    for device: AVCaptureDevice
  ) -> AVCaptureDevice {
    // High-frame-rate activeFormat changes are safer on a physical camera than
    // on Apple's virtual dual/triple camera devices. Preserve front/back
    // position but resolve the physical wide-angle constituent when available.
    if device.isVirtualDevice,
       let wide = AVCaptureDevice.default(
         .builtInWideAngleCamera,
         for: .video,
         position: device.position
       ) {
      return wide
    }
    return device
  }

  private func temporalFrequencyFormat(
    for device: AVCaptureDevice,
    requestedMaxFps: Double
  ) -> (format: AVCaptureDevice.Format, range: AVFrameRateRange, fps: Double)? {
    let tiers = [240.0, 120.0, 60.0].filter { $0 <= requestedMaxFps + 0.01 }
    for tier in tiers {
      var bestFormat: AVCaptureDevice.Format?
      var bestRange: AVFrameRateRange?
      var bestArea: Int64 = Int64.max
      let tolerance = max(0.5, tier * 0.01)

      for format in device.formats {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        if dimensions.width < 640 || dimensions.height < 480 { continue }

        for range in format.videoSupportedFrameRateRanges {
          // Use an endpoint duration supplied by AVFoundation itself. BUILD 90
          // constructed 1/fps as a new CMTime; iOS may reject that value with
          // NSInvalidArgumentException even when the numeric fps looks valid.
          if abs(range.maxFrameRate - tier) > tolerance { continue }
          let area = Int64(dimensions.width) * Int64(dimensions.height)
          if bestFormat == nil || area < bestArea {
            bestFormat = format
            bestRange = range
            bestArea = area
          }
        }
      }

      if let bestFormat, let bestRange {
        return (bestFormat, bestRange, bestRange.maxFrameRate)
      }
    }
    return nil
  }

  private func resetTemporalFrequencyOpticsForFlutterHandoff(
    _ device: AVCaptureDevice
  ) -> [String: Any] {
    var metadata: [String: Any] = [
      "requestedFocusMode": "CONTINUOUS_AUTO",
      "requestedExposureMode": "CONTINUOUS_AUTO",
      "requestedWhiteBalanceMode": "CONTINUOUS_AUTO",
      "centerFocusPointRequested": true,
      "autoFocusRangeRestrictionRequested": "NONE",
      "resetApplied": false,
    ]

    do {
      try device.lockForConfiguration()

      if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
      }
      if device.isAutoFocusRangeRestrictionSupported {
        device.autoFocusRangeRestriction = .none
      }
      if device.isFocusModeSupported(.continuousAutoFocus) {
        device.focusMode = .continuousAutoFocus
      }

      if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
      }
      if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
      }
      if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
        device.whiteBalanceMode = .continuousAutoWhiteBalance
      }
      device.isSubjectAreaChangeMonitoringEnabled = true

      device.unlockForConfiguration()

      metadata["resetApplied"] = true
      metadata["focusModeAfterReset"] = focusModeName(device.focusMode)
      metadata["lensPositionAfterReset"] = Double(device.lensPosition)
      metadata["exposureModeAfterReset"] = exposureModeName(device.exposureMode)
      metadata["whiteBalanceModeAfterReset"] = whiteBalanceModeName(device.whiteBalanceMode)
      metadata["subjectAreaChangeMonitoringEnabled"] = device.isSubjectAreaChangeMonitoringEnabled
    } catch {
      metadata["resetError"] = error.localizedDescription
    }
    return metadata
  }

  private func finishTemporalFrequencyNativeCapture(
    session: AVCaptureSession,
    output: AVCaptureVideoDataOutput,
    device: AVCaptureDevice,
    payload: [String: Any],
    result: @escaping FlutterResult
  ) {
    temporalFrequencyFinishLock.lock()
    if temporalFrequencyResultDelivered {
      temporalFrequencyFinishLock.unlock()
      return
    }
    temporalFrequencyResultDelivered = true
    temporalFrequencyFinishLock.unlock()

    temporalFrequencyNativeQueue.async { [weak self] in
      output.setSampleBufferDelegate(nil, queue: nil)
      if session.isRunning {
        session.stopRunning()
      }

      var finalPayload = payload
      if let self {
        // The HFR probe intentionally locks focus while collecting the short
        // sample. Never hand that locked optical state back to Flutter.
        finalPayload["cameraHandoffAfterNativeProbe"] =
          self.resetTemporalFrequencyOpticsForFlutterHandoff(device)
        self.temporalFrequencyNativeCollector = nil
        self.temporalFrequencyNativeSession = nil
        self.temporalFrequencyNativeBusy = false
      }
      DispatchQueue.main.async {
        result(finalPayload)
      }
    }
  }

  private func captureTemporalFrequencyNative(
    device: AVCaptureDevice,
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    if temporalFrequencyNativeBusy {
      result(FlutterError(
        code: "TEMPORAL_FREQUENCY_NATIVE_BUSY",
        message: "A native temporal-frequency capture is already running",
        details: nil
      ))
      return
    }

    let args = call.arguments as? [String: Any]
    let requestedMaxFps = max(
      60.0,
      min(240.0, args?["targetMaxFps"] as? Double ?? 240.0)
    )
    let requestedDuration = max(
      0.20,
      min(0.75, args?["targetDurationSeconds"] as? Double ?? 0.35)
    )
    let requestedExposure = max(
      0.0001,
      min(0.004, args?["targetExposureSeconds"] as? Double ?? 0.001)
    )
    let rowBins = max(24, min(128, args?["rowProfileBins"] as? Int ?? 96))

    temporalFrequencyNativeBusy = true
    temporalFrequencyFinishLock.lock()
    temporalFrequencyResultDelivered = false
    temporalFrequencyFinishLock.unlock()

    temporalFrequencyNativeQueue.async { [weak self] in
      guard let self else { return }
      let captureDevice = self.temporalFrequencyPhysicalDevice(for: device)
      do {
        guard let selection = self.temporalFrequencyFormat(
          for: captureDevice,
          requestedMaxFps: requestedMaxFps
        ) else {
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No 60/120/240 fps native format available"]
          )
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        let input = try AVCaptureDeviceInput(device: captureDevice)
        guard session.canAddInput(input) else {
          session.commitConfiguration()
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Native camera input unavailable"]
          )
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        // Never allow an expensive high-speed analysis callback to build an
        // unbounded CVPixelBuffer backlog. Timestamp analysis will reveal any
        // dropped sample instead of risking process termination.
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String:
            Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        guard session.canAddOutput(output) else {
          session.commitConfiguration()
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Native video data output unavailable"]
          )
        }
        session.addOutput(output)

        try captureDevice.lockForConfiguration()
        captureDevice.activeFormat = selection.format
        // Use the exact hardware-supported CMTime from AVFrameRateRange.
        // Assigning a reconstructed reciprocal can raise NSInvalidArgumentException.
        let frameDuration = selection.range.minFrameDuration
        captureDevice.activeVideoMinFrameDuration = frameDuration
        captureDevice.activeVideoMaxFrameDuration = frameDuration
        if captureDevice.isExposureModeSupported(.continuousAutoExposure) {
          captureDevice.exposureMode = .continuousAutoExposure
        }
        if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
          captureDevice.focusMode = .continuousAutoFocus
        }
        if captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
          captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        captureDevice.unlockForConfiguration()
        session.commitConfiguration()

        self.temporalFrequencyNativeSession = session
        session.startRunning()
        guard session.isRunning else {
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Native high-speed session failed to start"]
          )
        }

        // Let AE settle in the selected high-speed format before locking the
        // optics and applying the requested short shutter.
        Thread.sleep(forTimeInterval: 0.18)
        let baselineDuration = max(
          CMTimeGetSeconds(captureDevice.exposureDuration),
          CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration)
        )
        let baselineISO = max(captureDevice.iso, captureDevice.activeFormat.minISO)
        let minExposure = CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration)
        let maxExposure = min(
          CMTimeGetSeconds(captureDevice.activeFormat.maxExposureDuration),
          0.9 / selection.fps
        )
        let targetExposure = min(
          maxExposure,
          max(minExposure, requestedExposure)
        )
        let compensation = baselineDuration / max(targetExposure, 0.000001)
        let compensatedISO = min(
          captureDevice.activeFormat.maxISO,
          max(captureDevice.activeFormat.minISO, baselineISO * Float(compensation))
        )
        let targetDuration = CMTimeMakeWithSeconds(
          targetExposure,
          preferredTimescale: 1_000_000_000
        )

        let exposureSemaphore = DispatchSemaphore(value: 0)
        try captureDevice.lockForConfiguration()
        if captureDevice.isFocusModeSupported(.locked) {
          captureDevice.setFocusModeLocked(
            lensPosition: captureDevice.lensPosition,
            completionHandler: nil
          )
        }
        if captureDevice.isWhiteBalanceModeSupported(.locked) {
          let gains = self.clampedWhiteBalanceGains(
            captureDevice.deviceWhiteBalanceGains,
            for: captureDevice
          )
          captureDevice.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        }
        guard captureDevice.isExposureModeSupported(.custom) else {
          captureDevice.unlockForConfiguration()
          throw NSError(
            domain: "SIGILLUMTemporalFrequency",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Custom exposure unavailable"]
          )
        }
        captureDevice.setExposureModeCustom(
          duration: targetDuration,
          iso: compensatedISO
        ) { _ in
          exposureSemaphore.signal()
        }
        captureDevice.unlockForConfiguration()
        _ = exposureSemaphore.wait(timeout: .now() + 0.8)
        Thread.sleep(forTimeInterval: 0.03)

        let actualExposure = CMTimeGetSeconds(captureDevice.exposureDuration)
        let actualISO = Double(captureDevice.iso)
        let exposureTolerance = max(0.00015, targetExposure * 0.20)
        let exposureVerified = actualExposure.isFinite &&
          abs(actualExposure - targetExposure) <= exposureTolerance
        let dimensions = CMVideoFormatDescriptionGetDimensions(
          selection.format.formatDescription
        )
        let formatMaxFps = selection.format.videoSupportedFrameRateRanges
          .map { $0.maxFrameRate }
          .max() ?? selection.fps
        let targetFrameCount = max(
          24,
          min(120, Int((requestedDuration * selection.fps).rounded()))
        )

        let metadata: [String: Any] = [
          "analysisStatus": "CAPTURED",
          "captureMode": "ISOLATED_NATIVE_AVCAPTURESESSION_CMSAMPLEBUFFER",
          "requestedDeviceUniqueId": device.uniqueID,
          "physicalCaptureDeviceUniqueId": captureDevice.uniqueID,
          "physicalDeviceSubstitutionUsed": captureDevice.uniqueID != device.uniqueID,
          "requestedTargetFps": requestedMaxFps,
          "configuredFrameRate": selection.fps,
          "frameRateTier": Int(selection.fps.rounded()),
          "frameWidth": Int(dimensions.width),
          "frameHeight": Int(dimensions.height),
          "configuredFormatMaxSupportedFrameRate": formatMaxFps,
          "requestedShortExposureSeconds": requestedExposure,
          "targetShortExposureSecondsAfterClamp": targetExposure,
          "actualShortExposureSeconds": actualExposure,
          "shortExposureVerified": exposureVerified,
          "shortExposureISO": actualISO,
          "shortExposureISOClamped": compensatedISO >= captureDevice.activeFormat.maxISO - 0.5,
          "exposureLockedForEntireNativeCapture": true,
          "targetFrameCount": targetFrameCount,
          "rowProfileBins": rowBins,
          "sensorNativeOrientation": true,
          "encodedVideoUsed": false,
        ]

        let collector = HCVTemporalFrequencyNativeCollector(
          targetFrameCount: targetFrameCount,
          rowBins: rowBins
        ) { [weak self] snapshot in
          guard let self else { return }
          var payload = metadata
          for (key, value) in snapshot {
            payload[key] = value
          }
          let timestamps = snapshot["frameTimestampsSeconds"] as? [Double] ?? []
          if timestamps.count >= 2,
             let first = timestamps.first,
             let last = timestamps.last,
             last > first {
            payload["actualFrameRate"] = Double(timestamps.count - 1) / (last - first)
            payload["captureDurationMs"] = Int(((last - first) * 1000.0).rounded())
          }
          self.finishTemporalFrequencyNativeCapture(
            session: session,
            output: output,
            device: captureDevice,
            payload: payload,
            result: result
          )
        }
        self.temporalFrequencyNativeCollector = collector
        output.setSampleBufferDelegate(
          collector,
          queue: self.temporalFrequencySampleQueue
        )

        // Timeout protects against a device/format that advertises a tier but
        // does not deliver the requested number of sample buffers in practice.
        self.temporalFrequencyNativeQueue.asyncAfter(
          deadline: .now() + requestedDuration + 0.75
        ) { [weak self, weak collector] in
          guard let self, let collector else { return }
          let snapshot = collector.snapshotAndFinish()
          var payload = metadata
          for (key, value) in snapshot {
            payload[key] = value
          }
          let count = snapshot["frameCount"] as? Int ?? 0
          if count < 6 {
            payload["analysisStatus"] = "NOT_ANALYZED"
            payload["reason"] = "NATIVE_SAMPLEBUFFER_TIMEOUT"
          }
          let timestamps = snapshot["frameTimestampsSeconds"] as? [Double] ?? []
          if timestamps.count >= 2,
             let first = timestamps.first,
             let last = timestamps.last,
             last > first {
            payload["actualFrameRate"] = Double(timestamps.count - 1) / (last - first)
            payload["captureDurationMs"] = Int(((last - first) * 1000.0).rounded())
          }
          self.finishTemporalFrequencyNativeCapture(
            session: session,
            output: output,
            device: captureDevice,
            payload: payload,
            result: result
          )
        }
      } catch {
        if let runningSession = self.temporalFrequencyNativeSession,
           runningSession.isRunning {
          runningSession.stopRunning()
        }
        // Error paths must also release the focus lock; otherwise the next
        // Flutter session can inherit a stale lens position.
        _ = self.resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)
        self.temporalFrequencyNativeCollector = nil
        self.temporalFrequencyNativeSession = nil
        self.temporalFrequencyNativeBusy = false
        DispatchQueue.main.async {
          result(FlutterError(
            code: "TEMPORAL_FREQUENCY_NATIVE_CAPTURE_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }


  private func captureIlluminationResponseNative(
    device: AVCaptureDevice,
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    if illuminationResponseNativeBusy {
      result(FlutterError(code: "ILLUMINATION_RESPONSE_BUSY", message: "Illumination response capture already running", details: nil))
      return
    }
    let captureDevice = temporalFrequencyPhysicalDevice(for: device)
    guard captureDevice.hasTorch, captureDevice.isTorchModeSupported(.on) else {
      result([
        "analysisStatus": "NOT_ANALYZED",
        "reason": "TORCH_UNAVAILABLE_ON_ACTIVE_PHYSICAL_CAMERA",
        "physicalCaptureDeviceUniqueId": captureDevice.uniqueID,
      ])
      return
    }
    let args = call.arguments as? [String: Any]
    let torchLevel = Float(max(0.1, min(0.6, args?["torchLevel"] as? Double ?? 0.30)))
    illuminationResponseNativeBusy = true

    temporalFrequencyNativeQueue.async { [weak self] in
      guard let self else { return }
      var session: AVCaptureSession?
      var output: AVCaptureVideoDataOutput?
      do {
        guard let selection = self.temporalFrequencyFormat(for: captureDevice, requestedMaxFps: 60.0) else {
          throw NSError(domain: "SIGILLUMIlluminationResponse", code: 1, userInfo: [NSLocalizedDescriptionKey: "No native 60 fps format available"])
        }
        let nativeSession = AVCaptureSession()
        nativeSession.beginConfiguration()
        let input = try AVCaptureDeviceInput(device: captureDevice)
        guard nativeSession.canAddInput(input) else { throw NSError(domain: "SIGILLUMIlluminationResponse", code: 2, userInfo: [NSLocalizedDescriptionKey: "Camera input unavailable"]) }
        nativeSession.addInput(input)
        let nativeOutput = AVCaptureVideoDataOutput()
        nativeOutput.alwaysDiscardsLateVideoFrames = true
        nativeOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        guard nativeSession.canAddOutput(nativeOutput) else { throw NSError(domain: "SIGILLUMIlluminationResponse", code: 3, userInfo: [NSLocalizedDescriptionKey: "Video data output unavailable"]) }
        nativeSession.addOutput(nativeOutput)

        try captureDevice.lockForConfiguration()
        captureDevice.activeFormat = selection.format
        captureDevice.activeVideoMinFrameDuration = selection.range.minFrameDuration
        captureDevice.activeVideoMaxFrameDuration = selection.range.minFrameDuration
        if captureDevice.isExposureModeSupported(.continuousAutoExposure) { captureDevice.exposureMode = .continuousAutoExposure }
        if captureDevice.isFocusModeSupported(.continuousAutoFocus) { captureDevice.focusMode = .continuousAutoFocus }
        if captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance }
        captureDevice.torchMode = .off
        captureDevice.unlockForConfiguration()
        nativeSession.commitConfiguration()
        session = nativeSession
        output = nativeOutput
        self.illuminationResponseNativeSession = nativeSession
        nativeSession.startRunning()
        guard nativeSession.isRunning else { throw NSError(domain: "SIGILLUMIlluminationResponse", code: 4, userInfo: [NSLocalizedDescriptionKey: "Illumination session failed to start"]) }
        Thread.sleep(forTimeInterval: 0.18)

        let baselineDuration = max(CMTimeGetSeconds(captureDevice.exposureDuration), CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration))
        let baselineISO = max(captureDevice.iso, captureDevice.activeFormat.minISO)
        let maxLockedDuration = min(CMTimeGetSeconds(captureDevice.activeFormat.maxExposureDuration), 0.90 / selection.fps)
        let lockedDuration = min(maxLockedDuration, baselineDuration)
        let exposureCompensation = baselineDuration / max(lockedDuration, 0.000001)
        let lockedISO = min(captureDevice.activeFormat.maxISO, max(captureDevice.activeFormat.minISO, baselineISO * Float(exposureCompensation)))
        let duration = CMTimeMakeWithSeconds(lockedDuration, preferredTimescale: 1_000_000_000)
        let exposureSemaphore = DispatchSemaphore(value: 0)
        try captureDevice.lockForConfiguration()
        if captureDevice.isFocusModeSupported(.locked) {
          captureDevice.setFocusModeLocked(lensPosition: captureDevice.lensPosition, completionHandler: nil)
        }
        if captureDevice.isWhiteBalanceModeSupported(.locked) {
          let gains = self.clampedWhiteBalanceGains(captureDevice.deviceWhiteBalanceGains, for: captureDevice)
          captureDevice.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        }
        guard captureDevice.isExposureModeSupported(.custom) else {
          captureDevice.unlockForConfiguration()
          throw NSError(domain: "SIGILLUMIlluminationResponse", code: 5, userInfo: [NSLocalizedDescriptionKey: "Custom exposure unavailable"])
        }
        captureDevice.setExposureModeCustom(duration: duration, iso: lockedISO) { _ in exposureSemaphore.signal() }
        captureDevice.unlockForConfiguration()
        _ = exposureSemaphore.wait(timeout: .now() + 0.8)
        Thread.sleep(forTimeInterval: 0.04)

        let collector = HCVIlluminationResponseNativeCollector(maxFramesPerPhase: 12)
        self.illuminationResponseNativeCollector = collector
        nativeOutput.setSampleBufferDelegate(collector, queue: self.temporalFrequencySampleQueue)

        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = .off
        captureDevice.unlockForConfiguration()
        collector.setPhase(0)
        Thread.sleep(forTimeInterval: 0.16)

        try captureDevice.lockForConfiguration()
        do {
          try captureDevice.setTorchModeOn(level: torchLevel)
          captureDevice.unlockForConfiguration()
        } catch {
          captureDevice.unlockForConfiguration()
          throw error
        }
        Thread.sleep(forTimeInterval: 0.04)
        collector.setPhase(1)
        Thread.sleep(forTimeInterval: 0.18)

        try captureDevice.lockForConfiguration()
        captureDevice.torchMode = .off
        captureDevice.unlockForConfiguration()
        Thread.sleep(forTimeInterval: 0.04)
        collector.setPhase(2)
        Thread.sleep(forTimeInterval: 0.16)

        collector.setPhase(-1)
        nativeOutput.setSampleBufferDelegate(nil, queue: nil)
        let phases = collector.snapshot()
        if nativeSession.isRunning { nativeSession.stopRunning() }
        let handoff = self.resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)
        self.illuminationResponseNativeCollector = nil
        self.illuminationResponseNativeSession = nil
        self.illuminationResponseNativeBusy = false
        let dimensions = CMVideoFormatDescriptionGetDimensions(selection.format.formatDescription)
        let payload: [String: Any] = [
          "analysisStatus": phases.allSatisfy { $0.count >= 3 } ? "CAPTURED" : "NOT_ANALYZED",
          "reason": phases.allSatisfy { $0.count >= 3 } ? "CAPTURE_COMPLETE" : "NOT_ENOUGH_PHASE_FRAMES",
          "captureMode": "ISOLATED_NATIVE_TORCH_OFF_ON_OFF_LOCKED_EXPOSURE",
          "physicalCaptureDeviceUniqueId": captureDevice.uniqueID,
          "configuredFrameRate": selection.fps,
          "frameWidth": Int(dimensions.width),
          "frameHeight": Int(dimensions.height),
          "torchLevel": Double(torchLevel),
          "lockedExposureSeconds": CMTimeGetSeconds(captureDevice.exposureDuration),
          "lockedISO": Double(captureDevice.iso),
          "phaseFrames": phases,
          "phaseFrameCounts": phases.map { $0.count },
          "cameraHandoffAfterIlluminationProbe": handoff,
        ]
        DispatchQueue.main.async { result(payload) }
      } catch {
        do {
          try captureDevice.lockForConfiguration()
          captureDevice.torchMode = .off
          captureDevice.unlockForConfiguration()
        } catch {}
        output?.setSampleBufferDelegate(nil, queue: nil)
        if let session, session.isRunning { session.stopRunning() }
        _ = self.resetTemporalFrequencyOpticsForFlutterHandoff(captureDevice)
        self.illuminationResponseNativeCollector = nil
        self.illuminationResponseNativeSession = nil
        self.illuminationResponseNativeBusy = false
        DispatchQueue.main.async {
          result(FlutterError(code: "ILLUMINATION_RESPONSE_CAPTURE_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func handleCameraProbeCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let device = cameraProbeDevice(from: call, result: result) else {
      return
    }

    switch call.method {
    case "captureIlluminationResponseNative":
      let physicalDevice = temporalFrequencyPhysicalDevice(for: device)
      captureIlluminationResponseNative(device: physicalDevice, call: call, result: result)

    case "captureTemporalFrequencyNative":
      let physicalDevice = temporalFrequencyPhysicalDevice(for: device)
      captureTemporalFrequencyNative(
        device: physicalDevice,
        call: call,
        result: result
      )

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

  @available(iOS 15.0, *)
  private func trustedStorefrontCurrency(
    _ storefront: StoreKit.Storefront?
  ) -> (
    countryCode: String,
    storefrontCurrencyCode: String,
    regionCurrencyCode: String,
    trustedCurrencyCode: String
  ) {
    let countryCode = storefront?.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""

    var storefrontCurrencyCode = ""
    if #available(iOS 17.0, *) {
      storefrontCurrencyCode = storefront?.currency?.identifier
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased() ?? ""
    }

    // Storefront.countryCode is ISO-3166 alpha-3. Foundation canonicalizes
    // identifiers such as en_ITA to region IT and exposes the region currency.
    // This is a safety cross-check only: if Apple's Storefront currency and the
    // region-derived currency disagree, SIGILLUM must not display a numeric
    // amount. The Apple purchase sheet remains the final price source of truth.
    var regionCurrencyCode = ""
    if !countryCode.isEmpty {
      let regionLocale = Locale(identifier: "en_\(countryCode)")
      if #available(iOS 16.0, *) {
        regionCurrencyCode = regionLocale.currency?.identifier
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .uppercased() ?? ""
      } else {
        regionCurrencyCode = regionLocale.currencyCode?
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .uppercased() ?? ""
      }
    }

    var trustedCurrencyCode = ""
    if !storefrontCurrencyCode.isEmpty && !regionCurrencyCode.isEmpty {
      if storefrontCurrencyCode.caseInsensitiveCompare(regionCurrencyCode) == .orderedSame {
        trustedCurrencyCode = storefrontCurrencyCode
      }
    } else if !storefrontCurrencyCode.isEmpty {
      trustedCurrencyCode = storefrontCurrencyCode
    } else if !regionCurrencyCode.isEmpty {
      trustedCurrencyCode = regionCurrencyCode
    }

    return (
      countryCode,
      storefrontCurrencyCode,
      regionCurrencyCode,
      trustedCurrencyCode
    )
  }

  @available(iOS 15.0, *)
  private func storefrontFingerprint(
    _ snapshot: (
      countryCode: String,
      storefrontCurrencyCode: String,
      regionCurrencyCode: String,
      trustedCurrencyCode: String
    )
  ) -> String {
    return [
      snapshot.countryCode,
      snapshot.storefrontCurrencyCode,
      snapshot.regionCurrencyCode,
      snapshot.trustedCurrencyCode,
    ].joined(separator: "|")
  }

  @available(iOS 15.0, *)
  private func startStorefrontUpdateMonitoring(channel: FlutterMethodChannel) {
    storefrontUpdatesTask?.cancel()

    // TestFlight/Sandbox can expose a cached Storefront.current snapshot before
    // the purchase sheet refreshes the account storefront. Treat the first
    // snapshot only as a baseline, never as freshness proof. A numeric paywall
    // price becomes eligible only after Storefront.updates reports a genuinely
    // different storefront/currency fingerprint during this app session.
    storefrontUpdatesTask = Task { @MainActor [weak self] in
      guard let self = self else { return }

      let initialStorefront = await StoreKit.Storefront.current
      let initialSnapshot = self.trustedStorefrontCurrency(initialStorefront)
      self.storefrontBaselineFingerprint = self.storefrontFingerprint(initialSnapshot)
      self.storefrontSessionFresh = false

      for await storefront in StoreKit.Storefront.updates {
        if Task.isCancelled { return }

        let snapshot = self.trustedStorefrontCurrency(storefront)
        let fingerprint = self.storefrontFingerprint(snapshot)

        // Some StoreKit sequences may first echo the already-cached current
        // storefront. An identical first event is still not freshness evidence.
        guard !fingerprint.isEmpty,
              fingerprint != self.storefrontBaselineFingerprint else {
          continue
        }

        self.storefrontBaselineFingerprint = fingerprint
        self.storefrontSessionFresh = true
        channel.invokeMethod(
          "storefrontChanged",
          arguments: [
            "countryCode": snapshot.countryCode,
            "currencyCode": snapshot.trustedCurrencyCode,
          ]
        )
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

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
      name: "hcv.storekit2",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 15.0, *) else {
        result(FlutterError(
          code: "STOREKIT2_UNAVAILABLE",
          message: "StoreKit 2 is unavailable on this iOS version",
          details: nil
        ))
        return
      }

      switch call.method {
      case "localizedProductPrices":
        guard
          let args = call.arguments as? [String: Any],
          let productIds = args["productIds"] as? [String],
          !productIds.isEmpty
        else {
          result(FlutterError(
            code: "INVALID_PRODUCT_IDS",
            message: "No App Store product identifiers were supplied",
            details: nil
          ))
          return
        }

        Task {
          // Do not publish a numeric amount from the launch-time Storefront
          // snapshot. The user's TestFlight evidence showed that this snapshot
          // can remain USD while Apple's actual purchase sheet is already EUR.
          // Until Storefront.updates proves a session refresh, show only the
          // neutral App Store label and let Apple's sheet disclose the amount.
          let sessionFresh = await MainActor.run { self.storefrontSessionFresh }
          guard sessionFresh else {
            let neutral = Dictionary(
              uniqueKeysWithValues: productIds.map { ($0, "App Store") }
            )
            await MainActor.run {
              result(neutral)
            }
            return
          }

          do {
            let storefront = await StoreKit.Storefront.current
            let currencySnapshot = self.trustedStorefrontCurrency(storefront)

            let products = try await StoreKit.Product.products(for: productIds)
            var prices: [String: String] = [:]
            for product in products {
              let trustedCurrencyCode = currencySnapshot.trustedCurrencyCode
              guard !trustedCurrencyCode.isEmpty else {
                prices[product.id] = "App Store"
                continue
              }

              let productCurrencyCode = product.priceFormatStyle.currencyCode
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
              guard productCurrencyCode.caseInsensitiveCompare(trustedCurrencyCode) == .orderedSame else {
                prices[product.id] = "App Store"
                continue
              }

              prices[product.id] = product.displayPrice
            }
            await MainActor.run {
              result(prices)
            }
          } catch {
            await MainActor.run {
              result(FlutterError(
                code: "STOREKIT2_PRICE_LOOKUP_FAILED",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }

      case "currentStorefrontCurrency":
        Task {
          let storefront = await StoreKit.Storefront.current
          let currencySnapshot = self.trustedStorefrontCurrency(storefront)
          let sessionFresh = await MainActor.run { self.storefrontSessionFresh }
          let snapshot: [String: Any] = [
            "countryCode": currencySnapshot.countryCode,
            // Dart is intentionally given only the trusted value and only after
            // a session storefront refresh. Before then it must not reintroduce
            // stale ProductDetails USD as a fallback numeric price.
            "currencyCode": sessionFresh ? currencySnapshot.trustedCurrencyCode : "",
            "storefrontCurrencyCode": currencySnapshot.storefrontCurrencyCode,
            "regionCurrencyCode": currencySnapshot.regionCurrencyCode,
            "sessionFresh": sessionFresh,
          ]
          await MainActor.run {
            result(snapshot)
          }
        }

      case "currentEntitlements":
        Task {
          var entitlements: [[String: String]] = []
          for await verification in StoreKit.Transaction.currentEntitlements {
            switch verification {
            case .verified(let transaction):
              entitlements.append([
                "productId": transaction.productID,
                "transactionId": String(transaction.id),
                "receiptData": verification.jwsRepresentation,
              ])
            case .unverified:
              // An unverified StoreKit transaction must never be used as
              // entitlement evidence. The Dart/server path remains fail-closed.
              continue
            }
          }
          await MainActor.run {
            result(entitlements)
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
    storeKit2PriceChannel = channel

    if #available(iOS 15.0, *) {
      startStorefrontUpdateMonitoring(channel: channel)
    }
  }
}
