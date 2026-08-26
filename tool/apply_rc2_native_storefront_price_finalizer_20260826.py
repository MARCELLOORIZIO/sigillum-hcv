from pathlib import Path
import re

BILLING = Path('lib/commercial_billing_service.dart')
SCENE = Path('ios/Runner/SceneDelegate.swift')

billing = BILLING.read_text(encoding='utf-8')
scene = SCENE.read_text(encoding='utf-8')

# ---------------------------------------------------------------------------
# iOS native StoreKit price source. The installed TestFlight build proved that
# the Flutter-side cached ProductDetails/SK2 wrapper could show USD while the
# Apple purchase sheet used EUR. Query StoreKit natively at presentation time
# and use the product's current priceLocale; keep existing Dart prices only as
# a fallback if the native request is unavailable.
# ---------------------------------------------------------------------------
if 'import StoreKit\n' not in scene:
    import_anchor = 'import Security\n'
    if scene.count(import_anchor) != 1:
        raise RuntimeError('SceneDelegate StoreKit import anchor missing')
    scene = scene.replace(import_anchor, import_anchor + 'import StoreKit\n', 1)

helper = r'''
private final class HCVStorePriceLookup: NSObject, SKProductsRequestDelegate, SKRequestDelegate {
  private var request: SKProductsRequest?
  private let completion: ([String: String]?, Error?) -> Void

  init(productIds: [String], completion: @escaping ([String: String]?, Error?) -> Void) {
    self.completion = completion
    super.init()
    let lookup = SKProductsRequest(productIdentifiers: Set(productIds))
    request = lookup
    lookup.delegate = self
  }

  func start() {
    request?.start()
  }

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    var prices: [String: String] = [:]
    for product in response.products {
      formatter.locale = product.priceLocale
      if let rendered = formatter.string(from: product.price) {
        prices[product.productIdentifier] = rendered
      }
    }
    completion(prices, nil)
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    completion(nil, error)
  }
}

'''
if 'private final class HCVStorePriceLookup' not in scene:
    class_anchor = 'class SceneDelegate: FlutterSceneDelegate {'
    if scene.count(class_anchor) != 1:
        raise RuntimeError('SceneDelegate class anchor missing')
    scene = scene.replace(class_anchor, helper + class_anchor, 1)

if 'private var storePriceLookups: [HCVStorePriceLookup] = []' not in scene:
    state_anchor = '  private var mediaChannel: FlutterMethodChannel?\n'
    if scene.count(state_anchor) != 1:
        raise RuntimeError('SceneDelegate media-channel state anchor missing')
    scene = scene.replace(
        state_anchor,
        state_anchor + '  private var storePriceLookups: [HCVStorePriceLookup] = []\n',
        1,
    )

handler_anchor = '''      } else if call.method == "extractVideoFrame" {
'''
price_handler = '''      } else if call.method == "localizedProductPrices" {
        guard
          let args = call.arguments as? [String: Any],
          let ids = args["productIds"] as? [String],
          !ids.isEmpty
        else {
          result(FlutterError(
            code: "INVALID_PRODUCT_IDS",
            message: "No App Store product identifiers were supplied",
            details: nil
          ))
          return
        }

        self.localizedProductPrices(productIds: ids, result: result)
      } else if call.method == "extractVideoFrame" {
'''
if 'call.method == "localizedProductPrices"' not in scene:
    if scene.count(handler_anchor) != 1:
        raise RuntimeError('SceneDelegate localized price handler anchor missing')
    scene = scene.replace(handler_anchor, price_handler, 1)

price_method = r'''
  private func localizedProductPrices(
    productIds: [String],
    result: @escaping FlutterResult
  ) {
    var lookup: HCVStorePriceLookup?
    lookup = HCVStorePriceLookup(productIds: productIds) { [weak self] prices, error in
      DispatchQueue.main.async {
        if let lookup = lookup {
          self?.storePriceLookups.removeAll { $0 === lookup }
        }
        if let error = error {
          result(FlutterError(
            code: "STORE_PRICE_LOOKUP_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        } else {
          result(prices ?? [:])
        }
      }
    }
    guard let retainedLookup = lookup else {
      result(FlutterError(
        code: "STORE_PRICE_LOOKUP_FAILED",
        message: "Unable to initialize App Store price lookup",
        details: nil
      ))
      return
    }
    storePriceLookups.append(retainedLookup)
    retainedLookup.start()
  }

'''
if 'private func localizedProductPrices(' not in scene:
    method_anchor = '  private func saveToPhotos(path: String, result: @escaping FlutterResult) {'
    if scene.count(method_anchor) != 1:
        raise RuntimeError('SceneDelegate price method insertion anchor missing')
    scene = scene.replace(method_anchor, price_method + method_anchor, 1)

SCENE.write_text(scene, encoding='utf-8')

# Dart bridge to the native StoreKit request. Keep the previous StoreKit2/plugin
# implementation as fallback only, preserving non-iOS behavior.
if "import 'package:flutter/services.dart';" not in billing:
    foundation = "import 'package:flutter/foundation.dart';\n"
    if foundation not in billing:
        raise RuntimeError('billing foundation import must be materialized first')
    billing = billing.replace(
        foundation,
        foundation + "import 'package:flutter/services.dart';\n",
        1,
    )

if "static const _nativeStoreKit = MethodChannel('hcv.media');" not in billing:
    class_anchor = 'class CommercialBillingService {\n'
    if billing.count(class_anchor) != 1:
        raise RuntimeError('CommercialBillingService class anchor missing')
    billing = billing.replace(
        class_anchor,
        class_anchor + "  static const _nativeStoreKit = MethodChannel('hcv.media');\n\n",
        1,
    )

method_pattern = re.compile(
    r"  Future<Map<String, String>> localizedDisplayPrices\(.*?^  \}\n\n",
    re.MULTILINE | re.DOTALL,
)
method_match = method_pattern.search(billing)
if not method_match:
    raise RuntimeError('localizedDisplayPrices materialized method missing')

native_method = r'''  Future<Map<String, String>> localizedDisplayPrices(
    Iterable<ProductDetails> products,
  ) async {
    final fallback = <String, String>{
      for (final product in products) product.id: product.price,
    };
    if (defaultTargetPlatform != TargetPlatform.iOS || fallback.isEmpty) {
      return fallback;
    }

    try {
      final raw = await _nativeStoreKit.invokeMethod<Map<Object?, Object?>>(
        'localizedProductPrices',
        {'productIds': fallback.keys.toList()},
      );
      if (raw != null) {
        for (final entry in raw.entries) {
          final id = entry.key?.toString() ?? '';
          final price = entry.value?.toString().trim() ?? '';
          if (id.isNotEmpty && price.isNotEmpty && fallback.containsKey(id)) {
            fallback[id] = price;
          }
        }
      }
      return fallback;
    } catch (_) {
      // Fall through to the existing StoreKit 2 wrapper. Native StoreKit is the
      // preferred source because it matched the purchase sheet storefront in
      // TestFlight, while no price-rendering failure may block purchasing.
    }

    try {
      final storeKitProducts = await SK2Product.products(fallback.keys.toList());
      for (final product in storeKitProducts) {
        final displayPrice = product.displayPrice.trim();
        if (displayPrice.isNotEmpty) {
          fallback[product.id] = displayPrice;
        }
      }
    } catch (_) {}
    return fallback;
  }

'''
current_method = method_match.group(0)
if "'localizedProductPrices'" not in current_method:
    billing = billing[:method_match.start()] + native_method + billing[method_match.end():]
    print('native StoreKit storefront price bridge applied')
else:
    print('native StoreKit storefront price bridge already applied')

BILLING.write_text(billing, encoding='utf-8')

for path, tokens in {
    SCENE: [
        'import StoreKit',
        'private final class HCVStorePriceLookup',
        'product.priceLocale',
        'call.method == "localizedProductPrices"',
        'private func localizedProductPrices(',
    ],
    BILLING: [
        "static const _nativeStoreKit = MethodChannel('hcv.media');",
        "'localizedProductPrices'",
        "'productIds': fallback.keys.toList()",
        'SK2Product.products(',
    ],
}.items():
    final = path.read_text(encoding='utf-8')
    for token in tokens:
        if token not in final:
            raise RuntimeError(f'native storefront price contract missing in {path}: {token}')

print('RC2 native storefront price finalizer PASS')
