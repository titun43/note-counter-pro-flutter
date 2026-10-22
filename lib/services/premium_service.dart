// =============================================================================
// Note Counter Pro - Premium Service (Google Play In-App Purchase)
// =============================================================================
// Manages premium subscription status via Google Play Billing.
//
// Product IDs:
//   - 'premium_monthly'   (₹49/month, auto-renewing subscription)
//   - 'premium_yearly'    (₹299/year, auto-renewing subscription)
//   - 'premium_lifetime'  (₹499 one-time, non-consumable)
//
// Flow:
//   1. init() — connect to billing, restore previous purchases
//   2. isPremium — observable flag consumed by AdMobService + UI
//   3. purchasePlan(productId) — launches Play billing flow for a plan
//   4. restorePurchases() — re-check purchases (user reinstalled app)
//
// Persistence: SharedPreferences 'is_premium' flag (survives app restarts).
// Truth source: Google Play (restorePurchases re-verifies on every app start).
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumService {
  PremiumService._();
  static final PremiumService _instance = PremiumService._();
  factory PremiumService() => _instance;

  // Product IDs
  static const String productIdMonthly = 'premium_monthly';
  static const String productIdYearly = 'premium_yearly';
  static const String productIdLifetime = 'premium_lifetime';

  static const List<String> _allProductIds = [
    productIdMonthly,
    productIdYearly,
    productIdLifetime,
  ];

  static const String _prefsKey = 'is_premium';
  static const String _prefsPlanKey = 'premium_plan';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isPremium = false;
  String _activePlan = '';
  bool _initialized = false;

  bool get isPremium => _isPremium;
  String get activePlan => _activePlan;

  /// Available plans for UI display
  static const List<Map<String, dynamic>> plans = [
    {
      'id': productIdMonthly,
      'name': 'Monthly',
      'price': '₹49',
      'period': '/month',
      'description': 'Ad-free for 1 month',
      'isSubscription': true,
    },
    {
      'id': productIdYearly,
      'name': 'Yearly',
      'price': '₹299',
      'period': '/year',
      'description': 'Ad-free for 1 year (Save 49%)',
      'isSubscription': true,
      'badge': 'BEST VALUE',
    },
    {
      'id': productIdLifetime,
      'name': 'Lifetime',
      'price': '₹499',
      'period': 'one-time',
      'description': 'Ad-free forever — pay once',
      'isSubscription': false,
    },
  ];

  /// Initialize the service. Call once on app start.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(_prefsKey) ?? false;
      _activePlan = prefs.getString(_prefsPlanKey) ?? '';
    } catch (_) {}

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (e) => debugPrint('PremiumService: purchase stream error: $e'),
    );

    await _restorePurchases();
  }

  Future<void> _restorePurchases() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) return;
      debugPrint('PremiumService: IAP available, waiting for stream events');
    } catch (e) {
      debugPrint('PremiumService: restorePurchases failed (non-fatal): $e');
    }
  }

  /// Purchase a specific plan by product ID.
  Future<bool> purchasePlan(String productId) async {
    try {
      final available = await _iap.isAvailable();
      if (!available) return false;

      final response = await _iap.queryProductDetails({productId});
      if (response.error != null || response.productDetails.isEmpty) {
        debugPrint('PremiumService: product not found: $productId');
        return false;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);

      // Determine if it's a subscription or non-consumable
      if (productId == productIdLifetime) {
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('PremiumService: purchasePlan failed: $e');
      return false;
    }
  }

  /// Legacy method — purchases lifetime plan
  Future<bool> purchasePremium() async {
    return purchasePlan(productIdLifetime);
  }

  Future<void> restorePurchases() async {
    await _restorePurchases();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  void _handlePurchase(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        if (_allProductIds.contains(purchase.productID)) {
          _setPremium(true, plan: purchase.productID);
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
        }
        break;
      case PurchaseStatus.error:
        debugPrint('PremiumService: purchase error: ${purchase.error}');
        break;
      case PurchaseStatus.canceled:
        debugPrint('PremiumService: purchase canceled');
        break;
      default:
        break;
    }
  }

  Future<void> _setPremium(bool value, {String? plan}) async {
    if (_isPremium == value && (plan == null || plan == _activePlan)) return;
    _isPremium = value;
    if (plan != null) _activePlan = plan;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
      if (plan != null) await prefs.setString(_prefsPlanKey, plan);
    } catch (_) {}
    debugPrint('PremiumService: isPremium=$value, plan=${plan ?? _activePlan}');
  }

  Future<void> debugTogglePremium() async {
    await _setPremium(!_isPremium);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
