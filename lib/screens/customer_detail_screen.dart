import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../services/admob_service.dart';
import '../models/customer.dart';
import '../models/entry.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final int? pageNo;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    this.pageNo,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _customer = context.read<StorageService>().getCustomer(widget.customerId);
      });
    });
  }

  List<Entry> get _customerEntries {
    final storage = context.read<StorageService>();
    final entries = storage.entries
        .where((e) => e.customerId == widget.customerId)
        .toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> _addTransaction(bool isCredit) async {
    final loc = context.loc;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isCredit ? loc.t('addCredit') : loc.t('addDebit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: '${loc.t('amount')} *',
                  prefixText: '₹ ',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: loc.t('description'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Date picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.t('cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (amountController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: Text(loc.t('save')),
            ),
          ],
        ),
      ),
    );

    if (result == true && _customer != null) {
      final amount = double.parse(amountController.text.trim());
      final storage = context.read<StorageService>();

      if (isCredit) {
        _customer!.totalCredit += amount;
      } else {
        _customer!.totalDebit += amount;
      }

      await storage.updateCustomer(_customer!);

      final entry = Entry.create(
        type: isCredit ? 'cash_out' : 'cash_in',
        amount: amount,
        currency: storage.defaultCurrency,
        customerId: _customer!.id,
        customerName: _customer!.name,
        notes: notesController.text.trim(),
        category: isCredit ? 'credit' : 'debit',
      );
      // Override date with selected date
      final entryWithDate = Entry(
        id: entry.id,
        date: selectedDate,
        type: entry.type,
        amount: entry.amount,
        currency: entry.currency,
        customerId: entry.customerId,
        customerName: entry.customerName,
        notes: entry.notes,
        denominationCounts: entry.denominationCounts,
        category: entry.category,
        createdAt: entry.createdAt,
      );
      await storage.addEntry(entryWithDate);

      // Show interstitial after a new entry is saved (natural break point).
      // The 60-second cooldown + per-session/per-day caps in AdMobService
      // ensure we don't violate AdMob policy.
      AdMobService.showInterstitial();

      setState(() {
        _customer = storage.getCustomer(widget.customerId);
      });
    }

    amountController.dispose();
    notesController.dispose();
  }

  Future<void> _showEntryOptions(Entry entry) async {
    final loc = context.loc;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${entry.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share, color: AppColors.info),
              title: Text(loc.t('share')),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.info),
              title: Text(loc.t('edit')),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.danger),
              title: Text(loc.t('delete')),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (action == 'edit') {
      await _editEntry(entry);
    } else if (action == 'delete') {
      await _deleteEntry(entry);
    } else if (action == 'share') {
      _shareEntry(entry);
    }
  }

  Future<void> _editEntry(Entry entry) async {
    final loc = context.loc;
    final amountController = TextEditingController(text: entry.amount.toString());
    final notesController = TextEditingController(text: entry.notes ?? '');
    final isCredit = entry.category == 'credit';
    DateTime selectedDate = entry.date;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: AppColors.info),
              const SizedBox(width: 8),
              Text(loc.t('edit')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCredit ? loc.t('amountGiven') : loc.t('amountTaken'),
                style: TextStyle(
                  color: isCredit ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: '${loc.t('amount')} *',
                  prefixText: '₹ ',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: loc.t('description'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.t('cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (amountController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: Text(loc.t('save')),
            ),
          ],
        ),
      ),
    );

    if (result == true && _customer != null) {
      final newAmount = double.parse(amountController.text.trim());
      final oldAmount = entry.amount;
      final storage = context.read<StorageService>();

      if (isCredit) {
        _customer!.totalCredit = _customer!.totalCredit - oldAmount + newAmount;
      } else {
        _customer!.totalDebit = _customer!.totalDebit - oldAmount + newAmount;
      }
      await storage.updateCustomer(_customer!);

      final updatedEntry = Entry(
        id: entry.id,
        date: selectedDate,
        type: entry.type,
        amount: newAmount,
        currency: entry.currency,
        customerId: entry.customerId,
        customerName: entry.customerName,
        notes: notesController.text.trim(),
        denominationCounts: entry.denominationCounts,
        category: entry.category,
        createdAt: entry.createdAt,
      );
      await storage.updateEntry(updatedEntry);

      setState(() {
        _customer = storage.getCustomer(widget.customerId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }

    amountController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteEntry(Entry entry) async {
    final loc = context.loc;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(loc.t('delete')),
          ],
        ),
        content: Text('${loc.t('delete')} ₹${entry.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.t('delete')),
          ),
        ],
      ),
    );

    if (result == true && _customer != null) {
      final storage = context.read<StorageService>();
      final isCredit = entry.category == 'credit';

      if (isCredit) {
        _customer!.totalCredit -= entry.amount;
      } else {
        _customer!.totalDebit -= entry.amount;
      }
      await storage.updateCustomer(_customer!);

      await storage.deleteEntry(entry.id);

      setState(() {
        _customer = storage.getCustomer(widget.customerId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Share individual entry as text
  void _shareEntry(Entry entry) {
    final isCredit = entry.category == 'credit';
    final symbol = AppConstants.getCurrencySymbol(entry.currency);

    final text = StringBuffer();
    text.writeln('═══════════════════════');
    text.writeln('   ${isCredit ? "CREDIT (Given)" : "DEBIT (Taken)"}');
    text.writeln('═══════════════════════');
    text.writeln('Customer: ${_customer?.name ?? ""}');
    text.writeln('Date: ${entry.date.day}/${entry.date.month}/${entry.date.year}');
    text.writeln('Amount: $symbol ${entry.amount.toStringAsFixed(2)}');
    if (entry.notes != null && entry.notes!.isNotEmpty) {
      text.writeln('Description: ${entry.notes}');
    }
    text.writeln('───────────────────────');
    text.writeln('Note Counter Pro');

    Share.share(text.toString(), subject: 'Transaction - $symbol${entry.amount.toStringAsFixed(2)}');
  }

  /// Share entire customer page as image (not text)
  void _sharePage() async {
    if (_customer == null) return;

    // Show a dialog with the shareable receipt, then capture it
    final storage = context.read<StorageService>();
    final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);
    final entries = _customerEntries;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final balance = _customer!.balance;

    // Build a shareable receipt widget
    Widget receiptWidget = _buildShareableReceipt(
      storage, symbol, entries, theme, isDark, balance,
    );

    // Show in an offscreen overlay, capture, then share
    final Uint8List? imageBytes = await _captureWidget(receiptWidget);

    if (imageBytes != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final now = DateTime.now();
        final filename = 'khata-${_customer!.name}-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.png';
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Khata - ${_customer!.name}',
        );
      } catch (e) {
        // Fallback to text share
        _sharePageAsText(symbol, entries, balance);
      }
    } else {
      // Fallback to text share
      _sharePageAsText(symbol, entries, balance);
    }
  }

  /// Capture a widget as image using ScreenshotController
  Future<Uint8List?> _captureWidget(Widget widget) async {
    try {
      // Use a temporary ScreenshotController
      final controller = ScreenshotController();
      // Build the widget in an overlay
      final overlay = Overlay.of(context);
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (context) => Positioned(
          left: -1000,
          top: -1000,
          child: Material(
            type: MaterialType.transparency,
            child: Screenshot(
              controller: controller,
              child: widget,
            ),
          ),
        ),
      );

      overlay.insert(entry);

      // Wait for the widget to render
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await controller.capture();
      entry.remove();
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Build a shareable receipt widget for screenshot capture
  Widget _buildShareableReceipt(
    StorageService storage,
    String symbol,
    List<Entry> entries,
    ThemeData theme,
    bool isDark,
    double balance,
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 350,
        color: isDark ? AppColors.bgCardDark : Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    storage.businessName.isNotEmpty
                        ? storage.businessName
                        : (storage.businessOwner.isNotEmpty ? storage.businessOwner : 'Note Counter Pro'),
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'বাহি খাতা — Customer Statement',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Customer info
            Text(
              'Customer: ${_customer!.name}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            if (_customer!.phone != null && _customer!.phone!.isNotEmpty)
              Text('Phone: ${_customer!.phone}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[700])),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            // Balance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: balance > 0
                    ? Colors.red.withOpacity(0.1)
                    : (balance < 0 ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: balance > 0 ? Colors.red : (balance < 0 ? Colors.green : Colors.grey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Balance:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  Text(
                    '$symbol ${balance.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: balance > 0 ? Colors.red : (balance < 0 ? Colors.green : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Transactions header
            Text('Transactions (${entries.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            const Divider(),
            // Table header
            Row(
              children: [
                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[700]))),
                Expanded(flex: 3, child: Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[700]))),
                Expanded(flex: 2, child: Text('Took', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.end)),
                Expanded(flex: 2, child: Text('Gave', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red), textAlign: TextAlign.end)),
              ],
            ),
            const Divider(),
            // Transaction rows
            ...entries.map((e) {
              final isCredit = e.category == 'credit';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('${e.date.day}/${e.date.month}/${e.date.year}', style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.grey[600]))),
                    Expanded(flex: 3, child: Text(e.notes ?? (isCredit ? 'Given' : 'Taken'), style: TextStyle(fontSize: 10, color: isDark ? Colors.white : Colors.black87))),
                    Expanded(flex: 2, child: Text(!isCredit ? '$symbol${e.amount.toStringAsFixed(0)}' : '', textAlign: TextAlign.end, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green))),
                    Expanded(flex: 2, child: Text(isCredit ? '$symbol${e.amount.toStringAsFixed(0)}' : '', textAlign: TextAlign.end, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red))),
                  ],
                ),
              );
            }),
            const Divider(),
            // Totals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                Row(
                  children: [
                    Text('$symbol${_customer!.totalDebit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(width: 8),
                    Text('$symbol${_customer!.totalCredit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Footer
            Center(
              child: Text(
                'Generated by Note Counter Pro on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback: share as text
  void _sharePageAsText(String symbol, List<Entry> entries, double balance) {
    final text = StringBuffer();
    text.writeln('═══════════════════════════════');
    text.writeln('         বাহি খাতা');
    text.writeln('═══════════════════════════════');
    text.writeln('Customer: ${_customer!.name}');
    if (_customer!.phone != null && _customer!.phone!.isNotEmpty) {
      text.writeln('Phone: ${_customer!.phone}');
    }
    text.writeln('───────────────────────────────');
    text.writeln('Date       | Description      | Took    | Gave');
    text.writeln('───────────────────────────────');
    for (final e in entries) {
      final dateStr = '${e.date.day}/${e.date.month}/${e.date.year}';
      final desc = e.notes ?? '';
      final took = e.category == 'debit' ? '$symbol${e.amount.toStringAsFixed(2)}' : '';
      final gave = e.category == 'credit' ? '$symbol${e.amount.toStringAsFixed(2)}' : '';
      text.writeln('$dateStr | ${desc.padRight(15)} | ${took.padRight(7)} | $gave');
    }
    text.writeln('═══════════════════════════════');
    if (balance > 0) {
      text.writeln('BALANCE: $symbol ${balance.abs().toStringAsFixed(2)} (To Give)');
    } else if (balance < 0) {
      text.writeln('BALANCE: $symbol ${balance.abs().toStringAsFixed(2)} (To Take)');
    } else {
      text.writeln('BALANCE: $symbol 0.00 (Settled)');
    }
    text.writeln('═══════════════════════════════');
    text.writeln('Generated by Note Counter Pro');

    Share.share(text.toString(), subject: 'Khata - ${_customer!.name}');
  }

  /// Call customer
  Future<void> _callCustomer() async {
    if (_customer?.phone == null || _customer!.phone!.isEmpty) return;
    final cleanPhone = _customer!.phone!.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Send WhatsApp reminder
  Future<void> _sendWhatsAppReminder() async {
    if (_customer?.phone == null || _customer!.phone!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.t('noPhone'))),
        );
      }
      return;
    }
    final loc = context.loc;
    final cleanPhone = _customer!.phone!.replaceAll(RegExp(r'[^\d]'), '');
    String waPhone = cleanPhone;
    if (waPhone.startsWith('0')) {
      waPhone = '91${waPhone.substring(1)}';
    } else if (!waPhone.startsWith('91') && waPhone.length == 10) {
      waPhone = '91$waPhone';
    }
    final symbol = AppConstants.getCurrencySymbol(
        context.read<StorageService>().defaultCurrency);
    final balance = _customer!.balance;
    final msg = loc.t('reminderMsg', params: {
      'name': _customer!.name,
      'amount': '$symbol${balance.abs().toStringAsFixed(2)}',
    });
    final uri = Uri.parse('https://wa.me/$waPhone?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Mark as settled (create opposite transaction to zero out balance)
  Future<void> _settleUp() async {
    if (_customer == null) return;
    final loc = context.loc;
    final balance = _customer!.balance;
    if (balance == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('accountSettled'))),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Text(loc.t('accountSettled')),
          ],
        ),
        content: Text(
          '${loc.t('accountSettled')}?\n'
          '${_customer!.name}: ₹${balance.abs().toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.t('settled')),
          ),
        ],
      ),
    );

    if (result == true) {
      final storage = context.read<StorageService>();
      // balance = totalCredit - totalDebit
      // balance > 0 (To Give): we gave money (credit), need to take back (debit) to zero out
      // balance < 0 (To Take): we took money (debit), need to give back (credit) to zero out

      if (balance > 0) {
        // To Give — we gave extra, now take it back (debit)
        _customer!.totalDebit += balance.abs();
      } else {
        // To Take — we took extra, now give it back (credit)
        _customer!.totalCredit += balance.abs();
      }
      await storage.updateCustomer(_customer!);

      final entry = Entry.create(
        type: balance > 0 ? 'cash_in' : 'cash_out',
        amount: balance.abs(),
        currency: storage.defaultCurrency,
        customerId: _customer!.id,
        customerName: _customer!.name,
        notes: loc.t('accountSettled'),
        category: balance > 0 ? 'debit' : 'credit',
      );
      await storage.addEntry(entry);

      setState(() {
        _customer = storage.getCustomer(widget.customerId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('accountSettled')),
            backgroundColor: AppColors.success,
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

    if (_customer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final balance = _customer!.balance;
    final entries = _customerEntries;
    final isSettled = balance == 0 && entries.isNotEmpty;

    // Khata page colors
    final paperColor = isDark ? const Color(0xFF2C1810) : const Color(0xFFFFF8DC);
    final ruledLineColor = isDark
        ? const Color(0xFF5D4037).withOpacity(0.3)
        : const Color(0xFFB0C4DE).withOpacity(0.5);
    final marginLineColor = const Color(0xFFD32F2F).withOpacity(0.4);
    final textColor = isDark ? const Color(0xFFF5E6D3) : const Color(0xFF1A1A1A);
    final symbol = AppConstants.getCurrencySymbol(
        context.read<StorageService>().defaultCurrency);

    return Scaffold(
      backgroundColor: paperColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF3E2723) : const Color(0xFF8B0000),
        foregroundColor: const Color(0xFFD4AF37),
        title: Text(
          _customer!.name,
          style: const TextStyle(
            fontFamily: 'KhataHandwriting',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Share page as text
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: loc.t('sharePage'),
            onPressed: _sharePage,
          ),
          // Share as PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Share PDF',
            onPressed: () async {
              final storage = context.read<StorageService>();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)),
              );
              await PdfService.generateCustomerPdf(storage, _customer!, _customerEntries);
            },
          ),
          // WhatsApp reminder
          if (_customer!.phone != null && _customer!.phone!.isNotEmpty && balance != 0)
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: loc.t('whatsappReminder'),
              onPressed: _sendWhatsAppReminder,
            ),
          // Call
          if (_customer!.phone != null && _customer!.phone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.call),
              tooltip: loc.t('callCustomer'),
              onPressed: _callCustomer,
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Red margin line
            Positioned(
              left: 24,
              top: 0,
              bottom: 50, // Leave space for banner ad
              child: Container(
                width: 1.5,
                color: marginLineColor,
              ),
            ),
            // Ruled lines
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 50,
              child: CustomPaint(
                painter: RuledLinesPainter(ruledLineColor),
              ),
            ),
            // Content
            CustomScrollView(
              slivers: [
                // Page number header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${loc.t('pageNo')}: ${widget.pageNo ?? '-'}',
                          style: TextStyle(
                            fontFamily: 'KhataHandwriting',
                            fontSize: 14,
                            color: textColor.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (isSettled)
                          // Settled stamp
                          Transform.rotate(
                            angle: -0.15,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.success, width: 2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                loc.t('settled'),
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Customer header card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(32, 8, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3E2723).withOpacity(0.5)
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customer!.name,
                          style: TextStyle(
                            fontFamily: 'KhataHandwriting',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_customer!.phone != null && _customer!.phone!.isNotEmpty)
                          _infoRow(Icons.phone, _customer!.phone!, textColor),
                        if (_customer!.address != null && _customer!.address!.isNotEmpty)
                          _infoRow(Icons.location_on, _customer!.address!, textColor),
                        if (_customer!.email != null && _customer!.email!.isNotEmpty)
                          _infoRow(Icons.email, _customer!.email!, textColor),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        // Balance
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              loc.t('balance'),
                              style: TextStyle(
                                fontFamily: 'KhataHandwriting',
                                fontSize: 16,
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              '$symbol ${balance.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontFamily: 'KhataHandwriting',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: balance > 0
                                    ? const Color(0xFFC62828)
                                    : (balance < 0 ? const Color(0xFF2E7D32) : textColor),
                              ),
                            ),
                          ],
                        ),
                        if (balance != 0)
                          Text(
                            balance > 0 ? loc.t('youWillPay') : loc.t('youWillReceive'),
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: textColor.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Transactions table header
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(32, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: textColor.withOpacity(0.3), width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            loc.t('notes'),
                            style: TextStyle(
                              fontFamily: 'KhataHandwriting',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            loc.t('description'),
                            style: TextStyle(
                              fontFamily: 'KhataHandwriting',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            loc.t('took'),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: 'KhataHandwriting',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            loc.t('gave'),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: 'KhataHandwriting',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFC62828),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Transactions list
                if (entries.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          loc.t('noTransactions'),
                          style: TextStyle(
                            fontFamily: 'KhataHandwriting',
                            fontSize: 16,
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = entries[index];
                        final isCredit = entry.category == 'credit';

                        return InkWell(
                          onTap: () => _showEntryOptions(entry),
                          onLongPress: () => _showEntryOptions(entry),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(32, 0, 16, 0),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: textColor.withOpacity(0.1),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '${entry.date.day}/${entry.date.month}',
                                    style: TextStyle(
                                      fontFamily: 'KhataHandwriting',
                                      fontSize: 13,
                                      color: textColor.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                                // Description
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.notes?.isNotEmpty == true
                                        ? entry.notes!
                                        : (isCredit ? loc.t('amountGiven') : loc.t('amountTaken')),
                                    style: TextStyle(
                                      fontFamily: 'KhataHandwriting',
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                // Took (debit)
                                Expanded(
                                  child: Text(
                                    !isCredit
                                        ? '$symbol${entry.amount.toStringAsFixed(0)}'
                                        : '',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontFamily: 'KhataHandwriting',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                                // Gave (credit)
                                Expanded(
                                  child: Text(
                                    isCredit
                                        ? '$symbol${entry.amount.toStringAsFixed(0)}'
                                        : '',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontFamily: 'KhataHandwriting',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFC62828),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: entries.length,
                    ),
                  ),

                // Totals row
                if (entries.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(32, 4, 16, 0),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: textColor.withOpacity(0.3), width: 2),
                          bottom: BorderSide(color: textColor.withOpacity(0.3), width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 60),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Total:',
                              style: TextStyle(
                                fontFamily: 'KhataHandwriting',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$symbol${_customer!.totalDebit.toStringAsFixed(0)}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontFamily: 'KhataHandwriting',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$symbol${_customer!.totalCredit.toStringAsFixed(0)}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontFamily: 'KhataHandwriting',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFC62828),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Action buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 16, 16, 16),
                    child: Column(
                      children: [
                        // Took / Gave buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _addTransaction(false),
                                icon: const Icon(Icons.south, size: 18),
                                label: Text(loc.t('took')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _addTransaction(true),
                                icon: const Icon(Icons.north, size: 18),
                                label: Text(loc.t('gave')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC62828),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Settle up + Share page
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _settleUp,
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: Text(loc.t('settled')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.success,
                                  side: const BorderSide(color: AppColors.success),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _sharePage,
                                icon: const Icon(Icons.share, size: 18),
                                label: Text(loc.t('sharePage')),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF8B0000),
                                  side: const BorderSide(color: Color(0xFF8B0000)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  Widget _infoRow(IconData icon, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor.withOpacity(0.5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to draw ruled horizontal lines (like a notebook page)
class RuledLinesPainter extends CustomPainter {
  final Color color;
  RuledLinesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const lineSpacing = 32.0;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
