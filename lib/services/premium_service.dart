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
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PremiumService is a ChangeNotifier so that any UI widget listening via
/// `ListenableBuilder` / `AnimatedBuilder` / `context.watch` (when wrapped
/// in a provider) rebuilds automatically when premium state changes.
///
/// Specifically: when a rewarded-ad trial is granted, the App Lock / Voice
/// Announcement toggles in Settings must become enabled — they don't
/// unless the PremiumService notifies listeners.
class PremiumService extends ChangeNotifier {
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
  /// Timestamp (ms since epoch) when rewarded-ad premium trial expires.
  /// 0 means no active trial. Set by grantRewardedTrialDays().
  static const String _prefsTrialExpiryKey = 'rewarded_trial_expiry';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isPremium = false;
  String _activePlan = '';
  /// Wall-clock millis when the current rewarded-ad trial expires.
  /// 0 if no trial is active. Read from prefs on init.
  int _trialExpiryMs = 0;

  bool get isPremium {
    // Premium is true if either:
    //   - User has a paid IAP plan (isPremium flag), OR
    //   - Rewarded-ad trial is still active (expiry in the future)
    if (_isPremium) return true;
    if (_trialExpiryMs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < _trialExpiryMs) return true;
    }
    return false;
  }

  /// Whether the currently active premium comes from a rewarded-ad trial
  /// (rather than a paid IAP plan). Used to show appropriate UI labels.
  bool get isTrialActive {
    if (_isPremium) return false; // Paid plan takes precedence
    if (_trialExpiryMs <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch < _trialExpiryMs;
  }

  /// Remaining trial time as a Duration (zero if no active trial).
  Duration? get trialRemaining {
    if (_trialExpiryMs <= 0) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = _trialExpiryMs - now;
    if (diff <= 0) return Duration.zero;
    return Duration(milliseconds: diff);
  }

  /// Human-readable trial expiry (e.g. "Expires in 23h 45m").
  String get trialRemainingLabel {
    final r = trialRemaining;
    if (r == null || r == Duration.zero) return '';
    final hours = r.inHours;
    final minutes = r.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

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

  /// Initialize the service. Called on app start.
  ///
  /// This method is SAFE to call multiple times — it will always reload
  /// the persisted premium/trial state from SharedPreferences and notify
  /// listeners. The previous version used an _initialized flag that
  /// caused init() to silently skip on subsequent calls (e.g. after hot
  /// restart), leaving the UI with stale isPremium=false even though a
  /// trial was active.
  ///
  /// The IAP purchase stream subscription is only created once (guarded
  /// by _subscription != null) to avoid duplicate listeners.
  Future<void> init() async {
    debugPrint('PremiumService: === init() START ===');
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(_prefsKey) ?? false;
      _activePlan = prefs.getString(_prefsPlanKey) ?? '';
      _trialExpiryMs = prefs.getInt(_prefsTrialExpiryKey) ?? 0;
      debugPrint('PremiumService: loaded from prefs — isPremium=$_isPremium, plan=$_activePlan, trialExpiry=$_trialExpiryMs');
    } catch (e) { debugPrint('PremiumService failed: $e'); }

    // Only subscribe to the IAP purchase stream once.
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (e) => debugPrint('PremiumService: ❌ purchase stream error: $e'),
    );
    debugPrint('PremiumService: purchase stream listener attached');

    await _restorePurchases();

    // CRITICAL: always notify listeners so any UI widget bound to
    // isPremium (Settings screen App Lock / Voice toggles, Premium
    // screen, etc.) rebuilds with the correct premium state loaded
    // from prefs. Without this, the Settings screen keeps the stale
    // isPremium=false from the first build (before init() completed).
    notifyListeners();
    debugPrint('PremiumService: === init() END ===');
  }

  /// Grant the user a free premium trial by watching a rewarded ad.
  /// Adds [days] days to the current trial expiry (or starts a new trial).
  /// Stackable — multiple ad views extend the trial.
  ///
  /// Notifies listeners so that any UI widget bound to [isPremium]
  /// (e.g. the App Lock and Voice Announcement toggles in Settings)
  /// immediately reflects the new premium state.
  Future<void> grantRewardedTrialDays(int days) async {
    final now = DateTime.now();
    // If a trial is currently active, extend from its expiry; otherwise start fresh.
    final baseMs = (_trialExpiryMs > now.millisecondsSinceEpoch)
        ? _trialExpiryMs
        : now.millisecondsSinceEpoch;
    _trialExpiryMs = baseMs + (days * 24 * 60 * 60 * 1000);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsTrialExpiryKey, _trialExpiryMs);
    } catch (e) {
      debugPrint('PremiumService: grantRewardedTrialDays failed: $e');
    }
    debugPrint('PremiumService: granted $days day(s) trial. Expires at '
        '${DateTime.fromMillisecondsSinceEpoch(_trialExpiryMs).toIso8601String()}');
    // CRITICAL: notify listeners so the UI re-reads isPremium and unlocks
    // the App Lock / Voice Announcement / Cloud Backup / Printer toggles.
    notifyListeners();
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
  ///
  /// For subscriptions (Monthly/Yearly) AND non-consumables (Lifetime),
  /// we use buyNonConsumable — this is the correct Play Billing flow.
  /// Subscriptions are simply non-consumable recurring purchases.
  Future<bool> purchasePlan(String productId) async {
    try {
      debugPrint('PremiumService: === purchasePlan START for $productId ===');

      // 1. Check billing availability
      final available = await _iap.isAvailable();
      debugPrint('PremiumService: IAP available = $available');
      if (!available) {
        debugPrint('PremiumService: ❌ IAP NOT AVAILABLE — billing client cannot connect');
        return false;
      }

      // 2. Query product details
      debugPrint('PremiumService: querying product details for: $productId');
      final response = await _iap.queryProductDetails({productId});
      if (response.error != null) {
        debugPrint('PremiumService: ❌ queryProductDetails error: ${response.error}');
        return false;
      }
      if (response.productDetails.isEmpty) {
        debugPrint('PremiumService: ❌ product NOT FOUND: $productId');
        debugPrint('PremiumService:   → Check that product is ACTIVE in Play Console');
        debugPrint('PremiumService:   → Check that product ID matches exactly');
        debugPrint('PremiumService:   → Check that app is signed with same key as Play Console');
        return false;
      }

      final product = response.productDetails.first;
      debugPrint('PremiumService: ✅ product found: ${product.id} — ${product.title} — ${product.price}');

      // 3. Determine if subscription (for logging only — both use buyNonConsumable)
      final isSubscription = productId != productIdLifetime;
      debugPrint('PremiumService: isSubscription = $isSubscription');

      // 4. Launch billing flow
      final purchaseParam = PurchaseParam(productDetails: product);
      debugPrint('PremiumService: launching billing flow (buyNonConsumable)...');
      final ok = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('PremiumService: buyNonConsumable returned = $ok');
      if (!ok) {
        debugPrint('PremiumService: ❌ billing flow did NOT start');
      } else {
        debugPrint('PremiumService: ✅ billing flow started — waiting for purchaseStream event');
      }
      return ok;
    } catch (e, st) {
      debugPrint('PremiumService: ❌ purchasePlan EXCEPTION: $e');
      debugPrint('PremiumService: stacktrace: $st');
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
    debugPrint('PremiumService: === purchaseStream EVENT === ${purchases.length} purchase(s)');
    for (final purchase in purchases) {
      debugPrint('PremiumService:   purchase: id=${purchase.purchaseID}, '
          'product=${purchase.productID}, status=${purchase.status}, '
          'pendingComplete=${purchase.pendingCompletePurchase}');
      _handlePurchase(purchase);
    }
  }

  void _handlePurchase(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
        debugPrint('PremiumService: ✅ PURCHASED — ${purchase.productID}');
        if (_allProductIds.contains(purchase.productID)) {
          _setPremium(true, plan: purchase.productID);
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
        }
        break;
      case PurchaseStatus.restored:
        debugPrint('PremiumService: ✅ RESTORED — ${purchase.productID}');
        if (_allProductIds.contains(purchase.productID)) {
          _setPremium(true, plan: purchase.productID);
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
        }
        break;
      case PurchaseStatus.error:
        debugPrint('PremiumService: ❌ purchase ERROR: ${purchase.error}');
        break;
      case PurchaseStatus.canceled:
        debugPrint('PremiumService: ⚠️ purchase CANCELED by user');
        break;
      default:
        debugPrint('PremiumService: unknown purchase status: ${purchase.status}');
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
    } catch (e) { debugPrint('PremiumService failed: $e'); }
    debugPrint('PremiumService: isPremium=$value, plan=${plan ?? _activePlan}');
    // Notify listeners so any UI bound to isPremium refreshes immediately.
    notifyListeners();
  }

  Future<void> debugTogglePremium() async {
    await _setPremium(!_isPremium);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
