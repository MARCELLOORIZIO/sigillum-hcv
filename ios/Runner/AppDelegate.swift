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
          do {
            // StoreKit can briefly retain stale Sandbox Product metadata after a
            // storefront/account change. Never expose a Product.displayPrice
            // whose currency conflicts with the current Storefront currency.
            let storefront = await StoreKit.Storefront.current
            var storefrontCurrencyCode: String?
            if #available(iOS 17.0, *) {
              storefrontCurrencyCode = storefront?.currency?.identifier
            }

            let products = try await StoreKit.Product.products(for: productIds)
            var prices: [String: String] = [:]
            for product in products {
              let productCurrencyCode = product.priceFormatStyle.currencyCode
              if let storefrontCurrencyCode,
                 !storefrontCurrencyCode.isEmpty,
                 productCurrencyCode.caseInsensitiveCompare(storefrontCurrencyCode) != .orderedSame {
                // The Apple purchase sheet remains the source of truth. Keep the
                // plan purchasable, but do not display a known-wrong amount.
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
          var currencyCode = ""
          if #available(iOS 17.0, *) {
            currencyCode = storefront?.currency?.identifier ?? ""
          }
          let snapshot: [String: String] = [
            "countryCode": storefront?.countryCode ?? "",
            "currencyCode": currencyCode,
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
  }
}
