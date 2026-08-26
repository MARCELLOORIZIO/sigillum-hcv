import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

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
      final storeKitProducts = await SK2Product.products(
        fallback.keys.toList(),
      );
      for (final product in storeKitProducts) {
        final displayPrice = product.displayPrice.trim();
        if (displayPrice.isNotEmpty) {
          fallback[product.id] = displayPrice;
        }
      }
    } catch (_) {}
    return fallback;
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
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
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
