// =============================================================================
// Note Counter Pro - Send Money Screen (UPI)
// =============================================================================
// Enter UPI ID + amount → launch UPI deep link → user pays in their UPI app.
//
// Flow:
//   1. User enters UPI ID (or comes pre-filled from Saved UPI)
//   2. User enters Payee Name + Amount + Note (optional)
//   3. Click "Pay Now" → builds upi://pay?pa=...&pn=...&am=...&tn=...
//   4. System shows UPI app chooser (PhonePe / GPay / Paytm / BHIM)
//   5. User completes payment in their UPI app
//   6. Returns to Note Counter Pro
//
// IMPORTANT: We cannot detect whether payment succeeded — UPI deep links
// do not return success/failure to the calling app. The user must verify
// in their UPI app's transaction history.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admob_service.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import '../models/saved_upi.dart';
import '../services/saved_upi_service.dart';

class SendMoneyScreen extends StatefulWidget {
  /// Optional pre-filled UPI ID (when navigating from Saved UPI list).
  final SavedUpi? prefillUpi;

  const SendMoneyScreen({super.key, this.prefillUpi});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _upiIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillUpi != null) {
      _upiIdController.text = widget.prefillUpi!.upiId;
      _nameController.text = widget.prefillUpi!.name;
    }
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _payNow() async {
    final upiId = _upiIdController.text.trim();
    final name = _nameController.text.trim();
    final amountStr = _amountController.text.trim();
    final note = _noteController.text.trim();
    final loc = context.loc;

    if (upiId.isEmpty) {
      _showError(loc.t('enterUpiId'));
      return;
    }
    if (!upiId.contains('@')) {
      _showError(loc.t('invalidUpiId'));
      return;
    }
    if (amountStr.isEmpty) {
      _showError(loc.t('enterAmount'));
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showError(loc.t('invalidAmount'));
      return;
    }

    setState(() => _isLaunching = true);

    // Build UPI deep link
    // pa = payee address (UPI ID)
    // pn = payee name
    // am = amount
    // tn = transaction note
    // cu = currency (INR)
    final params = <String>[];
    params.add('pa=$upiId');
    if (name.isNotEmpty) params.add('pn=${Uri.encodeComponent(name)}');
    params.add('am=${amount.toStringAsFixed(2)}');
    params.add('cu=INR');
    if (note.isNotEmpty) params.add('tn=${Uri.encodeComponent(note)}');

    final upiUrl = 'upi://pay?${params.join('&')}';
    debugPrint('SendMoney: launching UPI URL = $upiUrl');

    // Show interstitial BEFORE launching UPI app (natural break point)
    AdMobService.showInterstitial();

    try {
      final uri = Uri.parse(upiUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        // Try platformDefault as fallback
        final launched2 = await launchUrl(uri);
        if (!launched2 && mounted) {
          _showError(loc.t('noUpiAppFound'));
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('${loc.t('upiLaunchFailed')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _saveAsContact() {
    final upiId = _upiIdController.text.trim();
    final name = _nameController.text.trim();
    final loc = context.loc;

    if (upiId.isEmpty || name.isEmpty) {
      _showError(loc.t('fillUpiAndName'));
      return;
    }
    Navigator.pop(context, {
      'upiId': upiId,
      'name': name,
      'phone': _noteController.text.trim().isEmpty ? null : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: Text(loc.t('sendMoney')),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero icon
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send,
                  size: 40,
                  color: Color(0xFF1A1A2E),
                ),
              ),

              // UPI ID input
              _buildLabel(loc.t('upiId'), required: true),
              TextField(
                controller: _upiIdController,
                decoration: InputDecoration(
                  hintText: 'example@oksbi',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Payee Name input
              _buildLabel(loc.t('payeeName')),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: loc.t('payeeName'),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Amount input
              _buildLabel(loc.t('amount'), required: true),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),

              // Note input (optional)
              _buildLabel(loc.t('noteOptional')),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: loc.t('noteHint'),
                  prefixIcon: const Icon(Icons.note_outlined),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: isDark ? AppColors.bgCardDark : AppColors.bgCard,
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 24),

              // Pay Now button
              FilledButton.icon(
                onPressed: _isLaunching ? null : _payNow,
                icon: _isLaunching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 22),
                label: Text(
                  _isLaunching ? loc.t('launching') : loc.t('payNow'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Save as Contact button (only if name+upi are filled and not pre-filled)
              if (widget.prefillUpi == null)
                OutlinedButton.icon(
                  onPressed: _saveAsContact,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(loc.t('saveAsContact')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.info),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Info note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.blue : Colors.blue[50])!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.t('sendMoneyInfo'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
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

  Widget _buildLabel(String text, {bool required = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
