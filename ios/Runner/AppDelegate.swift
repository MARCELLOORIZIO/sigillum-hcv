import Flutter
import Foundation
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
            // A TestFlight/Sandbox StoreKit Product can retain stale pricing
            // metadata even after Storefront.current has moved to another
            // country. A numeric amount is therefore shown only when the
            // Storefront currency, its country-derived currency, and the Product
            // currency form a consistent snapshot. Any ambiguity fails closed
            // to the neutral "App Store" label; purchase itself remains enabled
            // and Apple's sheet shows the exact localized amount before consent.
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
          let snapshot: [String: String] = [
            "countryCode": currencySnapshot.countryCode,
            // Dart is intentionally given only the trusted value. If the raw
            // Storefront currency conflicts with the storefront region, an empty
            // value prevents ProductDetails.price from reintroducing stale USD.
            "currencyCode": currencySnapshot.trustedCurrencyCode,
            "storefrontCurrencyCode": currencySnapshot.storefrontCurrencyCode,
            "regionCurrencyCode": currencySnapshot.regionCurrencyCode,
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
