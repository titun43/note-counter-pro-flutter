import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../services/admob_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../models/entry.dart';
import '../widgets/note_widget.dart';
import 'calculator_screen.dart';
import 'upi_qr_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCurrency = 'INR';
  final Map<int, TextEditingController> _countControllers = {};
  String _transactionType = 'Payable';
  final TextEditingController _targetAmountController = TextEditingController();
  final TextEditingController _otherAmountController = TextEditingController();
  final TextEditingController _onlineAmountController = TextEditingController();
  bool _showExtraFields = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = context.read<StorageService>();
      setState(() {
        _selectedCurrency = storage.defaultCurrency;
      });
      _initCountControllers();
    });
  }
  
  void _initCountControllers() {
    final denoms = AppConstants.getDenominations(_selectedCurrency);
    for (final denom in denoms) {
      final value = denom['value'] as int;
      if (!_countControllers.containsKey(value)) {
        _countControllers[value] = TextEditingController(text: '0');
      }
    }
  }
  
  void _clearCountControllers() {
    for (final controller in _countControllers.values) {
      controller.dispose();
    }
    _countControllers.clear();
  }
  
  @override
  void dispose() {
    _clearCountControllers();
    _targetAmountController.dispose();
    _otherAmountController.dispose();
    _onlineAmountController.dispose();
    super.dispose();
  }
  
  List<Map<String, dynamic>> get _denominations {
    return AppConstants.getDenominations(_selectedCurrency);
  }
  
  String get _currencySymbol {
    return AppConstants.getCurrencySymbol(_selectedCurrency);
  }
  
  int _getCount(int value) {
    final controller = _countControllers[value];
    if (controller == null) return 0;
    return int.tryParse(controller.text) ?? 0;
  }
  
  double get _cashTotal {
    double total = 0;
    for (final denom in _denominations) {
      final value = denom['value'] as int;
      total += value * _getCount(value);
    }
    return total;
  }
  
  double get _otherAmount {
    return double.tryParse(_otherAmountController.text) ?? 0;
  }
  
  double get _onlineAmount {
    return double.tryParse(_onlineAmountController.text) ?? 0;
  }
  
  double get _targetAmount {
    return double.tryParse(_targetAmountController.text) ?? 0;
  }
  
  double get _grandTotal {
    return _cashTotal + _otherAmount + _onlineAmount;
  }
  
  double get _difference {
    return _grandTotal - _targetAmount;
  }
  
  bool get _hasTarget {
    return _targetAmount > 0;
  }
  
  int get _totalNotes {
    int total = 0;
    for (final denom in _denominations) {
      total += _getCount(denom['value'] as int);
    }
    return total;
  }
  
  void _incrementCount(int value) {
    final controller = _countControllers[value];
    if (controller == null) return;
    final current = int.tryParse(controller.text) ?? 0;
    controller.text = '${current + 1}';
    setState(() {});
  }
  
  void _decrementCount(int value) {
    final controller = _countControllers[value];
    if (controller == null) return;
    final current = int.tryParse(controller.text) ?? 0;
    if (current > 0) {
      controller.text = '${current - 1}';
      setState(() {});
    }
  }
  
  void _onCountChanged(int value) {
    setState(() {});
  }
  
  void _reset() {
    for (final controller in _countControllers.values) {
      controller.text = '0';
    }
    _targetAmountController.clear();
    _otherAmountController.clear();
    _onlineAmountController.clear();
    setState(() {});
  }
  
  void _changeCurrency(String? currencyCode) {
    if (currencyCode == null || currencyCode == _selectedCurrency) return;
    setState(() {
      _selectedCurrency = currencyCode;
      _clearCountControllers();
      _initCountControllers();
      context.read<StorageService>().setDefaultCurrency(currencyCode);
    });
  }
  
  Future<void> _saveEntry(bool isCashIn) async {
    if (_grandTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some amount first!')),
      );
      return;
    }

    // Show name/note input dialog
    final nameController = TextEditingController();
    final noteController = TextEditingController();
    final loc = context.loc;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCashIn ? loc.t('cashInDetails') : loc.t('cashOutDetails')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: loc.t('nameLabel'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: loc.t('noteLabel'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.note),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(loc.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'note': noteController.text.trim(),
              });
            },
            child: Text(loc.t('save')),
          ),
        ],
      ),
    );

    if (result == null) return; // User cancelled

    final name = result['name'] ?? '';
    final noteText = result['note'] ?? '';

    final storage = context.read<StorageService>();
    final denominationMap = <String, int>{};
    for (final denom in _denominations) {
      final value = denom['value'] as int;
      final count = _getCount(value);
      if (count > 0) {
        denominationMap[value.toString()] = count;
      }
    }

    final noteString = StringBuffer();
    noteString.write('$_transactionType - $_totalNotes notes');
    if (_otherAmount > 0) noteString.write(' + Other: $_currencySymbol$_otherAmount');
    if (_onlineAmount > 0) noteString.write(' + Online: $_currencySymbol$_onlineAmount');
    if (name.isNotEmpty) noteString.write(' | From: $name');
    if (noteText.isNotEmpty) noteString.write(' | $noteText');

    final entry = Entry.create(
      type: isCashIn ? 'cash_in' : 'cash_out',
      amount: _grandTotal,
      currency: _selectedCurrency,
      notes: noteString.toString(),
      denominationCounts: denominationMap,
      category: _transactionType.toLowerCase(),
      customerName: name.isNotEmpty ? name : null,
    );

    await storage.addEntry(entry);

    if (mounted) {
      // Save values before reset
      final savedGrandTotal = _grandTotal;
      final savedTotalNotes = _totalNotes;
      final savedOtherAmount = _otherAmount;
      final savedOnlineAmount = _onlineAmount;
      final savedTransactionType = _transactionType;
      final savedCurrencySymbol = _currencySymbol;

      // Show receipt dialog with saved values
      _showReceiptDialog(entry, isCashIn, name, noteText,
          savedGrandTotal, savedTotalNotes, savedOtherAmount, savedOnlineAmount,
          savedTransactionType, savedCurrencySymbol);

      _reset();
    }
  }

  void _showReceiptDialog(Entry entry, bool isCashIn, String name, String noteText,
      double savedGrandTotal, int savedTotalNotes, double savedOtherAmount,
      double savedOnlineAmount, String savedTransactionType, String savedCurrencySymbol) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenshotController = ScreenshotController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Receipt wrapped in Screenshot widget
            Screenshot(
              controller: screenshotController,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 350),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Receipt header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCashIn ? AppColors.success : AppColors.danger,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.white, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            isCashIn ? 'CASH IN' : 'CASH OUT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Receipt body
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Note Counter Pro',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry.date.day}/${entry.date.month}/${entry.date.year} - ${entry.date.hour}:${entry.date.minute.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),

                          if (name.isNotEmpty)
                            _receiptRow('Name', name, theme),
                          if (noteText.isNotEmpty)
                            _receiptRow('Note', noteText, theme),
                          _receiptRow('Type', savedTransactionType, theme),
                          _receiptRow('Total Notes', '$savedTotalNotes', theme),

                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Denominations breakdown
                          if (entry.denominationCounts != null && entry.denominationCounts!.isNotEmpty) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Denomination Breakdown:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...entry.denominationCounts!.entries.map((e) {
                              final value = int.parse(e.key);
                              final count = e.value;
                              final subtotal = value * count;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('$savedCurrencySymbol$value × $count', style: theme.textTheme.bodySmall),
                                    Text('$savedCurrencySymbol$subtotal', style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                          ],

                          // Other & Online
                          if (savedOtherAmount > 0)
                            _receiptRow('Other Amount', '$savedCurrencySymbol${savedOtherAmount.toStringAsFixed(2)}', theme),
                          if (savedOnlineAmount > 0)
                            _receiptRow('Online Amount', '$savedCurrencySymbol${savedOnlineAmount.toStringAsFixed(2)}', theme),

                          if (savedOtherAmount > 0 || savedOnlineAmount > 0) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                          ],

                          // Grand total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GRAND TOTAL',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$savedCurrencySymbol ${savedGrandTotal.toStringAsFixed(2)}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCashIn ? AppColors.success : AppColors.danger,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),

                          Text(
                            'Generated by Note Counter Pro',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons (outside screenshot)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text('Close', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    // Capture receipt as image
                    try {
                      final Uint8List? imageBytes = await screenshotController.capture();
                      if (imageBytes != null) {
                        // Save to temp file
                        final tempDir = await getTemporaryDirectory();
                        final now = DateTime.now();
                        final filename = 'receipt-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}${now.second}.png';
                        final file = File('${tempDir.path}/$filename');
                        await file.writeAsBytes(imageBytes);

                        // Share as image
                        await Share.shareXFiles(
                          [XFile(file.path)],
                          subject: '${isCashIn ? "Cash In" : "Cash Out"} Receipt - $savedCurrencySymbol${savedGrandTotal.toStringAsFixed(2)}',
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      debugPrint('Share image failed: $e');
                      // Fallback to text share
                      _shareReceiptAsText(entry, name, noteText, isCashIn,
                          savedGrandTotal, savedTotalNotes, savedOtherAmount,
                          savedOnlineAmount, savedTransactionType, savedCurrencySymbol);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share Image'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Show interstitial ad after receipt
    AdMobService.showInterstitial();
  }

  Widget _receiptRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// Fallback: share receipt as text (if image capture fails)
  void _shareReceiptAsText(Entry entry, String name, String noteText, bool isCashIn,
      double savedGrandTotal, int savedTotalNotes, double savedOtherAmount,
      double savedOnlineAmount, String savedTransactionType, String savedCurrencySymbol) {
    final receiptText = StringBuffer();
    receiptText.writeln('═══════════════════════');
    receiptText.writeln('   ${isCashIn ? "CASH IN" : "CASH OUT"} RECEIPT');
    receiptText.writeln('═══════════════════════');
    receiptText.writeln('Note Counter Pro');
    receiptText.writeln('Date: ${entry.date.day}/${entry.date.month}/${entry.date.year}');
    receiptText.writeln('Time: ${entry.date.hour}:${entry.date.minute.toString().padLeft(2, '0')}');
    receiptText.writeln('───────────────────────');
    if (name.isNotEmpty) receiptText.writeln('Name: $name');
    if (noteText.isNotEmpty) receiptText.writeln('Note: $noteText');
    receiptText.writeln('Type: $savedTransactionType');
    receiptText.writeln('Total Notes: $savedTotalNotes');
    receiptText.writeln('───────────────────────');

    if (entry.denominationCounts != null) {
      receiptText.writeln('Denomination Breakdown:');
      entry.denominationCounts!.forEach((key, count) {
        final value = int.parse(key);
        final subtotal = value * count;
        receiptText.writeln('  $savedCurrencySymbol$value × $count = $savedCurrencySymbol$subtotal');
      });
      receiptText.writeln('───────────────────────');
    }

    if (savedOtherAmount > 0) receiptText.writeln('Other: $savedCurrencySymbol${savedOtherAmount.toStringAsFixed(2)}');
    if (savedOnlineAmount > 0) receiptText.writeln('Online: $savedCurrencySymbol${savedOnlineAmount.toStringAsFixed(2)}');

    receiptText.writeln('═══════════════════════');
    receiptText.writeln('GRAND TOTAL: $savedCurrencySymbol ${savedGrandTotal.toStringAsFixed(2)}');
    receiptText.writeln('═══════════════════════');
    receiptText.writeln('Generated by Note Counter Pro');

    Share.share(receiptText.toString(), subject: 'Receipt - $savedCurrencySymbol${savedGrandTotal.toStringAsFixed(2)}');
  }
  
  /// Show History bottom sheet with two tabs:
  /// 1. Save In/Out History (recent entries)
  /// 2. QR Code History (recent QR generations)
  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final loc = context.loc;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: AppColors.primaryDark),
                      const SizedBox(width: 8),
                      Text(
                        loc.t('viewHistory'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Tab bar
                Container(
                  color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                  child: TabBar(
                    labelColor: AppColors.primaryDark,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primaryDark,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.swap_vert, size: 18),
                        text: loc.t('saveInOutHistory'),
                      ),
                      Tab(
                        icon: const Icon(Icons.qr_code, size: 18),
                        text: loc.t('qrCodeHistory'),
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildSaveInOutHistoryTab(isDark),
                      _buildQrHistoryTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build Save In/Out history tab content
  Widget _buildSaveInOutHistoryTab(bool isDark) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final storage = context.watch<StorageService>();
    final entries = storage.entries.take(20).toList();

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                loc.t('noEntriesYet'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final e = entries[index];
        final isIn = e.type == 'cash_in';
        final symbol = AppConstants.getCurrencySymbol(e.currency);

        return Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => _showHistoryReceiptDialog(e),
            leading: CircleAvatar(
              backgroundColor: isIn ? AppColors.success.withOpacity(0.2) : AppColors.danger.withOpacity(0.2),
              child: Icon(
                isIn ? Icons.south : Icons.north,
                color: isIn ? AppColors.success : AppColors.danger,
              ),
            ),
            title: Row(
              children: [
                Text(
                  '$symbol${e.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isIn ? AppColors.success : AppColors.danger,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isIn ? AppColors.success.withOpacity(0.15) : AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isIn ? loc.t('cashIn') : loc.t('cashOut'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isIn ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.customerName != null && e.customerName!.isNotEmpty)
                  Text(
                    e.customerName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  '${e.date.day}/${e.date.month}/${e.date.year} ${e.date.hour}:${e.date.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, size: 18),
                  color: AppColors.info,
                  tooltip: loc.t('share'),
                  onPressed: () => _shareHistoryEntry(e),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build QR Code history tab content
  Widget _buildQrHistoryTab(bool isDark) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final storage = context.watch<StorageService>();
    final qrHistory = storage.qrHistory;

    if (qrHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                loc.t('noQrHistory'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: qrHistory.length,
      itemBuilder: (context, index) {
        final qr = qrHistory[index];
        final name = qr['name'] ?? '';
        final upiId = qr['upiId'] ?? '';
        final amount = qr['amount'] ?? '';
        final payeeName = qr['payeeName'] ?? '';

        // Build UPI deep link string for QR preview
        String upiString = 'upi://pay?pa=${Uri.encodeComponent(upiId)}';
        if (payeeName.isNotEmpty) {
          upiString += '&pn=${Uri.encodeComponent(payeeName)}';
        }
        if (amount.isNotEmpty) {
          upiString += '&am=$amount';
        }
        upiString += '&cu=INR';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showQrDetailDialog(qr, upiString),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // QR Preview (small)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: QrImageView(
                      data: upiString,
                      version: QrVersions.auto,
                      size: 70,
                      gapless: true,
                      errorStateBuilder: (context, error) => const Icon(
                        Icons.error_outline,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          name.isNotEmpty ? name : (upiId.isNotEmpty ? upiId : 'QR'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // UPI ID
                        if (upiId.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.account_circle, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  upiId,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        // Amount badge
                        if (amount.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '₹$amount',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        color: AppColors.info,
                        tooltip: loc.t('share'),
                        onPressed: () {
                          final shareText = StringBuffer();
                          shareText.writeln('UPI Payment Details');
                          shareText.writeln('─────────────────');
                          if (name.isNotEmpty) shareText.writeln('Name: $name');
                          if (upiId.isNotEmpty) shareText.writeln('UPI ID: $upiId');
                          if (amount.isNotEmpty) shareText.writeln('Amount: ₹$amount');
                          shareText.writeln('─────────────────');
                          shareText.writeln('Pay via any UPI app to: $upiId');
                          shareText.writeln('— Sent via Note Counter Pro');
                          Share.share(shareText.toString(), subject: 'UPI QR Details - $name');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Icon(
                        Icons.visibility,
                        size: 14,
                        color: AppColors.textSecondary.withOpacity(0.4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show full QR detail dialog with large QR + pay button
  void _showQrDetailDialog(Map<String, String> qr, String upiString) {
    final theme = Theme.of(context);
    final name = qr['name'] ?? '';
    final upiId = qr['upiId'] ?? '';
    final amount = qr['amount'] ?? '';
    final payeeName = qr['payeeName'] ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.qr_code, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name.isNotEmpty ? name : 'QR Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              // Large QR
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: QrImageView(
                  data: upiString,
                  version: QrVersions.auto,
                  size: 200,
                  gapless: true,
                ),
              ),
              const SizedBox(height: 12),
              // Details
              if (upiId.isNotEmpty)
                _qrDetailRow('UPI ID', upiId, theme),
              if (payeeName.isNotEmpty)
                _qrDetailRow('Payee', payeeName, theme),
              if (amount.isNotEmpty)
                _qrDetailRow('Amount', '₹$amount', theme),
              const SizedBox(height: 16),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UpiQrScreen()),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New QR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Show receipt dialog when tapping a history entry
  void _showHistoryReceiptDialog(Entry entry) {
    final theme = Theme.of(context);
    final isIn = entry.type == 'cash_in';
    final symbol = AppConstants.getCurrencySymbol(entry.currency);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isIn ? AppColors.success : AppColors.danger,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      isIn ? 'CASH IN' : 'CASH OUT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Note Counter Pro',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.date.day}/${entry.date.month}/${entry.date.year} - ${entry.date.hour}:${entry.date.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (entry.customerName != null && entry.customerName!.isNotEmpty)
                      _receiptRow('Name', entry.customerName!, theme),
                    if (entry.category != null && entry.category!.isNotEmpty)
                      _receiptRow('Type', entry.category!.toUpperCase(), theme),
                    if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Notes:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          entry.notes!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                    if (entry.denominationCounts != null && entry.denominationCounts!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Denomination Breakdown:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...entry.denominationCounts!.entries.map((e) {
                        final value = int.parse(e.key);
                        final count = e.value;
                        final subtotal = value * count;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$symbol$value × $count', style: theme.textTheme.bodySmall),
                              Text('$symbol$subtotal', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GRAND TOTAL',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$symbol ${entry.amount.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isIn ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _shareHistoryEntry(entry);
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Share a history entry as text (WhatsApp, SMS, etc.)
  void _shareHistoryEntry(Entry entry) {
    final isIn = entry.type == 'cash_in';
    final symbol = AppConstants.getCurrencySymbol(entry.currency);

    final text = StringBuffer();
    text.writeln('═══════════════════════');
    text.writeln('   ${isIn ? "CASH IN" : "CASH OUT"} RECEIPT');
    text.writeln('═══════════════════════');
    text.writeln('Note Counter Pro');
    text.writeln('Date: ${entry.date.day}/${entry.date.month}/${entry.date.year}');
    text.writeln('Time: ${entry.date.hour}:${entry.date.minute.toString().padLeft(2, '0')}');
    text.writeln('───────────────────────');
    if (entry.customerName != null && entry.customerName!.isNotEmpty) {
      text.writeln('Name: ${entry.customerName}');
    }
    if (entry.category != null && entry.category!.isNotEmpty) {
      text.writeln('Type: ${entry.category!.toUpperCase()}');
    }
    if (entry.notes != null && entry.notes!.isNotEmpty) {
      text.writeln('Notes: ${entry.notes}');
    }
    text.writeln('───────────────────────');

    if (entry.denominationCounts != null && entry.denominationCounts!.isNotEmpty) {
      text.writeln('Denomination Breakdown:');
      entry.denominationCounts!.forEach((key, count) {
        final value = int.parse(key);
        final subtotal = value * count;
        text.writeln('  $symbol$value × $count = $symbol$subtotal');
      });
      text.writeln('───────────────────────');
    }

    text.writeln('═══════════════════════');
    text.writeln('GRAND TOTAL: $symbol ${entry.amount.toStringAsFixed(2)}');
    text.writeln('═══════════════════════');
    text.writeln('Generated by Note Counter Pro');

    Share.share(text.toString(), subject: 'Receipt - $symbol${entry.amount.toStringAsFixed(2)}');
  }

  void _sendToCalculator() {
    if (_grandTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some amount first!')),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalculatorScreen(
          initialValue: _grandTotal,
          currencyCode: _selectedCurrency,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
        
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          // === TOP: Currency + Notes + Clear + Total (compact, one row) ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
            child: Row(
              children: [
                // Currency selector (compact)
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.currencies.map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency['code'],
                        child: Text(
                          currency['code']!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: _changeCurrency,
                  ),
                ),
                const SizedBox(width: 4),
                // Notes count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.bgDarker : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_totalNotes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        loc.t('notes'),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Clear button (moved here from AppBar)
                IconButton(
                  onPressed: _reset,
                  icon: const Icon(Icons.cleaning_services),
                  color: AppColors.danger,
                  tooltip: 'Clear',
                  iconSize: 22,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 4),
                // Grand Total
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_currencySymbol${_grandTotal.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.bgDark,
                        ),
                      ),
                      Text(
                        loc.t('total'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.bgDark,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // === TRANSACTION TYPE TOGGLE ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = loc.t('payable')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _transactionType == loc.t('payable')
                            ? AppColors.danger.withOpacity(0.2)
                            : (isDark ? AppColors.bgCardDark : AppColors.bgCard),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        border: Border.all(
                          color: _transactionType == loc.t('payable')
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                      child: Text(
                        loc.t('payable'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _transactionType == loc.t('payable')
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = loc.t('receivable')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _transactionType == loc.t('receivable')
                            ? AppColors.success.withOpacity(0.2)
                            : (isDark ? AppColors.bgCardDark : AppColors.bgCard),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        border: Border.all(
                          color: _transactionType == loc.t('receivable')
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      child: Text(
                        loc.t('receivable'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _transactionType == loc.t('receivable')
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // === "More" button to show extra fields when all are empty ===
          if (!_showExtraFields && !_hasTarget && _otherAmount == 0 && _onlineAmount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showExtraFields = true;
                    });
                  },
                  icon: const Icon(Icons.expand_more, size: 20),
                  label: Text(loc.t('more')),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
            ),
          
          // === COLLAPSIBLE EXTRA FIELDS (Target/Other/Online) ===
          // Visible if: user toggled "More" OR any field has input
          if (_showExtraFields || _hasTarget || _otherAmount > 0 || _onlineAmount > 0) ...[
            // === TARGET AMOUNT ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetAmountController,
                      decoration: InputDecoration(
                        labelText: loc.t('targetAmount'),
                        prefixText: '$_currencySymbol ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: _targetAmountController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _targetAmountController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_showExtraFields && !_hasTarget && _otherAmount == 0 && _onlineAmount == 0)
                    IconButton(
                      icon: const Icon(Icons.expand_less),
                      tooltip: 'Hide',
                      onPressed: () {
                        setState(() {
                          _showExtraFields = false;
                        });
                      },
                    ),
                ],
              ),
            ),
            
            // === TARGET vs ACTUAL COMPARISON ===
            if (_hasTarget)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _difference >= 0
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _difference >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _difference >= 0 ? Icons.check_circle : Icons.warning,
                      color: _difference >= 0 ? AppColors.success : AppColors.danger,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _difference >= 0 ? 'Target Reached!' : 'Short of Target',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _difference >= 0 ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          Text(
                            _difference >= 0
                                ? 'Surplus: $_currencySymbol${_difference.toStringAsFixed(2)}'
                                : 'Need: $_currencySymbol${_difference.abs().toStringAsFixed(2)} more',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _difference >= 0 ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Target',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$_currencySymbol${_targetAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Actual: $_currencySymbol${_grandTotal.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _difference >= 0 ? AppColors.success : AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            // === OTHER + ONLINE AMOUNT ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _otherAmountController,
                      decoration: InputDecoration(
                        labelText: loc.t('otherAmount'),
                        prefixText: '$_currencySymbol ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: _otherAmountController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _otherAmountController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _onlineAmountController,
                      decoration: InputDecoration(
                        labelText: loc.t('onlineAmount'),
                        prefixText: '$_currencySymbol ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: _onlineAmountController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _onlineAmountController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // === DENOMINATION LIST (vertical, scrollable, inline editable) ===
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _denominations.length,
              itemBuilder: (context, index) {
                final denom = _denominations[index];
                final value = denom['value'] as int;
                final name = denom['name'] as String;
                final count = _getCount(value);
                final subtotal = value * count;
                
                // Ensure controller exists
                if (!_countControllers.containsKey(value)) {
                  _countControllers[value] = TextEditingController(text: '0');
                }
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        // Note widget (looks like real currency note)
                        NoteWidget(
                          value: value,
                          currencyCode: _selectedCurrency,
                          currencySymbol: _currencySymbol,
                          size: 64,
                        ),
                        const SizedBox(width: 8),
                        // Minus button
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: count > 0 ? () => _decrementCount(value) : null,
                          color: AppColors.danger,
                          iconSize: 28,
                        ),
                        // Count display - INLINE EDITABLE TextField
                        // User can tap directly and type number with keyboard
                        // No dialog box needed
                        Container(
                          width: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgDarker : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _countControllers[value],
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => _onCountChanged(value),
                            onTap: () {
                              // Select all text when tapped for easy editing
                              _countControllers[value]!.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _countControllers[value]!.text.length,
                              );
                            },
                          ),
                        ),
                        // Plus button
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () => _incrementCount(value),
                          color: AppColors.success,
                          iconSize: 28,
                        ),
                        const Spacer(),
                        // Subtotal
                        Text(
                          '$_currencySymbol$subtotal',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // === ACTION BUTTONS ROW ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
              border: Border(
                top: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _saveEntry(true),
                    icon: const Icon(Icons.south, size: 18),
                    label: Text(loc.t('saveIn'), style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendToCalculator,
                  icon: const Icon(Icons.calculate),
                  color: AppColors.info,
                  tooltip: loc.t('calculator'),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  iconSize: 24,
                ),
                // === HISTORY BUTTON (center) ===
                // Click to view Save In/Out + QR history
                IconButton(
                  onPressed: _showHistorySheet,
                  icon: const Icon(Icons.history),
                  color: AppColors.primaryDark,
                  tooltip: loc.t('history'),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  iconSize: 24,
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UpiQrScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code),
                  color: AppColors.primary,
                  tooltip: loc.t('upiQrCode'),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  iconSize: 24,
                ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _saveEntry(false),
                    icon: const Icon(Icons.north, size: 18),
                    label: Text(loc.t('saveOut'), style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // === SUMMARY FOOTER ===
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? AppColors.bgDarker : Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryBox(
                        loc.t('cashTotal'),
                        '$_currencySymbol${_cashTotal.toStringAsFixed(2)}',
                        Colors.amber[100]!,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _summaryBox(
                        loc.t('other'),
                        '$_currencySymbol${_otherAmount.toStringAsFixed(2)}',
                        Colors.cyan[100]!,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _summaryBox(
                        loc.t('online'),
                        '$_currencySymbol${_onlineAmount.toStringAsFixed(2)}',
                        Colors.purple[100]!,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.t('grandTotal'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_currencySymbol ${_grandTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
  
  Widget _summaryBox(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
