// =============================================================================
// Note Counter Pro - Saved UPI Service
// =============================================================================
// Persists user-saved UPI IDs in SharedPreferences as a JSON list.
// Provides CRUD operations + group filtering.
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_upi.dart';

class SavedUpiService {
  static const String _prefsKey = 'saved_upi_ids';

  static final SavedUpiService _instance = SavedUpiService._();
  factory SavedUpiService() => _instance;
  SavedUpiService._();

  List<SavedUpi> _savedUpis = [];

  List<SavedUpi> get all => List.unmodifiable(_savedUpis);

  /// Get saved UPIs filtered by group.
  List<SavedUpi> getByGroup(String group) {
    return _savedUpis.where((u) => u.group == group).toList();
  }

  /// All groups in display order.
  static const List<String> groups = ['favorites', 'business', 'family', 'other'];

  /// Load saved UPIs from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _savedUpis = list
            .map((e) => SavedUpi.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('SavedUpiService: loaded ${_savedUpis.length} saved UPI IDs');
    } catch (e) {
      debugPrint('SavedUpiService init failed: $e');
    }
  }

  /// Add a new saved UPI. Returns false if a duplicate UPI ID already exists.
  Future<bool> add(SavedUpi upi) async {
    if (_savedUpis.any((u) => u.upiId.toLowerCase() == upi.upiId.toLowerCase())) {
      return false;
    }
    _savedUpis.add(upi);
    await _persist();
    return true;
  }

  /// Update an existing saved UPI by id.
  Future<void> update(SavedUpi updated) async {
    final i = _savedUpis.indexWhere((u) => u.id == updated.id);
    if (i != -1) {
      _savedUpis[i] = updated;
      await _persist();
    }
  }

  /// Delete a saved UPI by id.
  Future<void> delete(String id) async {
    _savedUpis.removeWhere((u) => u.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_savedUpis.map((u) => u.toJson()).toList());
      await prefs.setString(_prefsKey, raw);
    } catch (e) {
      debugPrint('SavedUpiService persist failed: $e');
    }
  }
}
