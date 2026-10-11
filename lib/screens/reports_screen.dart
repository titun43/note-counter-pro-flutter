import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../models/entry.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final storage = context.read<StorageService>();
    final entries = storage.entries;
    
    final now = DateTime.now();
    final thisMonth = entries.where((e) =>
      e.date.month == now.month && e.date.year == now.year).toList();
    final thisWeek = entries.where((e) =>
      now.difference(e.date).inDays <= 7).toList();
    
    final totalThisMonth = thisMonth.fold(0.0, (sum, e) => sum + e.amount);
    final totalThisWeek = thisWeek.fold(0.0, (sum, e) => sum + e.amount);
    final totalAllTime = entries.fold(0.0, (sum, e) => sum + e.amount);
    
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('reports'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportCard(
            context,
            title: loc.t('thisWeek'),
            amount: totalThisWeek,
            count: thisWeek.length,
            color: AppColors.info,
            icon: Icons.date_range,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            context,
            title: loc.t('thisMonth'),
            amount: totalThisMonth,
            count: thisMonth.length,
            color: AppColors.primary,
            icon: Icons.calendar_month,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            context,
            title: loc.t('allTime'),
            amount: totalAllTime,
            count: entries.length,
            color: AppColors.success,
            icon: Icons.all_inclusive,
          ),
          const SizedBox(height: 24),
          Text(
            loc.t('recentTransactions'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    loc.t('noTransactions'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            )
          else
            ...entries.take(20).map((entry) => _buildReceiptCard(entry, theme, loc, context)),
        ],
      ),
    );
  }
  
  Widget _buildReportCard(
    BuildContext context, {
    required String title,
    required double amount,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 28,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '$count transactions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getTypeColor(String type) {
    switch (type) {
      case 'cash_in':
        return AppColors.success;
      case 'cash_out':
        return AppColors.danger;
      case 'counter':
        return AppColors.primary;
      default:
        return AppColors.info;
    }
  }
  
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'cash_in':
        return Icons.arrow_downward;
      case 'cash_out':
        return Icons.arrow_upward;
      case 'counter':
        return Icons.calculate;
      default:
        return Icons.receipt;
    }
  }
  
  Widget _buildReceiptCard(Entry entry, ThemeData theme, AppLocalizations loc, BuildContext context) {
    final isCashIn = entry.type == 'cash_in';
    final currencySymbol = AppConstants.getCurrencySymbol(entry.currency);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showReceiptDetail(entry, theme, context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCashIn ? AppColors.success.withOpacity(0.15) : AppColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  isCashIn ? Icons.south : Icons.north,
                  color: isCashIn ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currencySymbol${entry.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      entry.customerName != null && entry.customerName!.isNotEmpty
                          ? entry.customerName!
                          : (isCashIn ? 'Cash In' : 'Cash Out'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${entry.date.day}/${entry.date.month}/${entry.date.year} ${entry.date.hour}:${entry.date.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Share button
              IconButton(
                icon: const Icon(Icons.share, size: 20),
                color: AppColors.info,
                onPressed: () => _shareEntryReceipt(entry),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showReceiptDetail(Entry entry, ThemeData theme, BuildContext context) {
    final isCashIn = entry.type == 'cash_in';
    final currencySymbol = AppConstants.getCurrencySymbol(entry.currency);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Note Counter Pro', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.date.day}/${entry.date.month}/${entry.date.year} - ${entry.date.hour}:${entry.date.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (entry.customerName != null && entry.customerName!.isNotEmpty)
                      _detailRow('Name', entry.customerName!, theme),
                    if (entry.notes != null && entry.notes!.isNotEmpty)
                      _detailRow('Note', entry.notes!, theme),
                    _detailRow('Amount', '$currencySymbol${entry.amount.toStringAsFixed(2)}', theme),
                    if (entry.denominationCounts != null && entry.denominationCounts!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Denomination Breakdown:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
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
                              Text('$currencySymbol$value × $count', style: theme.textTheme.bodySmall),
                              Text('$currencySymbol$subtotal', style: theme.textTheme.bodySmall),
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
                        Text('TOTAL', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '$currencySymbol ${entry.amount.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCashIn ? AppColors.success : AppColors.danger,
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
                              _shareEntryReceipt(entry);
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
  
  Widget _detailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
  
  void _shareEntryReceipt(Entry entry) {
    final isCashIn = entry.type == 'cash_in';
    final currencySymbol = AppConstants.getCurrencySymbol(entry.currency);
    
    final receiptText = StringBuffer();
    receiptText.writeln('═══════════════════════');
    receiptText.writeln('   ${isCashIn ? "CASH IN" : "CASH OUT"} RECEIPT');
    receiptText.writeln('═══════════════════════');
    receiptText.writeln('Note Counter Pro');
    receiptText.writeln('Date: ${entry.date.day}/${entry.date.month}/${entry.date.year}');
    receiptText.writeln('Time: ${entry.date.hour}:${entry.date.minute.toString().padLeft(2, '0')}');
    receiptText.writeln('───────────────────────');
    if (entry.customerName != null && entry.customerName!.isNotEmpty) {
      receiptText.writeln('Name: ${entry.customerName}');
    }
    if (entry.notes != null && entry.notes!.isNotEmpty) {
      receiptText.writeln('Note: ${entry.notes}');
    }
    receiptText.writeln('───────────────────────');
    
    if (entry.denominationCounts != null && entry.denominationCounts!.isNotEmpty) {
      receiptText.writeln('Denomination Breakdown:');
      entry.denominationCounts!.forEach((key, count) {
        final value = int.parse(key);
        final subtotal = value * count;
        receiptText.writeln('  $currencySymbol$value × $count = $currencySymbol$subtotal');
      });
      receiptText.writeln('───────────────────────');
    }
    
    receiptText.writeln('═══════════════════════');
    receiptText.writeln('TOTAL: $currencySymbol ${entry.amount.toStringAsFixed(2)}');
    receiptText.writeln('═══════════════════════');
    receiptText.writeln('Generated by Note Counter Pro');
    
    Share.share(receiptText.toString(), subject: 'Receipt - $currencySymbol${entry.amount.toStringAsFixed(2)}');
  }
}
