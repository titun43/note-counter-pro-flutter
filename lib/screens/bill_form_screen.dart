// =============================================================================
// Note Counter Pro - Bill Form Screen (Create / Edit)
// =============================================================================
// Full form for creating or editing a bill:
//   - Bill number (auto)
//   - Customer selection (existing or walk-in)
//   - Dynamic items list (add / edit / remove)
//   - Per-item: name, qty, price, GST%
//   - Discount %, due date, notes
//   - Real-time totals (subtotal, GST, discount, total)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mscanner;
import '../services/storage_service.dart';
import '../services/admob_service.dart';
import '../services/premium_service.dart';
import '../models/bill.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';
import 'premium_screen.dart';

class BillFormScreen extends StatefulWidget {
  /// Pass an existing bill to edit it; leave null to create new.
  final Bill? existingBill;

  const BillFormScreen({super.key, this.existingBill});

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  late String _billNumber;
  String? _customerId;
  String _customerName = '';
  String _customerPhone = '';
  final List<BillItem> _items = [];
  double _discountPercent = 0;
  DateTime? _dueDate;
  final _notesController = TextEditingController();

  bool get _isEditing => widget.existingBill != null;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    if (widget.existingBill != null) {
      final b = widget.existingBill!;
      _billNumber = b.billNumber;
      _customerId = b.customerId;
      _customerName = b.customerName ?? '';
      _customerPhone = b.customerPhone ?? '';
      _items.addAll(b.items.map((i) => BillItem(
            name: i.name,
            quantity: i.quantity,
            price: i.price,
            gstPercent: i.gstPercent,
          )));
      _discountPercent = b.discountPercent;
      _dueDate = b.dueDate;
      _notesController.text = b.notes ?? '';
    } else {
      _billNumber = storage.nextBillNumber;
      // Start with one empty item row
      _items.add(BillItem(name: '', quantity: 1, price: 0));
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0.0, (sum, i) => sum + i.subtotal);
  double get _totalGst =>
      _items.fold(0.0, (sum, i) => sum + i.gstAmount);
  double get _discountAmount =>
      (_subtotal + _totalGst) * _discountPercent / 100;
  double get _total => _subtotal + _totalGst - _discountAmount;

  bool get _canSave {
    if (_items.isEmpty) return false;
    // Every item must have name + price > 0
    for (final i in _items) {
      if (i.name.trim().isEmpty) return false;
      if (i.price <= 0) return false;
    }
    return true;
  }

  Future<void> _saveBill() async {
    if (!_canSave) return;
    final storage = context.read<StorageService>();
    final currency = storage.defaultCurrency;

    // Free-user bill limit check (only when creating new, not when editing).
    // Premium users have unlimited bills.
    if (!_isEditing) {
      final isPremium = PremiumService().isPremium;
      if (!isPremium && !storage.canCreateBillForFree) {
        if (mounted) {
          final loc = context.loc;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('billLimitReached')),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'PRO',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                },
              ),
            ),
          );
        }
        return;
      }
    }

    if (_isEditing) {
      final updated = widget.existingBill!.copyWith(
        customerId: _customerId,
        customerName: _customerName.isEmpty ? null : _customerName,
        customerPhone: _customerPhone.isEmpty ? null : _customerPhone,
        items: _items,
        discountPercent: _discountPercent,
        currency: currency,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        dueDate: _dueDate,
      );
      await storage.updateBill(updated);
      // For edited bills: we DO NOT auto-deduct stock again (the deduction
      // was already made when the bill was first created). Caller can use
      // the manual Stock Adjust screen if a correction is needed.
    } else {
      final bill = Bill.create(
        billNumber: _billNumber,
        customerId: _customerId,
        customerName: _customerName.isEmpty ? null : _customerName,
        customerPhone: _customerPhone.isEmpty ? null : _customerPhone,
        items: _items,
        discountPercent: _discountPercent,
        currency: currency,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        dueDate: _dueDate,
      );
      await storage.addBill(bill);
      // Stock auto-deduct — only for new bills. Existing bills (no productId
      // on items) are skipped (backward compatible). Oversell is allowed:
      // stock can go negative and a warning is shown in the inventory list.
      await storage.deductStockForBill(bill);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Bill $_billNumber updated'
              : 'Bill $_billNumber created'),
          backgroundColor: AppColors.success,
        ),
      );
      // Show interstitial after a bill is saved (natural break point).
      AdMobService.showInterstitial();
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickCustomer() async {
    final storage = context.read<StorageService>();
    final customers = storage.customers;
    if (customers.isEmpty) {
      // No customers yet — fall through to manual entry
      _showManualCustomerDialog();
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Customer',
                style: TextStyle(
                  fontFamily: 'KhataHandwriting',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.info),
              title: const Text('Walk-in Customer'),
              subtitle: const Text('No customer record needed'),
              onTap: () => Navigator.pop(ctx, {
                'id': null,
                'name': '',
                'phone': '',
              }),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: customers.length,
                itemBuilder: (ctx, i) {
                  final c = customers[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(c.name),
                    subtitle: c.phone != null && c.phone!.isNotEmpty
                        ? Text(c.phone!)
                        : null,
                    onTap: () => Navigator.pop(ctx, {
                      'id': c.id,
                      'name': c.name,
                      'phone': c.phone ?? '',
                    }),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showManualCustomerDialog();
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add New Customer Name'),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _customerId = selected['id'] as String?;
        _customerName = selected['name'] as String? ?? '';
        _customerPhone = selected['phone'] as String? ?? '';
      });
    }
  }

  Future<void> _showManualCustomerDialog() async {
    final nameCtl = TextEditingController(text: _customerName);
    final phoneCtl = TextEditingController(text: _customerPhone);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtl,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      setState(() {
        _customerId = null;
        _customerName = nameCtl.text.trim();
        _customerPhone = phoneCtl.text.trim();
      });
    }
    nameCtl.dispose();
    phoneCtl.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  /// Open barcode scanner → look up product → auto-add to bill.
  /// If same barcode already in bill → qty += 1.
  /// If not found → snackbar warning + manual item add.
  Future<void> _scanBarcodeToAdd() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _BillBarcodeScannerSheet(),
        fullscreenDialog: true,
      ),
    );
    if (scanned == null || scanned.isEmpty) return;

    final storage = context.read<StorageService>();
    final loc = context.loc;
    final product = storage.findByBarcode(scanned);

    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('productNotFound')),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Same barcode already in bill? → qty++
    final existingIndex = _items.indexWhere((i) => i.productId == product.id);
    if (existingIndex != -1) {
      setState(() {
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity + 1,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('sameBarcodeQtyPlus')),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      // Add new item with product info
      setState(() {
        _items.add(BillItem(
          name: product.name,
          quantity: 1,
          price: product.salePrice,
          gstPercent: product.gstPercent,
          productId: product.id,
          barcode: product.barcode,
        ));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} ✓'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final symbol = AppConstants.getCurrencySymbol(
        context.read<StorageService>().defaultCurrency);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Bill' : 'Create Bill',
          style: const TextStyle(fontFamily: 'KhataHandwriting', fontSize: 22),
        ),
        actions: [
          TextButton.icon(
            onPressed: _canSave ? _saveBill : null,
            icon: const Icon(Icons.check, size: 20),
            label: Text(loc.t('save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === Bill number + date ===
          _sectionCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.receipt, color: AppColors.primary),
                title: Text(loc.t('billNumber')),
                subtitle: Text(_billNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          // === Customer ===
          _sectionCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppColors.info),
                title: Text(loc.t('customer')),
                subtitle: Text(
                  _customerName.isEmpty
                      ? 'Walk-in Customer'
                      : _customerName +
                          (_customerPhone.isNotEmpty
                              ? ' · $_customerPhone'
                              : ''),
                  style: TextStyle(
                    fontStyle: _customerName.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: _customerName.isEmpty
                        ? AppColors.textSecondary
                        : null,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickCustomer,
              ),
            ],
          ),

          // === Items ===
          // Scan-to-add card (gold dashed border, prominent camera button)
          GestureDetector(
            onTap: _scanBarcodeToAdd,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF16213E), const Color(0xFF2A2418)]
                      : [Colors.white, const Color(0xFFFFF7ED)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    loc.t('scanToAddProduct'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.t('scanToAddDesc'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          _sectionCard(
            isDark: isDark,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      loc.t('items'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'KhataHandwriting',
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _items.add(BillItem(name: '', quantity: 1, price: 0));
                      }),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(loc.t('addItem')),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ..._items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return _itemRow(i, item, isDark, symbol);
              }),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    loc.t('noItemsAdded'),
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),

          // Stock-deduction info banner (only if any item has a productId)
          if (_items.any((i) => i.productId != null && i.productId!.isNotEmpty))
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.t('stockWillDeduct'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // === Discount / Due date / Notes ===
          _sectionCard(
            isDark: isDark,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.discount_outlined, color: AppColors.warning),
                title: Text(loc.t('discount')),
                trailing: SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(
                        text: _discountPercent == 0
                            ? ''
                            : _discountPercent.toStringAsFixed(0)),
                    onChanged: (v) {
                      final d = double.tryParse(v);
                      setState(() => _discountPercent = d ?? 0);
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.event_outlined, color: AppColors.info),
                title: Text(loc.t('dueDate')),
                subtitle: _dueDate == null
                    ? Text(loc.t('noDueDate'),
                        style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary))
                    : Text(
                        '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _dueDate = null),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: _pickDueDate,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.note_outlined,
                    color: AppColors.textSecondary),
                title: Text(loc.t('notes')),
                subtitle: TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    hintText: loc.t('notesHint'),
                    border: InputBorder.none,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),

          // === Totals ===
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF16213E), const Color(0xFF1A1A2E)]
                    : [const Color(0xFFFFF8DC), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                _totalRow('Subtotal', '$symbol${_subtotal.toStringAsFixed(2)}'),
                if (_totalGst > 0)
                  _totalRow(
                      'GST', '$symbol${_totalGst.toStringAsFixed(2)}'),
                if (_discountPercent > 0)
                  _totalRow('Discount (${_discountPercent.toStringAsFixed(0)}%)',
                      '-$symbol${_discountAmount.toStringAsFixed(2)}'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.t('total'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('$symbol${_total.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: AppColors.danger)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _itemRow(int i, BillItem item, bool isDark, String symbol) {
    return Dismissible(
      key: ValueKey('item-$i-${item.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => setState(() => _items.removeAt(i)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Text('${i + 1}.',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Item name *',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.name),
                    onChanged: (v) => item.name = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller:
                        TextEditingController(text: item.quantity.toString()),
                    onChanged: (v) =>
                        item.quantity = int.tryParse(v) ?? 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixText: symbol,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    controller:
                        TextEditingController(text: item.price.toStringAsFixed(0)),
                    onChanged: (v) =>
                        item.price = double.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'GST %',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(
                        text: item.gstPercent == null
                            ? ''
                            : item.gstPercent!.toStringAsFixed(0)),
                    onChanged: (v) =>
                        item.gstPercent = double.tryParse(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Amount: $symbol${item.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ],
            ),
            if (i < _items.length - 1) const Divider(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _totalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// =============================================================================
// Bill Barcode Scanner Sheet — opens camera, returns scanned barcode string.
// Reuses mobile_scanner (same package as Smart Pay / QR scanner).
// =============================================================================

class _BillBarcodeScannerSheet extends StatefulWidget {
  const _BillBarcodeScannerSheet();

  @override
  State<_BillBarcodeScannerSheet> createState() => _BillBarcodeScannerSheetState();
}

class _BillBarcodeScannerSheetState extends State<_BillBarcodeScannerSheet> {
  final mscanner.MobileScannerController _controller = mscanner.MobileScannerController(
    detectionSpeed: mscanner.DetectionSpeed.noDuplicates,
    facing: mscanner.CameraFacing.back,
    autoStart: true,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: mscanner.MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (capture.barcodes.isEmpty) return;
          final raw = capture.barcodes.first.rawValue;
          if (raw != null && raw.isNotEmpty) {
            _controller.stop();
            Navigator.pop(context, raw);
          }
        },
      ),
    );
  }
}
