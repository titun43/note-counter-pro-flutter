import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/product.dart';
import 'backup_service.dart';

class StorageService extends ChangeNotifier {
  final SharedPreferences? _prefs;
  
  List<Entry> _entries = [];
  List<Customer> _customers = [];
  List<Bill> _bills = [];
  List<Product> _products = [];
  
  StorageService(this._prefs) {
    // Initialize the theme notifier with the persisted value so the
    // very first frame uses the correct theme without waiting for
    // _loadData() to complete.
    themeNotifier = ValueNotifier<bool>(isDarkMode);
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
      
      // Load products (inventory)
      final productsJson = _prefs!.getString('products');
      if (productsJson != null) {
        final list = jsonDecode(productsJson) as List;
        _products = list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
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
  
  Future<void> _saveProducts() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setString('products', jsonEncode(_products.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Save products failed: $e');
    }
  }
  
  // === Theme ===
  // We expose dark-mode via a dedicated ValueNotifier so that theme
  // changes don't trigger a full StorageService.notifyListeners() call
  // (which would rebuild every screen that uses context.watch<StorageService>
  // and cause visible UI flashing). Only widgets that subscribe to
  // themeNotifier rebuild on theme change.
  late final ValueNotifier<bool> themeNotifier;

  bool get isDarkMode => _prefs?.getBool('isDarkMode') ?? false;

  Future<void> setDarkMode(bool value) async {
    await _prefs?.setBool('isDarkMode', value);
    // Only notify theme subscribers — do NOT call notifyListeners() here.
    // This is the fix for the dark-mode flashing issue: the previous
    // notifyListeners() call caused every screen using
    // context.watch<StorageService> to rebuild, reloading BannerAdWidgets
    // and producing a visible flash.
    themeNotifier.value = value;
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

  // === Last Cloud Backup Time (Google Drive) ===
  String? get lastCloudBackupTime =>
      _prefs?.getString('lastCloudBackupTime');

  Future<void> setLastCloudBackup(DateTime time) async {
    await _prefs?.setString(
        'lastCloudBackupTime', time.toIso8601String());
  }

  // === Business Details ===
  String get businessName => _prefs?.getString('businessName') ?? '';
  String get businessOwner => _prefs?.getString('businessOwner') ?? '';
  String get businessPhone => _prefs?.getString('businessPhone') ?? '';
  String get businessAddress => _prefs?.getString('businessAddress') ?? '';
  String get businessUpiId => _prefs?.getString('businessUpiId') ?? '';

  Future<void> setBusinessDetails({
    String? name,
    String? owner,
    String? phone,
    String? address,
    String? upiId,
  }) async {
    if (name != null) await _prefs?.setString('businessName', name);
    if (owner != null) await _prefs?.setString('businessOwner', owner);
    if (phone != null) await _prefs?.setString('businessPhone', phone);
    if (address != null) await _prefs?.setString('businessAddress', address);
    if (upiId != null) await _prefs?.setString('businessUpiId', upiId);
    notifyListeners();
  }

  bool get hasBusinessDetails {
    return businessName.isNotEmpty ||
        businessOwner.isNotEmpty ||
        businessPhone.isNotEmpty ||
        businessAddress.isNotEmpty ||
        businessUpiId.isNotEmpty;
  }

  // === REMINDER SETTINGS (v3.15.0) ===
  // Default reminder template: friendly / formal / strict
  String get defaultReminderTemplate =>
      _prefs?.getString('default_reminder_template') ?? 'friendly';

  Future<void> setDefaultReminderTemplate(String template) async {
    await _prefs?.setString('default_reminder_template', template);
    notifyListeners();
  }

  // Reminder schedule
  bool get reminderEnabled => _prefs?.getBool('reminder_enabled') ?? false;

  Future<void> setReminderEnabled(bool value) async {
    await _prefs?.setBool('reminder_enabled', value);
    notifyListeners();
  }

  // Frequency: 'daily', 'weekly', 'monthly'
  String get reminderFrequency =>
      _prefs?.getString('reminder_frequency') ?? 'weekly';

  Future<void> setReminderFrequency(String value) async {
    await _prefs?.setString('reminder_frequency', value);
    notifyListeners();
  }

  // Day of week (1=Monday ... 7=Sunday) for weekly, day of month (1-28) for monthly
  int get reminderDay => _prefs?.getInt('reminder_day') ?? 6; // default Saturday

  Future<void> setReminderDay(int value) async {
    await _prefs?.setInt('reminder_day', value);
    notifyListeners();
  }

  // Hour of day (0-23)
  int get reminderHour => _prefs?.getInt('reminder_hour') ?? 10;

  Future<void> setReminderHour(int value) async {
    await _prefs?.setInt('reminder_hour', value);
    notifyListeners();
  }

  // Minute (0-59)
  int get reminderMinute => _prefs?.getInt('reminder_minute') ?? 0;

  Future<void> setReminderMinute(int value) async {
    await _prefs?.setInt('reminder_minute', value);
    notifyListeners();
  }

  // Only send to pending customers (balance != 0)
  bool get reminderPendingOnly =>
      _prefs?.getBool('reminder_pending_only') ?? true;

  Future<void> setReminderPendingOnly(bool value) async {
    await _prefs?.setBool('reminder_pending_only', value);
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
    // Use max existing bill number + 1 so that deleting a bill doesn't
    // cause duplicate numbers when creating a new one.
    int maxNum = 0;
    for (final b in _bills) {
      // Try to parse the trailing 4-digit number from 'BILL-XXXX'
      final match = RegExp(r'BILL-(\d+)').firstMatch(b.billNumber);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return 'BILL-${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  /// Free-user limit: 5 bills max. Premium = unlimited.
  /// Caller must also check PremiumService().isPremium — this getter is
  /// the defensive hard cap.
  static const int freeBillLimit = 5;

  /// True if a free user can still create a new bill (or any premium user).
  /// PremiumService is checked by the caller — this getter is the
  /// defensive hard cap that only counts bills, regardless of premium.
  bool get canCreateBillForFree {
    return _bills.length < freeBillLimit;
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
    // Find the bill before removing so we can revert stock + Khata entry.
    final bill = _bills.where((b) => b.id == id).firstOrNull;
    // Revert stock deduction (adds back the quantity of each linked item).
    if (bill != null) {
      await revertStockForBill(bill);
      // Delete the linked Khata entry (cascade) and adjust customer totals.
      await deleteLinkedKhataEntry(bill);
    }
    _bills.removeWhere((b) => b.id == id);
    await _saveBills();
    notifyListeners();
  }

  // === Bill ↔ Khata linkage (partial payment auto-entry) ===

  /// Create a Khata Entry for the remaining (unpaid) balance of a bill.
  /// The entry is linked to the bill via linkedBillId so it can be
  /// automatically deleted if the bill is deleted. The entry type is
  /// 'cash_in' (customer will pay us later) and category 'receivable'
  /// (we will receive this money).
  Future<void> createLinkedKhataEntry(Bill bill) async {
    if (bill.customerId == null || bill.customerId!.isEmpty) return;
    final remaining = bill.remainingAmount;
    if (remaining <= 0) return;
    final entry = Entry.create(
      type: 'cash_in',
      amount: remaining,
      currency: bill.currency,
      customerId: bill.customerId,
      customerName: bill.customerName,
      notes: 'Bill ${bill.billNumber} - remaining balance',
      category: 'receivable',
      linkedBillId: bill.id,
    );
    _entries.add(entry);
    await _saveEntries();
    notifyListeners();
  }

  /// Sync the linked Khata entry when a bill is edited. Deletes the old
  /// linked entry (if any) and creates a new one if there's still a
  /// remaining balance. Called by BillFormScreen._saveBill on edit.
  Future<void> syncLinkedKhataEntry(Bill bill) async {
    // Remove any existing linked entry for this bill.
    final hadLinked = _entries.any((e) => e.linkedBillId == bill.id);
    _entries.removeWhere((e) => e.linkedBillId == bill.id);
    // Create a new one if there's still a remaining balance AND a customer.
    if (bill.customerId != null &&
        bill.customerId!.isNotEmpty &&
        bill.remainingAmount > 0) {
      final entry = Entry.create(
        type: 'cash_in',
        amount: bill.remainingAmount,
        currency: bill.currency,
        customerId: bill.customerId,
        customerName: bill.customerName,
        notes: 'Bill ${bill.billNumber} - remaining balance',
        category: 'receivable',
        linkedBillId: bill.id,
      );
      _entries.add(entry);
    }
    if (hadLinked || bill.remainingAmount > 0) {
      await _saveEntries();
      notifyListeners();
    }
  }

  /// Delete the linked Khata entry for a bill (cascade delete) and adjust
  /// the customer's totalDebit so their balance stays correct.
  Future<void> deleteLinkedKhataEntry(Bill bill) async {
    if (bill.customerId == null || bill.customerId!.isEmpty) return;
    final linked = _entries.where((e) => e.linkedBillId == bill.id).toList();
    if (linked.isEmpty) return;
    // Subtract the linked entry amounts from the customer's totalDebit
    // (since these were debit entries representing money owed to us).
    final totalLinked = linked.fold(0.0, (s, e) => s + e.amount);
    _entries.removeWhere((e) => e.linkedBillId == bill.id);
    await _saveEntries();
    // Adjust customer debit back down.
    await adjustCustomerDebit(bill.customerId!, -totalLinked);
  }

  /// Adjust a customer's totalDebit by a signed delta. Positive = customer
  /// owes more, negative = customer owes less. Used by BillFormScreen
  /// when partial payments change the remaining balance.
  Future<void> adjustCustomerDebit(String customerId, double delta) async {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index == -1) return;
    final c = _customers[index];
    final newDebit = (c.totalDebit + delta).clamp(0.0, double.infinity).toDouble();
    _customers[index] = c.copyWith(
      totalDebit: newDebit,
      updatedAt: DateTime.now(),
    );
    await _saveCustomers();
    notifyListeners();
  }

  /// Mark a bill as paid (sets isPaid=true, paidAt=now by default).
  Future<void> markBillPaid(String id, [DateTime? when]) async {
    final index = _bills.indexWhere((b) => b.id == id);
    if (index != -1) {
      _bills[index].markPaid(when);
      await _saveBills();
      notifyListeners();
    }
  }

  /// Revert a bill to unpaid status.
  Future<void> markBillUnpaid(String id) async {
    final index = _bills.indexWhere((b) => b.id == id);
    if (index != -1) {
      _bills[index].markUnpaid();
      await _saveBills();
      notifyListeners();
    }
  }

  /// Auto-deduct stock for products linked to bill items.
  /// Called after a new bill is saved (only for items with productId).
  /// Existing bills without productId are skipped (backward compatible).
  Future<void> deductStockForBill(Bill bill) async {
    bool changed = false;
    for (final item in bill.items) {
      if (item.productId == null || item.productId!.isEmpty) continue;
      final pIndex = _products.indexWhere((p) => p.id == item.productId);
      if (pIndex == -1) continue;
      // Allow oversell — stock can go negative (warning shown in UI).
      _products[pIndex] = _products[pIndex].copyWith(
        stock: _products[pIndex].stock - item.quantity,
        updatedAt: DateTime.now(),
      );
      changed = true;
    }
    if (changed) {
      await _saveProducts();
      notifyListeners();
    }
  }

  /// Revert stock deduction when a bill is deleted.
  /// Adds back the quantity of each linked item to its product.
  Future<void> revertStockForBill(Bill bill) async {
    bool changed = false;
    for (final item in bill.items) {
      if (item.productId == null || item.productId!.isEmpty) continue;
      final pIndex = _products.indexWhere((p) => p.id == item.productId);
      if (pIndex == -1) continue;
      _products[pIndex] = _products[pIndex].copyWith(
        stock: _products[pIndex].stock + item.quantity,
        updatedAt: DateTime.now(),
      );
      changed = true;
    }
    if (changed) {
      await _saveProducts();
      notifyListeners();
    }
  }

  // === Products (Inventory) ===
  List<Product> get products {
    final sorted = List<Product>.from(_products);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// Free-user limit: 5 products max. Premium = unlimited.
  static const int freeProductLimit = 5;
  bool get canAddProduct {
    // Import injected lazily to avoid circular import in the lib layer.
    // We rely on the calling screen to check PremiumService — but as a
    // safety net, also enforce the hard cap here.
    return _products.length < freeProductLimit;
  }

  Future<bool> addProduct(Product product) async {
    // Hard cap (free-user limit). PremiumService is checked by the
    // caller before reaching here; this is a defensive check.
    if (_products.length >= freeProductLimit) return false;
    _products.add(product);
    await _saveProducts();
    notifyListeners();
    return true;
  }

  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product.copyWith(updatedAt: DateTime.now());
      await _saveProducts();
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    await _saveProducts();
    notifyListeners();
  }

  /// Find product by barcode (returns first match — duplicates allowed).
  Product? findByBarcode(String code) {
    if (code.isEmpty) return null;
    try {
      return _products.firstWhere((p) => p.barcode == code);
    } catch (_) {
      return null;
    }
  }

  /// Find product by id.
  Product? getProduct(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Adjust stock for a product by a signed delta (positive = stock in,
  /// negative = stock out). Used by StockAdjustScreen.
  Future<void> adjustStock(String productId, int delta) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(
        stock: _products[index].stock + delta,
        updatedAt: DateTime.now(),
      );
      await _saveProducts();
      notifyListeners();
    }
  }

  /// Set absolute stock value (manual recount).
  Future<void> setStock(String productId, int newStock) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(
        stock: newStock,
        updatedAt: DateTime.now(),
      );
      await _saveProducts();
      notifyListeners();
    }
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
    // Unlimited history — no 10-item limit (v3.31.0)
    await _prefs?.setString('qrHistory', jsonEncode(history));
    notifyListeners();
  }

  /// Smart save: if UPI ID already exists in history, update existing entry;
  /// otherwise add new entry at top. Unlimited history.
  /// Used by Smart Pay Generate QR screen.
  Future<void> addQrHistorySmart(Map<String, String> qr) async {
    final history = qrHistory;
    final upiId = qr['upiId'] ?? '';

    // Check if UPI ID already exists
    final existingIndex = history.indexWhere(
      (e) => (e['upiId'] ?? '') == upiId,
    );

    if (existingIndex != -1) {
      // Update existing entry (move to top with new data)
      history.removeAt(existingIndex);
      history.insert(0, qr);
    } else {
      // Add new entry at top
      history.insert(0, qr);
    }

    // Unlimited history — no limit
    await _prefs?.setString('qrHistory', jsonEncode(history));
    notifyListeners();
  }

  /// Delete a QR history item by index
  Future<void> deleteQrHistory(int index) async {
    final history = qrHistory;
    if (index >= 0 && index < history.length) {
      history.removeAt(index);
      await _prefs?.setString('qrHistory', jsonEncode(history));
      notifyListeners();
    }
  }

  /// Clear all QR history
  // === SCAN HISTORY (Universal QR/Barcode Scanner) ===
  List<Map<String, String>> get scanHistory {
    final json = _prefs?.getString("scanHistory");
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) { return []; }
  }
  Future<void> addScanHistory(Map<String, String> scan) async {
    final history = scanHistory;
    history.insert(0, scan);
    await _prefs?.setString("scanHistory", jsonEncode(history));
    notifyListeners();
  }
  Future<void> deleteScanHistory(int index) async {
    final history = scanHistory;
    if (index >= 0 && index < history.length) {
      history.removeAt(index);
      await _prefs?.setString("scanHistory", jsonEncode(history));
      notifyListeners();
    }
  }
  // === UPI SCAN HISTORY (Smart Pay — separate from Counter QR history) ===
  List<Map<String, String>> get upiScanHistory {
    final json = _prefs?.getString("upiScanHistory");
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) { return []; }
  }
  Future<void> addUpiScanHistory(Map<String, String> scan) async {
    final history = upiScanHistory;
    history.insert(0, scan);
    await _prefs?.setString("upiScanHistory", jsonEncode(history));
    notifyListeners();
  }
  Future<void> deleteUpiScanHistory(int index) async {
    final history = upiScanHistory;
    if (index >= 0 && index < history.length) {
      history.removeAt(index);
      await _prefs?.setString("upiScanHistory", jsonEncode(history));
      notifyListeners();
    }
  }

  Future<void> clearScanHistory() async {
    await _prefs?.remove("scanHistory");
    notifyListeners();
  }

  Future<void> clearQrHistory() async {
    await _prefs?.remove('qrHistory');
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
    // Clear QR history too
    await _prefs?.remove('qrHistory');
    // Clear last backup time
    await _prefs?.remove('lastBackupTime');
    notifyListeners();
    _scheduleAutoBackup();
  }

  /// Public trigger for UI refresh after an external data mutation
  /// (e.g. after BackupService.restoreFromFile or restoreFromLocalBackup).
  /// Without this, the UI would not know that the data changed and would
  /// show stale state until the next user action.
  void triggerRefresh() {
    notifyListeners();
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

  /// Dispose the themeNotifier to prevent memory leaks.
  /// Called when the StorageService is no longer needed (app shutdown).
  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    themeNotifier.dispose();
    super.dispose();
  }
}
