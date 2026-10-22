// =============================================================================
// Note Counter Pro - Premium Upgrade Screen
// =============================================================================
// Shows premium benefits + buy button (Google Play IAP).
// Product ID: 'premium_lifetime' (one-time, ad-free forever)
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

  Future<void> _purchase() async {
    setState(() => _isLoading = true);
    final started = await PremiumService().purchasePremium();
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
    // Wait briefly to let purchaseStream update isPremium
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);

    // If premium now, show success + close
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
        const SnackBar(
          content: Text('No previous purchases found.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isPremium = PremiumService().isPremium;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('premium')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // === Hero Icon ===
            Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFE6C757)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.workspace_premium,
                  size: 56, color: Colors.white),
            ),

            // === Title ===
            Text(
              loc.t('premiumTitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.t('premiumSubtitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 32),

            // === Benefits List ===
            _BenefitTile(
              icon: Icons.block,
              color: AppColors.danger,
              title: loc.t('premiumBenefit1Title'),
              subtitle: loc.t('premiumBenefit1Sub'),
            ),
            _BenefitTile(
              icon: Icons.support_agent,
              color: AppColors.success,
              title: loc.t('premiumBenefit2Title'),
              subtitle: loc.t('premiumBenefit2Sub'),
            ),
            _BenefitTile(
              icon: Icons.update,
              color: AppColors.info,
              title: loc.t('premiumBenefit3Title'),
              subtitle: loc.t('premiumBenefit3Sub'),
            ),
            _BenefitTile(
              icon: Icons.cloud_done,
              color: AppColors.primary,
              title: loc.t('premiumBenefit4Title'),
              subtitle: loc.t('premiumBenefit4Sub'),
            ),

            const SizedBox(height: 32),

            // === Price + Buy Button (or Active badge) ===
            if (isPremium) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      loc.t('premiumActive'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.t('premiumActiveSub'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Price card
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹499',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        loc.t('premiumOneTime'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.t('premiumLifetimeNote'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 24),

              // Buy button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _purchase,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.workspace_premium),
                  label: Text(
                    loc.t('premiumBuyNow'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Restore purchases
              TextButton.icon(
                onPressed: _isLoading ? null : _restore,
                icon: const Icon(Icons.restore, size: 18),
                label: Text(loc.t('premiumRestore')),
              ),
            ],

            const SizedBox(height: 24),

            // === Note ===
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.t('premiumNote'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
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
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
