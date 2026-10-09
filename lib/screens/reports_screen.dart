import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportCard(
            context,
            title: 'This Week',
            amount: totalThisWeek,
            count: thisWeek.length,
            color: AppColors.info,
            icon: Icons.date_range,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            context,
            title: 'This Month',
            amount: totalThisMonth,
            count: thisMonth.length,
            color: AppColors.primary,
            icon: Icons.calendar_month,
          ),
          const SizedBox(height: 12),
          _buildReportCard(
            context,
            title: 'All Time',
            amount: totalAllTime,
            count: entries.length,
            color: AppColors.success,
            icon: Icons.all_inclusive,
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Transactions',
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
                    'No transactions yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            )
          else
            ...entries.take(10).map((entry) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getTypeColor(entry.type),
                  child: Icon(_getTypeIcon(entry.type), color: Colors.white),
                ),
                title: Text('₹${entry.amount.toStringAsFixed(2)}'),
                subtitle: Text(
                  '${entry.customerName ?? 'Counter'} - ${entry.date.day}/${entry.date.month}/${entry.date.year}',
                ),
                trailing: Text(entry.currency),
              ),
            )),
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
}
