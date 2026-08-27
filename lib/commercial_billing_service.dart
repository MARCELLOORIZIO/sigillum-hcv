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
  static const _nativeStoreKit = MethodChannel('hcv.media');

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

    // On iOS the visible paywall must use the same storefront-aware StoreKit
    // source as the purchase sheet. Never fall back to ProductDetails.price:
    // in TestFlight that value can reflect a different storefront/currency.
    final requestedIds = productList.map((product) => product.id).toList();
    final resolved = <String, String>{};

    try {
      final storeKitProducts = await SK2Product.products(requestedIds);
      for (final product in storeKitProducts) {
        final displayPrice = product.displayPrice.trim();
        if (displayPrice.isNotEmpty && requestedIds.contains(product.id)) {
          resolved[product.id] = displayPrice;
        }
      }
    } catch (_) {
      // Native StoreKit 1 below remains a compatibility fallback only for
      // products StoreKit 2 could not resolve.
    }

    final missingIds = requestedIds
        .where((productId) => !resolved.containsKey(productId))
        .toList(growable: false);
    if (missingIds.isNotEmpty) {
      try {
        final raw = await _nativeStoreKit.invokeMethod<Map<Object?, Object?>>(
          'localizedProductPrices',
          {'productIds': missingIds},
        );
        if (raw != null) {
          for (final entry in raw.entries) {
            final id = entry.key?.toString() ?? '';
            final price = entry.value?.toString().trim() ?? '';
            if (missingIds.contains(id) && price.isNotEmpty) {
              resolved[id] = price;
            }
          }
        }
      } catch (_) {}
    }

    final unresolved = requestedIds
        .where((productId) => !resolved.containsKey(productId))
        .toList(growable: false);
    if (unresolved.isNotEmpty) {
      throw StateError(
        'Localized App Store price unavailable for: ${unresolved.join(', ')}',
      );
    }

    return resolved;
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
