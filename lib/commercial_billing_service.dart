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

  CommercialBillingService._();

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
  final Set<String> _purchaseInFlight = <String>{};
  final Map<String, Completer<void>> _purchaseTerminalWaiters =
      <String, Completer<void>>{};

  Stream<List<PurchaseDetails>> get purchases => _purchaseController.stream;

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
      return raw?['currencyCode']?.toString().trim().toUpperCase() ?? '';
    } catch (_) {
      return '';
    }
  }

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

    // Read Storefront immediately before displaying product information. On
    // modern iOS, native StoreKit omits any Product whose currency conflicts
    // with the current storefront. ProductDetails is accepted as a secondary
    // Apple-backed source only when its currency matches that same storefront.
    // If neither source is consistent, the paywall deliberately shows no
    // numeric price rather than exposing a stale Sandbox amount/currency.
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

      if (previousComplete != null && mapEquals(previousComplete, resolved)) {
        return resolved;
      }

      previousComplete = Map<String, String>.from(resolved);
    }

    // Never fall back to a currency-inconsistent Product. A missing numeric
    // price is safer and truthful: the Apple purchase sheet still presents the
    // exact localized amount before confirmation.
    return lastResolved;
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

  Future<bool> purchase(ProductDetails product) async {
    if (!productIds.contains(product.id)) {
      throw StateError('Prodotto SIGILLUM non riconosciuto.');
    }

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
      final verified = await account.verifyApplePurchase(
        productId: transaction.productId,
        transactionId: transaction.transactionId,
        receiptData: transaction.receiptData,
      );
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
