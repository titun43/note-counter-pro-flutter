// =============================================================================
// Note Counter Pro — Reports Screen (Redesigned v3.54.0)
// =============================================================================
// Features B + F: Reports Dashboard with charts + Smart Insights
//
// New sections:
//   1. Smart Insights cards (Feature F)
//   2. 3 stat cards (income, bills, dues)
//   3. Weekly bar chart (7 days, gold bars)
//   4. Payment breakdown (Cash/Other/Online)
//   5. Recent transactions (compact)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../widgets/banner_ad_widget.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final storage = context.watch<StorageService>();
    final entries = storage.entries;
    final bills = storage.bills;
    final currencySymbol =
        AppConstants.getCurrencySymbol(storage.defaultCurrency);

    final now = DateTime.now();
    final thisMonth = entries
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .toList();
    final thisWeek =
        entries.where((e) => now.difference(e.date).inDays <= 7).toList();

    final totalThisMonth =
        thisMonth.fold(0.0, (sum, e) => sum + e.amount);
    final totalThisWeek =
        thisWeek.fold(0.0, (sum, e) => sum + e.amount);
    final totalAllTime =
        entries.fold(0.0, (sum, e) => sum + e.amount);

    // Pending dues from bills
    final pendingBills = bills.where((b) => !b.isPaid).toList();
    final totalDues =
        pendingBills.fold(0.0, (sum, b) => sum + b.remainingAmount);

    // Weekly chart data (last 7 days)
    final weeklyData = _getWeeklyData(entries, now);

    // Payment breakdown
    final cashTotal =
        entries.where((e) => e.type == 'cash_in').fold(0.0, (s, e) => s + e.amount);
    final onlineTotal = entries
        .where((e) => e.type == 'cash_out')
        .fold(0.0, (s, e) => s + e.amount);
    final otherTotal = totalAllTime - cashTotal - onlineTotal;
    final breakdown = [
      (cashTotal, AppColors.success, loc.t('cashTotal')),
      (otherTotal.abs(), AppColors.info, loc.t('other')),
      (onlineTotal, AppColors.warning, loc.t('online')),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('reports'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // === SMART INSIGHTS (Feature F) ===
                if (entries.isNotEmpty) ...[
                  _buildSectionTitle(loc.t('smartInsights'), Icons.lightbulb, isDark),
                  const SizedBox(height: 8),
                  _buildInsightCard(
                    icon: '📈',
                    message: loc.t('incomeGrowth'),
                    color: AppColors.success,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildInsightCard(
                    icon: '📅',
                    message: loc.t('lowSalesDay'),
                    color: AppColors.warning,
                    isDark: isDark,
                  ),
                  if (totalDues > 0) ...[
                    const SizedBox(height: 6),
                    _buildInsightCard(
                      icon: '⚠️',
                      message: loc.t('pendingReminder'),
                      color: AppColors.danger,
                      isDark: isDark,
                      actionText: loc.t('remindAll'),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                // === STAT CARDS ===
                Row(
                  children: [
                    _buildStatCard(
                      loc.t('incomeThisMonth'),
                      '$currencySymbol${totalThisMonth.toStringAsFixed(0)}',
                      AppColors.success,
                      isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildStatCard(
                      loc.t('billsCount'),
                      '${bills.length}',
                      AppColors.info,
                      isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildStatCard(
                      loc.t('pendingDues'),
                      '$currencySymbol${totalDues.toStringAsFixed(0)}',
                      AppColors.danger,
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // === WEEKLY CHART (Feature B) ===
                _buildSectionTitle(loc.t('weeklyChart'), Icons.bar_chart, isDark),
                const SizedBox(height: 8),
                _buildWeeklyChart(weeklyData, currencySymbol, isDark),
                const SizedBox(height: 16),

                // === PAYMENT BREAKDOWN ===
                _buildSectionTitle(loc.t('paymentBreakdown'), Icons.pie_chart, isDark),
                const SizedBox(height: 8),
                _buildPaymentBreakdown(breakdown, totalAllTime, isDark),
                const SizedBox(height: 16),

                // === REPORT CARDS ===
                _buildReportCard(
                  context,
                  title: loc.t('thisWeek'),
                  amount: totalThisWeek,
                  count: thisWeek.length,
                  color: AppColors.info,
                  icon: Icons.date_range,
                  currencySymbol: currencySymbol,
                ),
                const SizedBox(height: 8),
                _buildReportCard(
                  context,
                  title: loc.t('thisMonth'),
                  amount: totalThisMonth,
                  count: thisMonth.length,
                  color: AppColors.primary,
                  icon: Icons.calendar_month,
                  currencySymbol: currencySymbol,
                ),
                const SizedBox(height: 8),
                _buildReportCard(
                  context,
                  title: loc.t('allTime'),
                  amount: totalAllTime,
                  count: entries.length,
                  color: AppColors.success,
                  icon: Icons.all_inclusive,
                  currencySymbol: currencySymbol,
                ),
                const SizedBox(height: 16),

                // === RECENT TRANSACTIONS ===
                if (entries.isNotEmpty) ...[
                  Text(
                    loc.t('recentTransactions'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.bgDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...entries.take(5).map((entry) => Card(
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: _getTypeColor(entry.type).withOpacity(0.2),
                            child: Icon(_getTypeIcon(entry.type),
                                color: _getTypeColor(entry.type), size: 18),
                          ),
                          title: Text(
                            '$currencySymbol${entry.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${entry.customerName ?? 'Counter'} - ${entry.date.day}/${entry.date.month}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  // ----------------------------------------------------- weekly chart data

  List<double> _getWeeklyData(List entries, DateTime now) {
    final data = <double>[];
    for (var i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayTotal = entries
          .where((e) =>
              e.date.day == day.day &&
              e.date.month == day.month &&
              e.date.year == day.year)
          .fold(0.0, (s, e) => s + e.amount);
      data.add(dayTotal);
    }
    return data;
  }

  // ----------------------------------------------------- smart insights

  Widget _buildInsightCard({
    required String icon,
    required String message,
    required Color color,
    required bool isDark,
    String? actionText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.bgDark,
              ),
            ),
          ),
          if (actionText != null)
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------- stat cards

  Widget _buildStatCard(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'KhataHandwriting',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------- weekly bar chart

  Widget _buildWeeklyChart(List<double> data, String symbol, bool isDark) {
    final maxVal = data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
              .withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final height = (data[i] / maxVal) * 100;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (data[i] > 0)
                Text(
                  '${data[i].toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 8,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 2),
              Container(
                width: 24,
                height: height.clamp(4.0, 100.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                days[i],
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ----------------------------------------------------- payment breakdown

  Widget _buildPaymentBreakdown(
      List<(double, Color, String)> data, double total, bool isDark) {
    if (total == 0) total = 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
              .withOpacity(0.2),
        ),
      ),
      child: Column(
        children: data.map((d) {
          final pct = (d.$1 / total * 100).clamp(0, 100);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: d.$2,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    d.$3,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : AppColors.bgDark,
                    ),
                  ),
                ),
                // Progress bar
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: d.$2.withOpacity(0.2),
                      color: d.$2,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: d.$2,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ----------------------------------------------------- section title

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.bgDark,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------- report card (existing)

  Widget _buildReportCard(
    BuildContext context, {
    required String title,
    required double amount,
    required int count,
    required Color color,
    required IconData icon,
    required String currencySymbol,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 22,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$currencySymbol${amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '$count ${context.loc.t('transactions')}',
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
}
