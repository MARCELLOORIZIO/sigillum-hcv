import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

class CommercialBillingService {
  CommercialBillingService._();

  static final instance = CommercialBillingService._();

  static const monthlyProductId = 'com.sigillum.hcv.creator.monthly';
  static const annualProductId = 'com.sigillum.hcv.creator.annual';
  static const productIds = {monthlyProductId, annualProductId};

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
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return products;
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
