// =============================================================================
// Note Counter Pro - Premium Upgrade Screen
// =============================================================================
// Shows multiple premium plans + buy button (Google Play IAP).
// Plans: Monthly (₹49), Yearly (₹299), Lifetime (₹499)
// =============================================================================

import 'package:flutter/material.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = false;
  String? _selectedPlan;

  Future<void> _purchase(String productId) async {
    setState(() {
      _isLoading = true;
      _selectedPlan = productId;
    });
    final started = await PremiumService().purchasePlan(productId);
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not start purchase. Please try again or check your Google Play connection.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);

    if (PremiumService().isPremium && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Premium activated! Enjoy ad-free experience.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    await PremiumService().restorePurchases();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);

    if (PremiumService().isPremium && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Premium restored!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous purchases found.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isPremium = PremiumService().isPremium;

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('premium'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),

            // Hero icon
            Container(
              width: 90,
              height: 90,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFE6C757)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.workspace_premium,
                  size: 48, color: Colors.white),
            ),

            Text(
              loc.t('premiumTitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.t('premiumSubtitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 24),

            // Benefits
            _BenefitTile(icon: Icons.block, color: AppColors.danger,
                title: loc.t('premiumBenefit1Title'), subtitle: loc.t('premiumBenefit1Sub')),
            _BenefitTile(icon: Icons.fingerprint, color: AppColors.success,
                title: 'App Lock (Fingerprint/PIN)', subtitle: 'Secure your app with biometric lock'),
            _BenefitTile(icon: Icons.record_voice_over, color: AppColors.info,
                title: 'Voice Announcement', subtitle: 'Voice reads out totals on save'),
            _BenefitTile(icon: Icons.support_agent, color: AppColors.primary,
                title: 'Priority Support', subtitle: 'Direct email support'),
            _BenefitTile(icon: Icons.update, color: AppColors.accentColor ?? AppColors.primary,
                title: loc.t('premiumBenefit3Title'), subtitle: loc.t('premiumBenefit3Sub')),

            const SizedBox(height: 24),

            if (isPremium) ...[
              // Active state
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                    const SizedBox(height: 8),
                    Text(loc.t('premiumActive'),
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: AppColors.success)),
                    const SizedBox(height: 4),
                    Text(loc.t('premiumActiveSub'),
                        textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ] else ...[
              // Plan cards
              ...PremiumService.plans.map((plan) => _PlanCard(
                    plan: plan,
                    isLoading: _isLoading && _selectedPlan == plan['id'],
                    onTap: () => _purchase(plan['id'] as String),
                  )),

              const SizedBox(height: 12),

              // Restore
              Center(
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _restore,
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(loc.t('premiumRestore')),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(loc.t('premiumNote'),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isLoading;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBestValue = plan['badge'] != null;
    final isLifetime = plan['id'] == PremiumService.productIdLifetime;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBestValue ? const Color(0xFFD4AF37) : Colors.grey[300]!,
          width: isBestValue ? 2 : 1,
        ),
        color: isBestValue ? const Color(0xFFD4AF37).withOpacity(0.05) : null,
      ),
      child: Stack(
        children: [
          if (isBestValue)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8941F)]),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  plan['badge'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan['name'] as String,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(plan['description'] as String,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(plan['price'] as String,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isBestValue ? const Color(0xFFD4AF37) : AppColors.primary,
                              )),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(plan['period'] as String,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 36,
                        child: FilledButton(
                          onPressed: isLoading ? null : onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: isBestValue
                                ? const Color(0xFFD4AF37)
                                : AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: isLoading
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _BenefitTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
