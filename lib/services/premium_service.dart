// =============================================================================
// Note Counter Pro - Premium Service (Local-Only, No IAP)
// =============================================================================
// In-App Purchase plugin temporarily removed due to Play Billing 16 KB
// page size + version conflict with Flutter 3.35.5.
//
// Premium is now local-only:
//   - Rewarded ad trial still works (grantRewardedTrialDays)
//   - No purchase flow (purchasePlan returns false with message)
//   - No restore from Google Play
//   - Debug toggle still works for testing
//
// Will re-add in_app_purchase when Flutter ships 16 KB compatible .so files.
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> init() async {
    debugPrint('PremiumService: init() (local-only, no IAP)');
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(_prefsKey) ?? false;
      _activePlan = prefs.getString(_prefsPlanKey) ?? '';
      _trialExpiryMs = prefs.getInt(_prefsTrialExpiryKey) ?? 0;
      debugPrint('PremiumService: loaded — isPremium=$_isPremium, trial=$_trialExpiryMs');
    } catch (e) {
      debugPrint('PremiumService init failed: $e');
    }
    notifyListeners();
  }

  Future<void> grantRewardedTrialDays(int days) async {
    final now = DateTime.now();
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
    debugPrint('PremiumService: granted $days day(s) trial');
    notifyListeners();
  }

  /// Purchase plan — currently disabled (no IAP plugin).
  /// Returns a tuple indicating failure with a helpful message.
  Future<(bool, String?, String)> purchasePlanDebug(String productId) async {
    return (
      false,
      'In-app purchase is temporarily unavailable. '
      'Please use "Watch Ad" to get free premium trial.',
      'no_iap',
    );
  }

  Future<bool> purchasePlan(String productId) async {
    return false;
  }

  Future<bool> purchasePremium() async {
    return false;
  }

  Future<void> restorePurchases() async {
    debugPrint('PremiumService: restorePurchases (no-op, IAP removed)');
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

  Future<void> debugTogglePremium() async {
    await _setPremium(!_isPremium);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
