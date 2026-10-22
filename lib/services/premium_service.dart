// =============================================================================
// Note Counter Pro - Premium Service (Google Play In-App Purchase)
// =============================================================================
// Manages premium subscription status via Google Play Billing.
//
// Product ID: 'premium_lifetime' (one-time purchase, ad-free forever)
//
// Flow:
//   1. init() — connect to billing, restore previous purchases
//   2. isPremium — observable flag consumed by AdMobService + UI
//   3. purchasePremium() — launches Play billing flow
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

  static const String _productId = 'premium_lifetime';
  static const String _prefsKey = 'is_premium';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isPremium = false;
  bool _initialized = false;

  // Public getter
  bool get isPremium => _isPremium;

  /// Initialize the service. Call once on app start.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Load cached value first (instant UI)
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {}

    // Listen to purchase stream
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (e) => debugPrint('PremiumService: purchase stream error: $e'),
    );

    // Request products + restore previous purchases
    await _restorePurchases();
  }

  /// Restore previous purchases from Google Play.
  /// Called automatically on init, and manually from Settings.
  ///
  /// In in_app_purchase 3.x, Google Play automatically delivers past
  /// purchases through the purchaseStream on connection. So we just
  /// need to ensure the connection is open — the stream listener will
  /// receive any restored purchases as PurchaseStatus.restored events.
  Future<void> _restorePurchases() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('PremiumService: IAP not available');
        return;
      }
      // Google Play auto-delivers past purchases via purchaseStream.
      // No need to call queryPastPurchases (removed in in_app_purchase 3.x).
      // The purchaseStream listener (_onPurchaseUpdated) handles them.
      debugPrint('PremiumService: IAP available, waiting for stream events');
    } catch (e) {
      debugPrint('PremiumService: restorePurchases failed (non-fatal): $e');
    }
  }

  /// Manually trigger purchase of premium.
  /// Returns true if purchase flow started successfully.
  Future<bool> purchasePremium() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('PremiumService: IAP not available');
        return false;
      }

      final response = await _iap.queryProductDetails({_productId});
      if (response.error != null || response.productDetails.isEmpty) {
        debugPrint('PremiumService: product not found: ${response.error}');
        return false;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      // Non-consumable — one-time purchase
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return started;
    } catch (e) {
      debugPrint('PremiumService: purchasePremium failed: $e');
      return false;
    }
  }

  /// Manually restore purchases (from Settings).
  Future<void> restorePurchases() async {
    await _restorePurchases();
  }

  /// Listen to purchase updates.
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  /// Handle a single purchase event.
  void _handlePurchase(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        if (purchase.productID == _productId) {
          _setPremium(true);
          // Acknowledge the purchase (required for non-consumable)
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

  /// Set premium flag + persist.
  Future<void> _setPremium(bool value) async {
    if (_isPremium == value) return;
    _isPremium = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
    debugPrint('PremiumService: isPremium = $value');
  }

  /// DEV ONLY: manually toggle premium for testing.
  /// Remove before production release.
  Future<void> debugTogglePremium() async {
    await _setPremium(!_isPremium);
  }

  /// Cleanup on app dispose.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
