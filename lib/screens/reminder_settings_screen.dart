// =============================================================================
// Note Counter Pro - Reminder Settings Screen
// =============================================================================
// User can configure:
//   - Enable/disable scheduled reminders
//   - Frequency: daily/weekly/monthly
//   - Day of week/month
//   - Time
//   - Pending-only or all customers
//   - Default template (Friendly/Formal/Strict)
//   - Test notification
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../utils/app_localizations.dart';
import '../utils/constants.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  DateTime? _nextReminder;

  @override
  void initState() {
    super.initState();
    _loadNextReminder();
    NotificationService().init();
  }

  Future<void> _loadNextReminder() async {
    final t = await NotificationService().getNextReminderTime();
    if (mounted) {
      setState(() {
        _nextReminder = t;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final loc = context.loc;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('reminderSettings')),
      ),
      body: ListView(
        children: [
          // === ENABLE REMINDERS ===
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active,
                color: AppColors.primary),
            title: Text(loc.t('enableReminders'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(loc.t('enableRemindersDesc')),
            value: storage.reminderEnabled,
            onChanged: (value) async {
              setState(() {});
              await storage.setReminderEnabled(value);
              if (value) {
                // Request permission first
                await NotificationService().requestPermissions();
                await _reschedule(storage);
              } else {
                await NotificationService().cancelReminder();
              }
              _loadNextReminder();
            },
          ),

          if (storage.reminderEnabled) ...[
            const Divider(),

            // === FREQUENCY ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(loc.t('frequency'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            RadioListTile<String>(
              value: 'daily',
              groupValue: storage.reminderFrequency,
              onChanged: (v) async {
                await storage.setReminderFrequency(v!);
                await _reschedule(storage);
              },
              title: Text(loc.t('daily')),
            ),
            RadioListTile<String>(
              value: 'weekly',
              groupValue: storage.reminderFrequency,
              onChanged: (v) async {
                await storage.setReminderFrequency(v!);
                await _reschedule(storage);
              },
              title: Text(loc.t('weekly')),
            ),
            RadioListTile<String>(
              value: 'monthly',
              groupValue: storage.reminderFrequency,
              onChanged: (v) async {
                await storage.setReminderFrequency(v!);
                await _reschedule(storage);
              },
              title: Text(loc.t('monthly')),
            ),

            // === DAY (for weekly/monthly) ===
            if (storage.reminderFrequency != 'daily')
              ListTile(
                leading: const Icon(Icons.calendar_today,
                    color: AppColors.info),
                title: Text(loc.t('reminderDay')),
                trailing: DropdownButton<int>(
                  value: storage.reminderDay,
                  items: _buildDayDropdownItems(storage.reminderFrequency),
                  onChanged: (v) async {
                    if (v == null) return;
                    await storage.setReminderDay(v);
                    await _reschedule(storage);
                  },
                ),
              ),

            // === TIME ===
            ListTile(
              leading: const Icon(Icons.access_time, color: AppColors.success),
              title: Text(loc.t('reminderTime')),
              trailing: Text(
                '${storage.reminderHour.toString().padLeft(2, '0')}:${storage.reminderMinute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                      hour: storage.reminderHour,
                      minute: storage.reminderMinute),
                );
                if (picked != null) {
                  await storage.setReminderHour(picked.hour);
                  await storage.setReminderMinute(picked.minute);
                  await _reschedule(storage);
                }
              },
            ),

            // === PENDING ONLY ===
            SwitchListTile(
              secondary: const Icon(Icons.filter_list, color: AppColors.warning),
              title: Text(loc.t('pendingOnly')),
              subtitle: Text(loc.t('pendingOnlyDesc')),
              value: storage.reminderPendingOnly,
              onChanged: (value) async {
                await storage.setReminderPendingOnly(value);
                await _reschedule(storage);
              },
            ),

            const Divider(),

            // === NEXT REMINDER INFO ===
            if (_nextReminder != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.t('nextReminder'),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          Text(
                            _formatDateTime(_nextReminder!),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // === TEST NOTIFICATION ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await NotificationService().showTestNotification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.t('testSent'))),
                    );
                  }
                },
                icon: const Icon(Icons.notifications),
                label: Text(loc.t('sendTestNotification')),
              ),
            ),

            const SizedBox(height: 24),

            // === DEFAULT TEMPLATE ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(loc.t('defaultTemplate'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            ...ReminderService()
                .getTemplates(storage.languageCode)
                .map((t) => RadioListTile<String>(
                      value: t['key']!,
                      groupValue: storage.defaultReminderTemplate,
                      onChanged: (v) async {
                        if (v == null) return;
                        await storage.setDefaultReminderTemplate(v);
                      },
                      title: Text(t['name']!),
                      subtitle: Text(t['desc']!),
                    )),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<DropdownMenuItem<int>> _buildDayDropdownItems(String frequency) {
    if (frequency == 'monthly') {
      return List.generate(28, (i) {
        return DropdownMenuItem(
          value: i + 1,
          child: Text('Day ${i + 1}'),
        );
      });
    }
    // weekly
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      return DropdownMenuItem(
        value: i + 1,
        child: Text(days[i]),
      );
    });
  }

  String _formatDateTime(DateTime dt) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$dayName, ${dt.day} $monthName at $hour:$minute';
  }

  Future<void> _reschedule(StorageService storage) async {
    // Count pending customers
    final customers = storage.customers;
    final pendingCustomers = storage.reminderPendingOnly
        ? customers.where((c) => c.balance.abs() > 0.01).toList()
        : customers;
    final totalPending = pendingCustomers.fold<double>(
        0, (sum, c) => sum + c.balance.abs());

    await NotificationService().scheduleReminder(
      frequency: storage.reminderFrequency,
      day: storage.reminderDay,
      hour: storage.reminderHour,
      minute: storage.reminderMinute,
      pendingCount: pendingCustomers.length,
      totalPending: totalPending,
    );
    _loadNextReminder();
  }
}
