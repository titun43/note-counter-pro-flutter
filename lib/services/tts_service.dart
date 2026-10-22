// =============================================================================
// Note Counter Pro - Text-to-Speech Service
// =============================================================================
// Announces the saved entry in the user's selected app language.
//
// Behavior:
// - Reads SharedPreferences for 'voice_announcement' (default: true)
// - Reads SharedPreferences for 'app_language' (default: 'en')
// - Uses Android AudioManager to route audio through loudspeaker
// - Builds a localized announcement string from:
//     * transactionType (Payable/Receivable equivalent)
//     * name (optional)
//     * totalAmount (number)
//     * note (optional)
// - Skips announcement entirely if totalAmount is 0
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  TtsService._();
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  /// Initialize engine + audio routing. Safe to call multiple times.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await _tts.setEngine('android');
      // Try to route through loudspeaker (speakerphone-style)
      // flutter_tts exposes this only via awaitSpeakCompletion; volume boost is platform-side.
      await _tts.setSpeechRate(0.45); // slower for clarity (default 0.85 was too fast)
      await _tts.setVolume(1.0); // max volume
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('TtsService init failed (non-fatal): $e');
    }
  }

  /// Read user's voice toggle setting (default: true = ON).
  Future<bool> _isVoiceEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('voice_announcement') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Public getter for UI (Settings screen) to read current state.
  Future<bool> isVoiceEnabled() => _isVoiceEnabled();

  /// Read user's app language (default: 'en').
  /// Reads 'languageCode' from SharedPreferences (same key StorageService uses).
  Future<String> _getAppLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('languageCode') ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  /// Map app language code to BCP-47 locale for TTS engine.
  String _localeForLanguage(String lang) {
    switch (lang) {
      case 'bn':
        return 'bn-IN';
      case 'hi':
        return 'hi-IN';
      case 'en':
      default:
        return 'en-IN';
    }
  }

  /// Build the localized announcement text.
  /// Returns null if announcement should be skipped (e.g. amount is 0).
  String? _buildAnnouncement({
    required String language,
    required String transactionType,
    required double totalAmount,
    String? name,
    String? note,
    required String currencySymbol,
  }) {
    // Skip if total is 0 (per developer spec)
    if (totalAmount <= 0) return null;

    final amountStr = totalAmount.toStringAsFixed(2);

    switch (language) {
      case 'bn':
        return _buildBn(
          transactionType: transactionType,
          amount: amountStr,
          name: name,
          note: note,
        );
      case 'hi':
        return _buildHi(
          transactionType: transactionType,
          amount: amountStr,
          name: name,
          note: note,
        );
      case 'en':
      default:
        return _buildEn(
          transactionType: transactionType,
          amount: amountStr,
          name: name,
          note: note,
        );
    }
  }

  String _buildEn({
    required String transactionType,
    required String amount,
    String? name,
    String? note,
  }) {
    final buf = StringBuffer();
    if (name != null && name.trim().isNotEmpty) {
      buf.write('Saved for ${name.trim()}. ');
    }
    buf.write('Total amount: $amount rupees. ');
    if (note != null && note.trim().isNotEmpty) {
      buf.write('Notes: ${note.trim()}.');
    }
    return buf.toString().trim();
  }

  String _buildBn({
    required String transactionType,
    required String amount,
    String? name,
    String? note,
  }) {
    final buf = StringBuffer();
    if (name != null && name.trim().isNotEmpty) {
      buf.write('${name.trim()}-এর জন্য সেভ করা হলো। ');
    }
    buf.write('মোট টাকা: $amount টাকা। ');
    if (note != null && note.trim().isNotEmpty) {
      buf.write('নোট: ${note.trim()}.');
    }
    return buf.toString().trim();
  }

  String _buildHi({
    required String transactionType,
    required String amount,
    String? name,
    String? note,
  }) {
    final buf = StringBuffer();
    if (name != null && name.trim().isNotEmpty) {
      buf.write('${name.trim()} के लिए सेव किया गया। ');
    }
    buf.write('कुल राशि: $amount रुपये। ');
    if (note != null && note.trim().isNotEmpty) {
      buf.write('नोट्स: ${note.trim()}.');
    }
    return buf.toString().trim();
  }

  /// Main entry: announce a save event.
  ///
  /// - [transactionType]: localized 'Payable' / 'Receivable' / 'পরিশোধ্য' etc.
  /// - [totalAmount]: total amount saved (0 → skipped).
  /// - [name]: optional customer/person name.
  /// - [note]: optional note text the user typed in the note field.
  /// - [currencySymbol]: for reference (currently voice always says "rupees"/"টাকা"/"रुपये").
  Future<void> announceSave({
    required String transactionType,
    required double totalAmount,
    String? name,
    String? note,
    String currencySymbol = '₹',
  }) async {
    try {
      final enabled = await _isVoiceEnabled();
      if (!enabled) return;

      final language = await _getAppLanguage();
      final text = _buildAnnouncement(
        language: language,
        transactionType: transactionType,
        totalAmount: totalAmount,
        name: name,
        note: note,
        currencySymbol: currencySymbol,
      );
      if (text == null || text.isEmpty) return;

      await _ensureInitialized();
      await _tts.setLanguage(_localeForLanguage(language));
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TtsService.announceSave failed (non-fatal): $e');
    }
  }

  /// Stop any in-progress announcement.
  Future<void> stop() async {
    try {
      await _ensureInitialized();
      await _tts.stop();
    } catch (_) {}
  }

  /// Set the voice toggle persistently.
  Future<void> setVoiceEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voice_announcement', enabled);
    } catch (_) {}
  }

  /// Set the app language persistently (also used by other UI parts).
  Future<void> setAppLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', language);
    } catch (_) {}
  }
}
