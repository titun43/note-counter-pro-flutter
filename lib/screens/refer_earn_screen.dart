// =============================================================================
// Note Counter Pro - Refer & Earn Screen
// =============================================================================
// Premium feature: User shares referral code, new user enters it.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/referral_service.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'premium_screen.dart';

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final message = ReferralService().getShareMessage();
    await Share.share(message, subject: 'Note Counter Pro — Referral');
  }

  Future<void> _copyCode() async {
    final code = ReferralService().referralCode ?? '';
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Referral code copied!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isSubmitting = true);
    final success = await ReferralService().submitReferralCode(code);
    setState(() => _isSubmitting = false);

    if (success) {
      _codeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Referral code submitted! Premium will be activated after verification.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      setState(() {}); // refresh history
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Invalid code. Format: NCP-XXXXXX. You cannot refer yourself.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isPremium = PremiumService().isPremium;
    final code = ReferralService().referralCode ?? '';
    final history = ReferralService().history;
    final pendingCount = ReferralService().pendingCount;
    final verifiedCount = ReferralService().verifiedCount;

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('referEarn'))),
      body: !isPremium
          ? _buildPremiumRequired(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.card_giftcard,
                            size: 56, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          loc.t('referEarnTitle'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.t('referEarnDesc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Referral code card
                  Text(
                    loc.t('referEarnYourCode'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3), width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          code,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 2,
                          ),
                        ),
                        IconButton(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy, color: AppColors.primary),
                          tooltip: loc.t('referEarnCopy'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Share button
                  FilledButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share),
                    label: Text(
                      loc.t('referEarnShare'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.hourglass_top,
                          color: AppColors.warning,
                          label: loc.t('referEarnPending'),
                          value: '$pendingCount',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.verified,
                          color: AppColors.success,
                          label: loc.t('referEarnVerified'),
                          value: '$verifiedCount',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Enter referral code (for users who were referred)
                  Text(
                    loc.t('referEarnEnterCode'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            hintText: 'NCP-XXXXXX',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.card_giftcard),
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submitCode,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // History
                  if (history.isNotEmpty) ...[
                    Text(
                      loc.t('referEarnHistory'),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...history.map((h) => Card(
                          child: ListTile(
                            leading: Icon(
                              h['status'] == 'verified'
                                  ? Icons.verified
                                  : Icons.hourglass_top,
                              color: h['status'] == 'verified'
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            title: Text(h['code'] ?? ''),
                            subtitle: Text(
                              'Status: ${h['status'] ?? 'pending'}\n'
                              'Submitted: ${h['submittedAt'] ?? ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                            isThreeLine: true,
                          ),
                        )),
                  ],

                  // How it works
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.t('referEarnHowTitle'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.t('referEarnHow'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPremiumRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium,
                size: 80, color: Color(0xFFD4AF37)),
            const SizedBox(height: 16),
            Text(
              context.loc.t('referEarnPremiumRequired'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.loc.t('cloudBackupPremiumDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
              icon: const Icon(Icons.workspace_premium),
              label: Text(context.loc.t('premiumUpgradeTitle')),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
