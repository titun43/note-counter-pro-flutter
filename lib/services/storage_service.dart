import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import 'backup_service.dart';

class StorageService extends ChangeNotifier {
  final SharedPreferences? _prefs;
  
  List<Entry> _entries = [];
  List<Customer> _customers = [];
  List<Bill> _bills = [];
  
  StorageService(this._prefs) {
    _loadData();
  }
  
  void _loadData() {
    if (_prefs == null) return;
    
    try {
      // Load entries
      final entriesJson = _prefs!.getString('entries');
      if (entriesJson != null) {
        final list = jsonDecode(entriesJson) as List;
        _entries = list.map((e) => Entry.fromJson(e as Map<String, dynamic>)).toList();
      }
      
      // Load customers
      final customersJson = _prefs!.getString('customers');
      if (customersJson != null) {
        final list = jsonDecode(customersJson) as List;
        _customers = list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
      }
      
      // Load bills
      final billsJson = _prefs!.getString('bills');
      if (billsJson != null) {
        final list = jsonDecode(billsJson) as List;
        _bills = list.map((e) => Bill.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('StorageService loadData failed: $e');
    }
  }
  
  Future<void> _saveEntries() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setString('entries', jsonEncode(_entries.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Save entries failed: $e');
    }
  }
  
  Future<void> _saveCustomers() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setString('customers', jsonEncode(_customers.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Save customers failed: $e');
    }
  }
  
  Future<void> _saveBills() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setString('bills', jsonEncode(_bills.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Save bills failed: $e');
    }
  }
  
  // === Theme ===
  bool get isDarkMode => _prefs?.getBool('isDarkMode') ?? true;
  
  Future<void> setDarkMode(bool value) async {
    await _prefs?.setBool('isDarkMode', value);
    notifyListeners();
  }
  
  // === Currency ===
  String get defaultCurrency => _prefs?.getString('defaultCurrency') ?? 'INR';
  
  Future<void> setDefaultCurrency(String currency) async {
    await _prefs?.setString('defaultCurrency', currency);
    notifyListeners();
  }
  
  // === Language ===
  String get languageCode => _prefs?.getString('languageCode') ?? 'en';
  
  Future<void> setLanguageCode(String code) async {
    await _prefs?.setString('languageCode', code);
    notifyListeners();
  }
  
  // === Haptics ===
  bool get hapticFeedback => _prefs?.getBool('hapticFeedback') ?? true;
  
  Future<void> setHapticFeedback(bool value) async {
    await _prefs?.setBool('hapticFeedback', value);
    notifyListeners();
  }
  
  // === App Lock (Fingerprint/PIN) ===
  bool get appLockEnabled => _prefs?.getBool('appLockEnabled') ?? false;
  
  Future<void> setAppLockEnabled(bool value) async {
    await _prefs?.setBool('appLockEnabled', value);
    notifyListeners();
  }

  // === Last Backup Time ===
  String? get lastBackupTime => _prefs?.getString('lastBackupTime');

  Future<void> setLastBackupTime(String value) async {
    await _prefs?.setString('lastBackupTime', value);
    // Don't notify listeners to avoid triggering auto-backup loop
  }
  
  // === Entries ===
  List<Entry> get entries {
    final sorted = List<Entry>.from(_entries);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }
  
  Future<void> addEntry(Entry entry) async {
    _entries.add(entry);
    await _saveEntries();
    notifyListeners();
    _scheduleAutoBackup();
  }
  
  Future<void> updateEntry(Entry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      await _saveEntries();
      notifyListeners();
      _scheduleAutoBackup();
    }
  }
  
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _saveEntries();
    notifyListeners();
    _scheduleAutoBackup();
  }
  
  Future<void> clearAllEntries() async {
    _entries.clear();
    await _saveEntries();
    notifyListeners();
    _scheduleAutoBackup();
  }
  
  // === Customers ===
  List<Customer> get customers {
    final sorted = List<Customer>.from(_customers);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }
  
  Future<void> addCustomer(Customer customer) async {
    _customers.add(customer);
    await _saveCustomers();
    notifyListeners();
    _scheduleAutoBackup();
  }
  
  Future<void> updateCustomer(Customer customer) async {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer.copyWith(updatedAt: DateTime.now());
      await _saveCustomers();
      notifyListeners();
      _scheduleAutoBackup();
    }
  }
  
  Future<void> deleteCustomer(String id) async {
    _customers.removeWhere((c) => c.id == id);
    await _saveCustomers();
    notifyListeners();
    _scheduleAutoBackup();
  }
  
  Customer? getCustomer(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // === Bills ===
  List<Bill> get bills {
    final sorted = List<Bill>.from(_bills);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }
  
  String get nextBillNumber {
    return 'BILL-${(_bills.length + 1).toString().padLeft(4, '0')}';
  }
  
  Future<void> addBill(Bill bill) async {
    _bills.add(bill);
    await _saveBills();
    notifyListeners();
  }
  
  Future<void> updateBill(Bill bill) async {
    final index = _bills.indexWhere((b) => b.id == bill.id);
    if (index != -1) {
      _bills[index] = bill;
      await _saveBills();
      notifyListeners();
    }
  }
  
  Future<void> deleteBill(String id) async {
    _bills.removeWhere((b) => b.id == id);
    await _saveBills();
    notifyListeners();
  }
  
  // === Export/Backup ===
  static const String backupVersion = '1.1';

  /// Export all data as a versioned JSON-compatible map.
  /// Includes entries, customers, bills, qrHistory, settings, version, timestamp.
  Map<String, dynamic> exportAllData() {
    return {
      'schemaVersion': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': '3.10.0',
      'data': {
        'entries': _entries.map((e) => e.toJson()).toList(),
        'customers': _customers.map((c) => c.toJson()).toList(),
        'bills': _bills.map((b) => b.toJson()).toList(),
        'qrHistory': qrHistory,
        'settings': {
          'languageCode': languageCode,
          'defaultCurrency': defaultCurrency,
          'isDarkMode': isDarkMode,
          'hapticFeedback': hapticFeedback,
          'appLockEnabled': appLockEnabled,
        },
      },
    };
  }

  /// Import data from a backup map (with migration support).
  /// Returns true on success, false on failure.
  /// Does NOT notify listeners — caller should do that.
  Future<bool> importData(Map<String, dynamic> backup) async {
    try {
      // Handle both old format (no 'data' key) and new format
      Map<String, dynamic> data;
      String version;

      if (backup.containsKey('data') && backup['data'] is Map) {
        // New format (v1.0+)
        data = Map<String, dynamic>.from(backup['data'] as Map);
        version = backup['schemaVersion'] as String? ?? '1.0';
      } else {
        // Old format (pre v1.0 — direct entries/customers/bills)
        data = backup;
        version = '0.9';
      }

      // Migration: apply transformations based on version
      data = _migrateData(data, version);

      // Clear existing data
      _entries.clear();
      _customers.clear();
      _bills.clear();

      // Restore entries
      if (data.containsKey('entries') && data['entries'] is List) {
        final list = data['entries'] as List;
        _entries = list
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Restore customers
      if (data.containsKey('customers') && data['customers'] is List) {
        final list = data['customers'] as List;
        _customers = list
            .map((c) => Customer.fromJson(c as Map<String, dynamic>))
            .toList();
      }

      // Restore bills
      if (data.containsKey('bills') && data['bills'] is List) {
        final list = data['bills'] as List;
        _bills = list
            .map((b) => Bill.fromJson(b as Map<String, dynamic>))
            .toList();
      }

      // Restore QR history
      if (data.containsKey('qrHistory') && data['qrHistory'] is List) {
        final list = data['qrHistory'] as List;
        final qrList = list
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
        await _prefs?.setString('qrHistory', jsonEncode(qrList));
      }

      // Restore settings
      if (data.containsKey('settings') && data['settings'] is Map) {
        final s = Map<String, dynamic>.from(data['settings'] as Map);
        if (s.containsKey('languageCode')) {
          await _prefs?.setString('languageCode', s['languageCode'] as String);
        }
        if (s.containsKey('defaultCurrency')) {
          await _prefs?.setString('defaultCurrency', s['defaultCurrency'] as String);
        }
        if (s.containsKey('isDarkMode')) {
          await _prefs?.setBool('isDarkMode', s['isDarkMode'] as bool);
        }
        if (s.containsKey('hapticFeedback')) {
          await _prefs?.setBool('hapticFeedback', s['hapticFeedback'] as bool);
        }
        if (s.containsKey('appLockEnabled')) {
          await _prefs?.setBool('appLockEnabled', s['appLockEnabled'] as bool);
        }
      }

      // Save restored data
      await _saveEntries();
      await _saveCustomers();
      await _saveBills();

      return true;
    } catch (e) {
      debugPrint('Import failed: $e');
      return false;
    }
  }

  /// Migration logic — transform old data format to current format.
  /// Add cases as schema evolves.
  Map<String, dynamic> _migrateData(Map<String, dynamic> data, String fromVersion) {
    // Example migration for future versions:
    // if (fromVersion == '1.0') {
    //   // Add countryCode to customers
    //   for (var c in data['customers'] ?? []) {
    //     c['countryCode'] = c['countryCode'] ?? '91';
    //   }
    // }
    // For now, no migrations needed — current version is 1.1
    return data;
  }
  
  String exportEntriesAsCsv() {
    if (_entries.isEmpty) return '';
    
    final headers = ['id', 'date', 'type', 'amount', 'currency', 'customerName', 'notes', 'category'];
    final rows = <String>[];
    rows.add(headers.join(','));
    
    for (final entry in entries) {
      final row = [
        entry.id,
        entry.date.toIso8601String(),
        entry.type,
        entry.amount.toString(),
        entry.currency,
        entry.customerName ?? '',
        _escapeCsv(entry.notes ?? ''),
        _escapeCsv(entry.category ?? ''),
      ];
      rows.add(row.join(','));
    }
    
    return rows.join('\n');
  }
  
  String exportCustomersAsCsv() {
    if (_customers.isEmpty) return '';
    
    final headers = ['id', 'name', 'phone', 'email', 'address', 'totalCredit', 'totalDebit', 'balance', 'notes'];
    final rows = <String>[];
    rows.add(headers.join(','));
    
    for (final customer in customers) {
      final row = [
        customer.id,
        _escapeCsv(customer.name),
        customer.phone ?? '',
        customer.email ?? '',
        _escapeCsv(customer.address ?? ''),
        customer.totalCredit.toString(),
        customer.totalDebit.toString(),
        customer.balance.toString(),
        _escapeCsv(customer.notes ?? ''),
      ];
      rows.add(row.join(','));
    }
    
    return rows.join('\n');
  }
  
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
  
  Future<void> clearAllData() async {
    _entries.clear();
    _customers.clear();
    _bills.clear();
    await _saveEntries();
    await _saveCustomers();
    await _saveBills();
    notifyListeners();
    _scheduleAutoBackup();
  }

  // === Auto-Backup ===
  // Debounced auto-backup: coalesce multiple changes within 5 seconds
  // into a single backup file write.
  static Timer? _autoBackupTimer;

  void _scheduleAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer(const Duration(seconds: 5), () {
      _performAutoBackup();
    });
  }

  Future<void> _performAutoBackup() async {
    try {
      await BackupService.createLocalBackup(this);
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
    }
  }
}
