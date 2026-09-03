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
    case .locked:
      return "LOCKED"
    case .autoExpose:
      return "AUTO_EXPOSE"
    case .continuousAutoExposure:
      return "CONTINUOUS_AUTO"
    case .custom:
      return "CUSTOM"
    @unknown default:
      return "UNKNOWN"
    }
  }

  private func cameraProbeState(_ device: AVCaptureDevice) -> [String: Any] {
    let duration = CMTimeGetSeconds(device.exposureDuration)
    let minDuration = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
    let maxDuration = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
    return [
      "deviceUniqueId": device.uniqueID,
      "zoomFactor": Double(device.videoZoomFactor),
      "exposureMode": exposureModeName(device.exposureMode),
      "exposureDurationSeconds": duration.isFinite ? duration : 0.0,
      "iso": Double(device.iso),
      "minISO": Double(device.activeFormat.minISO),
      "maxISO": Double(device.activeFormat.maxISO),
      "minExposureDurationSeconds": minDuration.isFinite ? minDuration : 0.0,
      "maxExposureDurationSeconds": maxDuration.isFinite ? maxDuration : 0.0,
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

    case "setContinuousAutoExposure":
      do {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        guard device.isExposureModeSupported(.continuousAutoExposure) else {
          result(FlutterError(
            code: "CONTINUOUS_AUTO_EXPOSURE_UNSUPPORTED",
            message: "Continuous auto exposure is unavailable on this camera",
            details: nil
          ))
          return
        }
        device.exposureMode = .continuousAutoExposure
        result(cameraProbeState(device))
      } catch {
        result(FlutterError(
          code: "CAMERA_CONFIGURATION_LOCK_FAILED",
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
        device.setExposureModeCustom(
          duration: targetDuration,
          iso: compensatedISO
        ) { [weak self, weak device] _ in
          guard let self = self, let device = device else {
            result(FlutterError(
              code: "CAMERA_PROBE_DEVICE_RELEASED",
              message: "Camera device was released during exposure change",
              details: nil
            ))
            return
          }
          DispatchQueue.main.async {
            var state = self.cameraProbeState(device)
            state["requestedExposureDurationSeconds"] = requestedDuration
            state["baselineExposureDurationSeconds"] = currentDuration
            state["baselineISO"] = Double(currentISO)
            state["isoCompensationClamped"] =
              compensatedISO >= device.activeFormat.maxISO - 0.5
            result(state)
          }
        }
        device.unlockForConfiguration()
      } catch {
        result(FlutterError(
          code: "CAMERA_CONFIGURATION_LOCK_FAILED",
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

      let originalMode = state["exposureMode"] as? String ?? "CONTINUOUS_AUTO"
      if originalMode == "CONTINUOUS_AUTO" || originalMode == "AUTO_EXPOSE" {
        do {
          try device.lockForConfiguration()
          defer { device.unlockForConfiguration() }
          let desiredMode: AVCaptureDevice.ExposureMode =
            originalMode == "AUTO_EXPOSE" ? .autoExpose : .continuousAutoExposure
          if device.isExposureModeSupported(desiredMode) {
            device.exposureMode = desiredMode
          } else if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
          }
          result(cameraProbeState(device))
        } catch {
          result(FlutterError(
            code: "CAMERA_CONFIGURATION_LOCK_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
        return
      }

      let durationSeconds =
        state["exposureDurationSeconds"] as? Double ?? CMTimeGetSeconds(device.exposureDuration)
      let requestedISO = Float(state["iso"] as? Double ?? Double(device.iso))
      let duration = CMTimeMakeWithSeconds(
        durationSeconds,
        preferredTimescale: 1_000_000_000
      )
      let restoredISO = min(
        device.activeFormat.maxISO,
        max(device.activeFormat.minISO, requestedISO)
      )

      do {
        try device.lockForConfiguration()
        guard device.isExposureModeSupported(.custom) else {
          device.unlockForConfiguration()
          result(FlutterError(
            code: "CUSTOM_EXPOSURE_UNSUPPORTED",
            message: "Original custom exposure could not be restored",
            details: nil
          ))
          return
        }
        device.setExposureModeCustom(duration: duration, iso: restoredISO) {
          [weak self, weak device] _ in
          guard let self = self, let device = device else {
            result(FlutterError(
              code: "CAMERA_PROBE_DEVICE_RELEASED",
              message: "Camera device was released during state restore",
              details: nil
            ))
            return
          }
          DispatchQueue.main.async {
            result(self.cameraProbeState(device))
          }
        }
        device.unlockForConfiguration()
      } catch {
        result(FlutterError(
          code: "CAMERA_CONFIGURATION_LOCK_FAILED",
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
