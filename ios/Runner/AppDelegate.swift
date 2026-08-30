import Flutter
import Foundation
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var storeKit2PriceChannel: FlutterMethodChannel?
  private var storefrontUpdatesTask: Task<Void, Never>?
  private var storefrontBaselineFingerprint = ""
  private var storefrontSessionFresh = false

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
