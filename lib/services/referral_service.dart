// =============================================================================
// Note Counter Pro - Refer & Earn Service
// =============================================================================
// Premium feature: Users get 1 month of premium benefits for each successful
// referral. Referral works via unique code + share link.
//
// NOTE: Note Counter Pro has no Firebase backend, so we can't auto-verify
// referral purchases. Instead:
//   - User shares their unique referral code + Play Store link
//   - Referred user enters the code in Settings → Refer & Earn
//   - Code is stored locally + shown to app owner via email
//   - App owner manually grants premium from Play Console Order Management
//     (using the IAP order ID) OR grants a free month via promo code
//
// For a fully automated system, would need Firebase backend — not in scope.
// =============================================================================

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'premium_service.dart';

class ReferralService {
  ReferralService._();
  static final ReferralService _instance = ReferralService._();
  factory ReferralService() => _instance;

  static const String _prefsKey = 'referral_code';
  static const String _historyKey = 'referral_history';
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.lokhnathtechnical.notecounterpro';

  String? _referralCode;
  List<Map<String, dynamic>> _history = [];

  String? get referralCode => _referralCode;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  /// Initialize — load or generate referral code
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _referralCode = prefs.getString(_prefsKey);
      if (_referralCode == null) {
        _referralCode = _generateCode();
        await prefs.setString(_prefsKey, _referralCode!);
      }

      final historyStr = prefs.getString(_historyKey);
      if (historyStr != null) {
        final list = jsonDecode(historyStr) as List;
        _history = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('ReferralService init failed: $e');
    }
  }

  /// Generate a unique 8-char referral code (e.g. NCP-AB12CD)
  String _generateCode() {
    final random = Random.secure();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final code =
        List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return 'NCP-$code';
  }

  /// Get shareable referral message
  String getShareMessage() {
    return '''
📱 Note Counter Pro — Smart Cash Counter App

Hey! I'm using Note Counter Pro for cash counting & khata management. It's super useful for shopkeepers.

📥 Download free: $_playStoreUrl

🎁 Use my referral code: $_referralCode
(After installing, go to Settings → Refer & Earn → Enter Code)

Features:
• Multi-currency note counter
• Khata (ledger) with customer tracking
• UPI QR code payment
• WhatsApp payment reminder
• Voice announcement on save
• PDF reports

— Sent via Note Counter Pro
''';
  }

  /// Share referral via WhatsApp/SMS/etc (uses url_launcher / share_plus)
  /// We delegate to the caller to use share_plus, but we provide the message.
  String getShareText() => getShareMessage();

  /// Open Play Store directly (for the referrer to verify)
  Future<void> openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Submit a referral code (when a NEW user enters someone's code).
  /// Returns true if code is valid format (NCP-XXXXXX) and not their own.
  Future<bool> submitReferralCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    // Validate format
    if (!RegExp(r'^NCP-[A-Z0-9]{6}$').hasMatch(trimmed)) {
      return false;
    }
    // Can't refer yourself
    if (trimmed == _referralCode) {
      return false;
    }
    // Already submitted this code?
    if (_history.any((h) => h['code'] == trimmed)) {
      return false;
    }

    // Add to history
    _history.insert(0, {
      'code': trimmed,
      'submittedAt': DateTime.now().toIso8601String(),
      'status': 'pending', // pending → verified → rewarded
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_history));
    } catch (_) {}

    return true;
  }

  /// Get count of pending referrals (for UI badge)
  int get pendingCount =>
      _history.where((h) => h['status'] == 'pending').length;

  /// Get count of verified referrals
  int get verifiedCount =>
      _history.where((h) => h['status'] == 'verified').length;

  /// Clear history (dev only)
  Future<void> clearHistory() async {
    _history.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {}
  }
}
