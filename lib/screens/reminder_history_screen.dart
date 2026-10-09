// =============================================================================
// Note Counter Pro - Reminder History Screen (Idea 7)
// =============================================================================
// Shows when reminders were sent to which customers.
// =============================================================================

import 'package:flutter/material.dart';
import '../widgets/banner_ad_widget.dart';
import 'package:provider/provider.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';
import '../utils/constants.dart';

class ReminderHistoryScreen extends StatefulWidget {
  const ReminderHistoryScreen({super.key});

  @override
  State<ReminderHistoryScreen> createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await ReminderService().getReminderHistory();
    if (mounted) {
      setState(() {
        _history = h;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final loc = context.loc;
    final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('reminderHistory')),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: loc.t('clearHistory'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(loc.t('clearHistory')),
                    content: Text(loc.t('clearHistoryConfirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(loc.t('cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(loc.t('clear')),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ReminderService().clearHistory();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 80,
                          color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(loc.t('noReminderHistory'),
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final entry = _history[index];
                    final name = entry['customerName'] as String? ?? 'Unknown';
                    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
                    final timestampStr = entry['timestamp'] as String?;
                    DateTime? dt;
                    if (timestampStr != null) {
                      try {
                        dt = DateTime.parse(timestampStr);
                      } catch (_) {}
                    }
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.success.withOpacity(0.15),
                          child: const Icon(Icons.check,
                              color: AppColors.success),
                        ),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          dt != null
                              ? '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                              : '',
                          style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 12),
                        ),
                        trailing: Text(
                          '$symbol${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }
}
