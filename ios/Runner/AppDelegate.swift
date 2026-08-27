import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var storeKit2PriceChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "hcv.storekit2",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "localizedProductPrices" else {
        result(FlutterMethodNotImplemented)
        return
      }
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

      guard #available(iOS 15.0, *) else {
        result(FlutterError(
          code: "STOREKIT2_UNAVAILABLE",
          message: "StoreKit 2 is unavailable on this iOS version",
          details: nil
        ))
        return
      }

      Task {
        do {
          let products = try await StoreKit.Product.products(for: productIds)
          var prices: [String: String] = [:]
          for product in products {
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
    }
    storeKit2PriceChannel = channel
  }
}
