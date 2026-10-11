import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';
import '../models/customer.dart';
import '../models/bill.dart';

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
  
  // === QR History ===
  List<Map<String, String>> get qrHistory {
    final json = _prefs?.getString('qrHistory');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }
  
  Future<void> addQrHistory(Map<String, String> qr) async {
    final history = qrHistory;
    history.insert(0, qr);
    if (history.length > 10) history.removeLast();
    await _prefs?.setString('qrHistory', jsonEncode(history));
    notifyListeners();
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
  }
  
  Future<void> updateEntry(Entry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      await _saveEntries();
      notifyListeners();
    }
  }
  
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _saveEntries();
    notifyListeners();
  }
  
  Future<void> clearAllEntries() async {
    _entries.clear();
    await _saveEntries();
    notifyListeners();
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
  }
  
  Future<void> updateCustomer(Customer customer) async {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer.copyWith(updatedAt: DateTime.now());
      await _saveCustomers();
      notifyListeners();
    }
  }
  
  Future<void> deleteCustomer(String id) async {
    _customers.removeWhere((c) => c.id == id);
    await _saveCustomers();
    notifyListeners();
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
  Map<String, dynamic> exportAllData() {
    return {
      'entries': _entries.map((e) => e.toJson()).toList(),
      'customers': _customers.map((c) => c.toJson()).toList(),
      'bills': _bills.map((b) => b.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '3.0.0',
    };
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
  }
}
