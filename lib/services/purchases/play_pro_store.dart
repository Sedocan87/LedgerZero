import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:ledger_zero/core/constants/pro_features.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/purchases/pro_store.dart';

/// LedgerZero Pro through Google Play Billing (the official
/// `in_app_purchase` plugin). Play shows the purchase sheet, takes the
/// payment and confirms the purchase to the app on the phone; nothing goes
/// through a server of ours, and no third-party purchase service is used.
class PlayProStore implements ProStore {
  PlayProStore({InAppPurchase? iap, this.productId = ProFeatures.productId})
    : _iap = iap ?? InAppPurchase.instance {
    // Subscribed from the start: a purchase finished while the app was
    // closed (or killed during the sheet) is delivered after the next start
    // and must be acknowledged, or Play refunds it after three days.
    _subscription = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        Logger.warning('Play purchase stream: $e');
        _updates.add(ProPurchaseUpdate(ProPurchaseStatus.failed, error: '$e'));
      },
    );
  }

  final InAppPurchase _iap;

  /// The Play product that unlocks Pro.
  final String productId;
  final _updates = StreamController<ProPurchaseUpdate>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;

  @override
  Stream<ProPurchaseUpdate> get updates => _updates.stream;

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) {
        continue;
      }
      if (purchase.status == PurchaseStatus.error &&
          _isAlreadyOwnedError(purchase.error)) {
        final alreadyOwned = await owned();
        if (alreadyOwned == true) {
          _updates.add(const ProPurchaseUpdate(ProPurchaseStatus.purchased));
          continue;
        }
      }
      final update = switch (purchase.status) {
        PurchaseStatus.pending => const ProPurchaseUpdate(
          ProPurchaseStatus.pending,
        ),
        PurchaseStatus.purchased || PurchaseStatus.restored =>
          const ProPurchaseUpdate(ProPurchaseStatus.purchased),
        PurchaseStatus.canceled => const ProPurchaseUpdate(
          ProPurchaseStatus.cancelled,
        ),
        PurchaseStatus.error => ProPurchaseUpdate(
          ProPurchaseStatus.failed,
          error: purchase.error?.message,
        ),
      };
      if (purchase.pendingCompletePurchase) {
        await _complete(purchase);
      }
      _updates.add(update);
    }
  }

  static bool _isAlreadyOwnedError(IAPError? error) {
    if (error == null) {
      return false;
    }
    final code = error.code.toLowerCase();
    final message = error.message.toLowerCase();
    return code.contains('already_owned') ||
        code.contains('itemalreadyowned') ||
        message.contains('already_owned') ||
        message.contains('itemalreadyowned') ||
        message.contains('item already owned');
  }

  /// Acknowledges [purchase]; Play refunds a purchase that is not
  /// acknowledged within three days. On Android the plugin reports a
  /// failed acknowledgement as a BillingResult instead of throwing. A
  /// failure is retried by the next [owned] (at start and when the app
  /// comes back to the foreground).
  Future<bool> _complete(PurchaseDetails purchase) async {
    try {
      // The facade is typed Future<void> but hands over the platform's
      // result.
      final Object? result =
          await (_iap.completePurchase(purchase) as Future<Object?>);
      if (result is BillingResultWrapper &&
          result.responseCode != BillingResponse.ok) {
        Logger.warning(
          'Acknowledging the Pro purchase failed: ${result.responseCode} '
          '${result.debugMessage ?? ''}',
        );
        return false;
      }
      return true;
    } catch (e) {
      Logger.warning('Acknowledging the Pro purchase failed: $e');
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (e) {
      Logger.warning('Play billing unavailable: $e');
      return false;
    }
  }

  Future<ProductDetails?> _loadProduct() async {
    if (_product != null) {
      return _product;
    }
    try {
      final response = await _iap.queryProductDetails({productId});
      if (response.error != null) {
        Logger.warning('Play product query: ${response.error!.message}');
      }
      return _product = response.productDetails
          .where((p) => p.id == productId)
          .firstOrNull;
    } catch (e) {
      Logger.warning('Play product query failed: $e');
      return null;
    }
  }

  @override
  Future<String?> price() async => (await _loadProduct())?.price;

  @override
  Future<bool> buy() async {
    final product = await _loadProduct();
    if (product == null) {
      return false;
    }
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      Logger.warning('Opening the Play purchase sheet failed: $e');
      return false;
    }
  }

  @override
  Future<bool?> owned() async {
    try {
      final addition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) {
        Logger.warning('Play purchase query: ${response.error!.message}');
        return null;
      }
      var owned = false;
      for (final purchase in response.pastPurchases) {
        if (purchase.productID != productId ||
            (purchase.status != PurchaseStatus.purchased &&
                purchase.status != PurchaseStatus.restored)) {
          continue;
        }
        if (purchase.pendingCompletePurchase) {
          await _complete(purchase);
        }
        owned = true;
      }
      return owned;
    } catch (e) {
      Logger.warning('Play purchase query failed: $e');
      return null;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_updates.close());
  }
}
