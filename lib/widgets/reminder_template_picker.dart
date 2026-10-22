// =============================================================================
// Note Counter Pro - Reminder Template Picker (Idea 8)
// =============================================================================
// Shows a bottom sheet to pick template (Friendly/Formal/Strict)
// before sending reminder.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';
import '../utils/constants.dart';
import '../models/customer.dart';

class ReminderTemplatePicker extends StatelessWidget {
  final Customer customer;
  final double balance;
  final String currencySymbol;
  final String channel; // 'whatsapp', 'sms', 'qr'

  const ReminderTemplatePicker({
    super.key,
    required this.customer,
    required this.balance,
    required this.currencySymbol,
    required this.channel,
  });

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final loc = context.loc;
    final language = storage.languageCode;
    final templates = ReminderService().getTemplates(language);
    final defaultTemplate = storage.defaultReminderTemplate;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.message, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${loc.t('sendReminderTo')} ${customer.name}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currencySymbol${balance.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary),
          ),
          const Divider(height: 24),
          Text(loc.t('chooseTemplate'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...templates.map((t) {
            final key = t['key']!;
            final isDefault = key == defaultTemplate;
            return ListTile(
              leading: Icon(
                isDefault ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isDefault ? AppColors.primary : Colors.grey,
              ),
              title: Text(t['name']!),
              subtitle: Text(t['desc']!),
              onTap: () => _sendWithTemplate(context, key),
            );
          }),
          const Divider(height: 24),
          // Quick action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendWithTemplate(context, defaultTemplate),
                  icon: const Icon(Icons.send),
                  label: Text(loc.t('sendWithDefault')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _sendWithTemplate(BuildContext context, String templateKey) async {
    Navigator.pop(context); // close bottom sheet
    final storage = context.read<StorageService>();

    if (channel == 'qr') {
      await ReminderService().shareQrWithMessage(
        customer: customer,
        balance: balance,
        currencySymbol: currencySymbol,
        storage: storage,
      );
      return;
    }

    bool success;
    if (channel == 'whatsapp') {
      success = await ReminderService().openWhatsAppReminder(
        customer: customer,
        balance: balance,
        currencySymbol: currencySymbol,
        storage: storage,
        templateKey: templateKey,
      );
    } else {
      success = await ReminderService().openSmsReminder(
        customer: customer,
        balance: balance,
        currencySymbol: currencySymbol,
        storage: storage,
        templateKey: templateKey,
      );
    }

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.t('noPhoneCustomer'))),
      );
    }
  }
}

/// Helper to show the template picker as a bottom sheet.
Future<void> showReminderTemplatePicker({
  required BuildContext context,
  required Customer customer,
  required double balance,
  required String currencySymbol,
  required String channel,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ReminderTemplatePicker(
      customer: customer,
      balance: balance,
      currencySymbol: currencySymbol,
      channel: channel,
    ),
  );
}
