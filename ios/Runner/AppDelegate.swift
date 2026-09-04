import AVFoundation
import Flutter
import Foundation
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var storeKit2PriceChannel: FlutterMethodChannel?
  private var cameraProbeChannel: FlutterMethodChannel?
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
