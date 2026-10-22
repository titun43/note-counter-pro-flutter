// =============================================================================
// Note Counter Pro - Send Reminder to All Dialog (Idea 4)
// =============================================================================
// Opens WhatsApp/SMS for each pending customer one by one.
// User taps "Send" in WhatsApp, then taps "Next" here to move on.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import '../utils/app_localizations.dart';
import '../utils/constants.dart';

class SendReminderToAllDialog extends StatefulWidget {
  final List<Customer> customers;
  final String channel; // 'whatsapp' or 'sms'

  const SendReminderToAllDialog({
    super.key,
    required this.customers,
    required this.channel,
  });

  @override
  State<SendReminderToAllDialog> createState() =>
      _SendReminderToAllDialogState();
}

class _SendReminderToAllDialogState extends State<SendReminderToAllDialog> {
  int _currentIndex = 0;
  bool _currentOpened = false;

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final loc = context.loc;
    final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);
    final total = widget.customers.length;

    if (_currentIndex >= total) {
      // All done
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Text(loc.t('allRemindersSent')),
          ],
        ),
        content: Text(loc.t('remindersOpenedCount').replaceAll('{n}', '$total')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('done')),
          ),
        ],
      );
    }

    final customer = widget.customers[_currentIndex];
    final balance = customer.balance.abs();
    final hasPhone = customer.phone != null && customer.phone!.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.send, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${loc.t('sendingReminder')} (${_currentIndex + 1}/$total)',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentIndex + (_currentOpened ? 1 : 0)) / total,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 16),

          // Current customer info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$symbol${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
                if (customer.phone != null && customer.phone!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('📞 ${customer.phone}',
                        style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),

          if (!hasPhone) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(loc.t('noPhoneSkip'),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Text(
            _currentOpened
                ? loc.t('tapSendInWhatsApp')
                : loc.t('openWhatsAppFor'),
            style: TextStyle(
                fontSize: 13,
                color: _currentOpened ? AppColors.success : Colors.grey[700]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.t('cancel')),
        ),
        if (!hasPhone)
          FilledButton(
            onPressed: _next,
            child: Text(loc.t('skip')),
          )
        else if (!_currentOpened)
          FilledButton.icon(
            onPressed: _openCurrent,
            icon: const Icon(Icons.open_in_new),
            label: Text(widget.channel == 'whatsapp'
                ? loc.t('openWhatsApp')
                : loc.t('openSms')),
          )
        else
          FilledButton.icon(
            onPressed: _next,
            icon: const Icon(Icons.arrow_forward),
            label: Text(loc.t('nextCustomer')),
          ),
      ],
    );
  }

  Future<void> _openCurrent() async {
    final storage = context.read<StorageService>();
    final symbol = AppConstants.getCurrencySymbol(storage.defaultCurrency);
    final customer = widget.customers[_currentIndex];

    if (widget.channel == 'whatsapp') {
      await ReminderService().openWhatsAppReminder(
        customer: customer,
        balance: customer.balance.abs(),
        currencySymbol: symbol,
        storage: storage,
      );
    } else {
      await ReminderService().openSmsReminder(
        customer: customer,
        balance: customer.balance.abs(),
        currencySymbol: symbol,
        storage: storage,
      );
    }

    if (mounted) {
      setState(() {
        _currentOpened = true;
      });
    }
  }

  void _next() {
    setState(() {
      _currentIndex++;
      _currentOpened = false;
    });
  }
}
