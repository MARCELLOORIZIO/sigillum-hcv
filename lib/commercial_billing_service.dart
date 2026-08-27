import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
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

    // ProductDetails can retain a stale sandbox currency in TestFlight. Read
    // Product.displayPrice directly from native StoreKit 2 and require two
    // consecutive complete identical snapshots before exposing prices.
    final requestedIds = productList.map((product) => product.id).toList();
    Map<String, String>? previousComplete;

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

    throw StateError(
      'Stable localized App Store price unavailable for current storefront.',
    );
  }

  void startListening() {
    _subscription ??= _iap.purchaseStream.listen(
      _purchaseController.add,
      onError: _purchaseController.addError,
    );
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

    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
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
  }
}
