import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import 'commercial_account_service.dart';

class CommercialUnfinishedAppleTransaction {
  const CommercialUnfinishedAppleTransaction({
    required this.transactionId,
    required this.productId,
    required this.receiptData,
  });

  final String transactionId;
  final String productId;
  final String receiptData;
}

class CommercialBillingService {
  static const _nativeStoreKit2 = MethodChannel('hcv.storekit2');

  CommercialBillingService._() {
    _nativeStoreKit2.setMethodCallHandler(_handleNativeStoreKit2Call);
  }

  static final instance = CommercialBillingService._();

  static const weeklyProductId = 'com.sigillum.hcv.creator.weekly';
  static const monthlyProductId = 'com.sigillum.hcv.creator.monthly';
  static const annualProductId = 'com.sigillum.hcv.creator.annual';
  static const productIds = {
    weeklyProductId,
    monthlyProductId,
    annualProductId,
  };

  static const _storefrontPriceRetryDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 250),
    Duration(milliseconds: 650),
    Duration(milliseconds: 1200),
  ];

  static int productRank(String productId) {
    if (productId == weeklyProductId) return 0;
    if (productId == monthlyProductId) return 1;
    if (productId == annualProductId) return 2;
    return 99;
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<List<PurchaseDetails>> _purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();
  final StreamController<void> _storefrontController =
      StreamController<void>.broadcast();
  final Set<String> _purchaseInFlight = <String>{};
  final Map<String, Completer<void>> _purchaseTerminalWaiters =
      <String, Completer<void>>{};

  Stream<List<PurchaseDetails>> get purchases => _purchaseController.stream;
  Stream<void> get storefrontChanges => _storefrontController.stream;

  Future<dynamic> _handleNativeStoreKit2Call(MethodCall call) async {
    if (call.method == 'storefrontChanged') {
      _storefrontController.add(null);
      return true;
    }
    return null;
  }

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<List<ProductDetails>> loadProducts() async {
    if (!await _iap.isAvailable()) return const [];
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      throw StateError(response.error!.message);
    }
    final products = [...response.productDetails]
      ..sort((a, b) => productRank(a.id).compareTo(productRank(b.id)));
    return products;
  }

  Future<String> _currentStorefrontCurrency() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return '';
    try {
      final raw = await _nativeStoreKit2.invokeMethod<Map<Object?, Object?>>(
        'currentStorefrontCurrency',
      );
      if (raw?['sessionFresh'] != true) return '';
      return raw?['currencyCode']?.toString().trim().toUpperCase() ?? '';
    } catch (_) {
      return '';
    }
  }

  static bool _isNeutralApplePrice(String value) =>
      value.trim().toLowerCase() == 'app store';

  Future<Map<String, String>> localizedDisplayPrices(
    Iterable<ProductDetails> products,
  ) async {
    final productList = products.toList(growable: false);
    if (productList.isEmpty) return const {};

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return <String, String>{
        for (final product in productList) product.id: product.price,
      };
    }

    // A launch-time TestFlight/Sandbox storefront snapshot is not freshness
    // proof. Native StoreKit 2 exposes a trusted currency to Dart only after a
    // genuine Storefront.updates transition has happened in this app session.
    // Until then, the native price call returns the neutral "App Store" label.
    // ProductDetails is accepted as a secondary Apple-backed source only when
    // that session-fresh trusted currency exists.
    final storefrontCurrency = await _currentStorefrontCurrency();
    final requestedIds = productList.map((product) => product.id).toList();
    Map<String, String>? previousComplete;
    Map<String, String> lastResolved = const {};

    for (final delay in _storefrontPriceRetryDelays) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);

      final resolved = <String, String>{};
      try {
        final raw = await _nativeStoreKit2.invokeMethod<Map<Object?, Object?>>(
          'localizedProductPrices',
          {'productIds': requestedIds},
        );
        if (raw != null) {
          for (final entry in raw.entries) {
            final id = entry.key?.toString() ?? '';
            final price = entry.value?.toString().trim() ?? '';
            if (requestedIds.contains(id) && price.isNotEmpty) {
              resolved[id] = price;
            }
          }
        }
      } catch (_) {}

      if (storefrontCurrency.isNotEmpty) {
        for (final product in productList) {
          if (resolved.containsKey(product.id)) continue;
          final productCurrency = product.currencyCode.trim().toUpperCase();
          if (productCurrency == storefrontCurrency && product.price.isNotEmpty) {
            resolved[product.id] = product.price;
          }
        }
      }

      lastResolved = Map<String, String>.from(resolved);
      final complete = resolved.length == requestedIds.length;
      if (!complete) {
        previousComplete = null;
        continue;
      }

      final neutralOnly = resolved.values.every(_isNeutralApplePrice);
      if (neutralOnly && storefrontCurrency.isEmpty) {
        // Do not settle immediately on the launch-time neutral result. Use the
        // complete retry window to give Storefront.updates a chance to refresh
        // Sandbox/TestFlight metadata before the paywall becomes visible.
        previousComplete = null;
        continue;
      }

      if (previousComplete != null && mapEquals(previousComplete, resolved)) {
        return resolved;
      }

      previousComplete = Map<String, String>.from(resolved);
    }

    // Never fall back to an unrefreshed numeric Product. If StoreKit did not
    // prove storefront freshness during the retry window, keep the purchase
    // available with a truthful neutral label; Apple's sheet remains the final
    // localized price authority before consent.
    if (lastResolved.isNotEmpty) return lastResolved;
    return <String, String>{for (final id in requestedIds) id: 'App Store'};
  }

  void startListening() {
    _subscription ??= _iap.purchaseStream.listen(
      (purchases) {
        _releaseTerminalPurchaseAttempts(purchases);
        _purchaseController.add(purchases);
      },
      onError: (Object error, StackTrace stackTrace) {
        _failPurchaseAttempts(error, stackTrace);
        _purchaseController.addError(error, stackTrace);
      },
    );
  }

  void _releaseTerminalPurchaseAttempts(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (!productIds.contains(purchase.productID)) continue;
      final terminal = purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored ||
          purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled;
      if (!terminal) continue;
      _releasePurchaseAttempt(purchase.productID);
    }
  }

  void _releasePurchaseAttempt(String productId) {
    _purchaseInFlight.remove(productId);
    final waiter = _purchaseTerminalWaiters.remove(productId);
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  void _failPurchaseAttempts(Object error, StackTrace stackTrace) {
    final waiters = Map<String, Completer<void>>.from(_purchaseTerminalWaiters);
    _purchaseTerminalWaiters.clear();
    _purchaseInFlight.clear();
    for (final waiter in waiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(error, stackTrace);
      }
    }
  }

  Future<void> _preflightCurrentAppleEntitlementOwnership() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      // billingStatus() reconciles StoreKit 2 currentEntitlements with the
      // server-side durable originalTransactionId owner. If the Apple ID already
      // has a current SIGILLUM subscription owned by another SIGILLUM account,
      // opening another Apple sheet would only attempt a plan change on that
      // foreign subscription and would necessarily fail server verification.
      // Block before payment instead. A stale unfinished transaction that is no
      // longer a current entitlement is still handled separately below and may
      // be finished safely before a genuinely new purchase.
      await const CommercialAccountService().billingStatus();
    } on CommercialAccountException catch (error) {
      if (error.code == 'APPLE_SUBSCRIPTION_ALREADY_LINKED') rethrow;
      // Preserve the existing purchase behavior for unrelated/transient status
      // lookup failures; the actual purchase remains fail-closed because its
      // resulting transaction must still pass server verification.
    }
  }

  Future<bool> purchase(ProductDetails product) async {
    if (!productIds.contains(product.id)) {
      throw StateError('Prodotto SIGILLUM non riconosciuto.');
    }

    await _preflightCurrentAppleEntitlementOwnership();

    // StoreKit rejects a second purchase object for a product whose previous
    // transaction is still unfinished. Resolve only the same product before
    // creating a new payment. The transaction is never finished until the
    // SIGILLUM backend has authenticated it.
    final recoveredActive = await _recoverSameProductBeforePurchase(product.id);
    if (recoveredActive) {
      // Re-deliver the active entitlement through the normal purchase stream so
      // CommercialGate performs its existing server verification/routing path.
      await _iap.restorePurchases();
      return true;
    }

    if (_purchaseInFlight.contains(product.id)) {
      throw StateError('Acquisto App Store già in corso per questo prodotto.');
    }

    // buyNonConsumable completes when the payment request has been submitted,
    // not when StoreKit has finished the sheet lifecycle. Keep the same product
    // locked until purchaseStream reports a terminal status, including user
    // cancellation. This prevents an immediate second tap from creating the
    // duplicate product object observed in TestFlight after Cancel.
    startListening();
    final terminal = Completer<void>();
    _purchaseInFlight.add(product.id);
    _purchaseTerminalWaiters[product.id] = terminal;

    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _releasePurchaseAttempt(product.id);
        return false;
      }
      await terminal.future;
      return true;
    } catch (error, stackTrace) {
      _releasePurchaseAttempt(product.id);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<bool> _recoverSameProductBeforePurchase(String productId) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;

    final unfinished = await unfinishedAppleTransactions();
    final sameProduct = unfinished
        .where((transaction) => transaction.productId == productId)
        .toList(growable: false);
    if (sameProduct.isEmpty) return false;

    const account = CommercialAccountService();
    var entitlementActive = false;
    for (final transaction in sameProduct) {
      Map<String, dynamic> verified;
      try {
        verified = await account.verifyApplePurchase(
          productId: transaction.productId,
          transactionId: transaction.transactionId,
          receiptData: transaction.receiptData,
        );
      } on CommercialAccountException catch (error) {
        if (error.code != 'APPLE_SUBSCRIPTION_ALREADY_LINKED') rethrow;

        // This branch is reached only when the preflight above did not find a
        // current foreign entitlement. The backend has authenticated this stale
        // unfinished transaction and resolved a different durable owner, so it
        // is safe to finish only the queue delivery. No entitlement is granted
        // or transferred, and a genuinely new payment may then proceed.
        await finishUnfinishedAppleTransaction(transaction.transactionId);
        continue;
      }

      if (verified['verified'] != true) {
        throw const CommercialAccountException(
          'Verifica abbonamento App Store non riuscita.',
        );
      }

      await finishUnfinishedAppleTransaction(transaction.transactionId);

      final status = verified['status']?.toString() ?? 'inactive';
      if (status == 'active' || status == 'grace') {
        entitlementActive = true;
      }
    }

    return entitlementActive;
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<List<CommercialUnfinishedAppleTransaction>>
  unfinishedAppleTransactions() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return const [];

    final transactions = await SK2Transaction.unfinishedTransactions();
    return transactions
        .where((transaction) => productIds.contains(transaction.productId))
        .where((transaction) => (transaction.receiptData ?? '').isNotEmpty)
        .map(
          (transaction) => CommercialUnfinishedAppleTransaction(
            transactionId: transaction.id,
            productId: transaction.productId,
            receiptData: transaction.receiptData!,
          ),
        )
        .toList(growable: false);
  }

  Future<void> finishUnfinishedAppleTransaction(String transactionId) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final numericId = int.tryParse(transactionId);
    if (numericId == null) {
      throw StateError('Identificativo transazione Apple non valido.');
    }
    await SK2Transaction.finish(numericId);
  }

  Future<void> completeVerifiedPurchase(PurchaseDetails purchase) async {
    if (!productIds.contains(purchase.productID)) {
      throw StateError('Prodotto SIGILLUM non riconosciuto.');
    }
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      throw StateError('Acquisto SIGILLUM non completato.');
    }
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _purchaseInFlight.clear();
    final waiters = _purchaseTerminalWaiters.values.toList(growable: false);
    _purchaseTerminalWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.completeError(StateError('Billing service disposed.'));
      }
    }
  }
}
