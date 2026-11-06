// =============================================================================
// Note Counter Pro - Premium Service (IAP + Rewarded Ad Trial)
// =============================================================================
//
// In-App Purchase using google_mobile_ads + in_app_purchase plugin.
//
// Plans:
//   - premium_monthly   (₹49/month, subscription)
//   - premium_yearly    (₹299/year, subscription)
//   - premium_lifetime  (₹499 one-time, non-consumable)
//
// Also supports:
//   - Rewarded ad trial (1 day / 30 day premium)
//   - Restore purchases
//   - Debug toggle for testing
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService _instance = PremiumService._();
  factory PremiumService() => _instance;

  static const String _prefsKey = 'is_premium';
  static const String _prefsPlanKey = 'premium_plan';
  static const String _prefsTrialExpiryKey = 'rewarded_trial_expiry';

  bool _isPremium = false;
  String _activePlan = '';
  int _trialExpiryMs = 0;

  // IAP instance
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _iapInitialized = false;

  bool get isPremium {
    if (_isPremium) return true;
    if (_trialExpiryMs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < _trialExpiryMs) return true;
    }
    return false;
  }

  bool get isTrialActive {
    if (_isPremium) return false;
    if (_trialExpiryMs <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch < _trialExpiryMs;
  }

  Duration? get trialRemaining {
    if (_trialExpiryMs <= 0) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = _trialExpiryMs - now;
    if (diff <= 0) return Duration.zero;
    return Duration(milliseconds: diff);
  }

  String get trialRemainingLabel {
    final r = trialRemaining;
    if (r == null || r == Duration.zero) return '';
    final hours = r.inHours;
    final minutes = r.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String get activePlan => _activePlan;

  static const List<Map<String, dynamic>> plans = [
    {
      'id': 'premium_monthly',
      'name': 'Monthly',
      'price': '₹49',
      'period': '/month',
      'description': 'Ad-free for 1 month',
      'isSubscription': true,
    },
    {
      'id': 'premium_yearly',
      'name': 'Yearly',
      'price': '₹299',
      'period': '/year',
      'description': 'Ad-free for 1 year (Save 49%)',
      'isSubscription': true,
      'badge': 'BEST VALUE',
    },
    {
      'id': 'premium_lifetime',
      'name': 'Lifetime',
      'price': '₹499',
      'period': 'one-time',
      'description': 'Ad-free forever — pay once',
      'isSubscription': false,
    },
  ];

  /// Initialize: load prefs + set up IAP listener.
  Future<void> init() async {
    debugPrint('PremiumService: init()');
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(_prefsKey) ?? false;
      _activePlan = prefs.getString(_prefsPlanKey) ?? '';
      _trialExpiryMs = prefs.getInt(_prefsTrialExpiryKey) ?? 0;

      // Check if trial expired
      if (_trialExpiryMs > 0 &&
          DateTime.now().millisecondsSinceEpoch >= _trialExpiryMs) {
        _trialExpiryMs = 0;
        await prefs.remove(_prefsTrialExpiryKey);
      }
    } catch (e) {
      debugPrint('PremiumService init failed: $e');
    }

    // Initialize IAP
    _initIAP();
    notifyListeners();
  }

  void _initIAP() {
    if (_iapInitialized) return;
    _iapInitialized = true;

    try {
      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onError: (e) {
          debugPrint('PremiumService: purchase stream error: $e');
        },
      );
      // In 3.1.0, connection is automatic — no initConnection() needed.
      debugPrint('PremiumService: IAP purchase stream listening');
    } catch (e) {
      debugPrint('PremiumService: IAP init failed: $e');
    }
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  void _handlePurchase(PurchaseDetails purchase) async {
    debugPrint('PremiumService: purchase status = ${purchase.status}');

    switch (purchase.status) {
      case PurchaseStatus.restored:
      case PurchaseStatus.purchased:
        // Verify and grant premium
        await _grantPremiumFromPurchase(purchase);
        // Complete the purchase (tell Google Play we handled it)
        if (purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
            debugPrint('PremiumService: purchase completed');
          } catch (e) {
            debugPrint('PremiumService: completePurchase failed: $e');
          }
        }
        break;

      case PurchaseStatus.error:
        debugPrint('PremiumService: purchase error: ${purchase.error}');
        break;

      case PurchaseStatus.canceled:
        debugPrint('PremiumService: purchase canceled');
        break;

      case PurchaseStatus.pending:
        debugPrint('PremiumService: purchase pending');
        break;
    }
  }

  Future<void> _grantPremiumFromPurchase(PurchaseDetails purchase) async {
    // Determine plan from product ID
    String plan = 'lifetime';
    if (purchase.productID == 'premium_monthly') {
      plan = 'monthly';
    } else if (purchase.productID == 'premium_yearly') {
      plan = 'yearly';
    }

    await _setPremium(true, plan: plan);
    debugPrint('PremiumService: premium granted! plan=$plan');
  }

  /// Purchase a plan — opens Google Play purchase flow.
  /// Returns a tuple: (success, error message, error code)
  Future<(bool, String?, String)> purchasePlanDebug(String productId) async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        return (false, 'In-app purchase is not available on this device.', 'not_available');
      }

      // Query product details
      final response = await _iap.queryProductDetails({productId});
      if (response.error != null) {
        return (false, response.error!.message, 'query_error');
      }
      if (response.productDetails.isEmpty) {
        return (false, 'Product not found. Make sure it is published in Play Console.', 'product_not_found');
      }

      final product = response.productDetails.first;

      // PurchaseParam — 3.1.0 doesn't have offerToken
      final param = PurchaseParam(productDetails: product);

      // Start purchase flow (both subscription and non-consumable use buyNonConsumable)
      await _iap.buyNonConsumable(purchaseParam: param);

      return (true, null, '');
    } catch (e) {
      debugPrint('PremiumService: purchasePlanDebug failed: $e');
      return (false, e.toString(), 'exception');
    }
  }

  /// Simple purchase (returns true if flow started successfully).
  Future<bool> purchasePlan(String productId) async {
    final (success, _, _) = await purchasePlanDebug(productId);
    return success;
  }

  /// Purchase lifetime premium directly.
  Future<bool> purchasePremium() async {
    return await purchasePlan('premium_lifetime');
  }

  /// Restore previous purchases from Google Play.
  Future<void> restorePurchases() async {
    debugPrint('PremiumService: restorePurchases');
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('PremiumService: restorePurchases failed: $e');
    }
  }

  /// Grant rewarded trial days (from watching ad).
  Future<void> grantRewardedTrialDays(int days) async {
    final expiry = DateTime.now().add(Duration(days: days));
    _trialExpiryMs = expiry.millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsTrialExpiryKey, _trialExpiryMs);
    } catch (e) {
      debugPrint('PremiumService: grantRewardedTrialDays failed: $e');
    }
    debugPrint('PremiumService: granted $days day(s) trial');
    notifyListeners();
  }

  Future<void> _setPremium(bool value, {String? plan}) async {
    if (_isPremium == value && (plan == null || plan == _activePlan)) return;
    _isPremium = value;
    if (plan != null) _activePlan = plan;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
      if (plan != null) await prefs.setString(_prefsPlanKey, plan);
    } catch (e) {
      debugPrint('PremiumService failed: $e');
    }
    notifyListeners();
  }

  /// Debug toggle for testing (no real purchase).
  Future<void> debugTogglePremium() async {
    await _setPremium(!_isPremium);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
