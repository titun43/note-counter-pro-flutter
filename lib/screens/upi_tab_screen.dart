// =============================================================================
// Note Counter Pro - UPI Tab Screen
// =============================================================================
// Wrapper around UpiToolsScreen with premium lock for free users.
//
// Free users see: A beautiful lock screen explaining UPI is a premium
// feature, with a "Get Premium" CTA.
//
// Premium users see: UpiToolsScreen (Generate QR + Scan QR).
// =============================================================================

import 'package:flutter/material.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'premium_screen.dart';
import 'upi_tools_screen.dart';

class UpiTabScreen extends StatefulWidget {
  const UpiTabScreen({super.key});

  @override
  State<UpiTabScreen> createState() => _UpiTabScreenState();
}

class _UpiTabScreenState extends State<UpiTabScreen> {
  @override
  void initState() {
    super.initState();
    // Listen to PremiumService so that when premium status changes
    // (e.g. after purchase, or trial granted), this widget rebuilds
    // and shows the UpiToolsScreen instead of the lock.
    PremiumService().addListener(_onPremiumChanged);
  }

  @override
  void dispose() {
    PremiumService().removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;

    // Premium users see the actual UPI Tools screen
    if (PremiumService().isPremium) {
      return const UpiToolsScreen();
    }

    // Free users see the premium lock screen
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        top: false, // MainScaffold handles top padding for banner ad
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock icon with gold gradient circle
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock,
                    size: 50,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 24),

                // UPI Tools title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFFD4AF37), size: 28),
                    const SizedBox(width: 8),
                    Text(
                      loc.t('upiTools'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // PRO badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD4AF37)),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Description
                Text(
                  loc.t('upiPremiumLockDesc'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Features list
                _buildFeatureRow(Icons.qr_code, loc.t('generateQr')),
                _buildFeatureRow(Icons.camera_alt, loc.t('scanQr')),
                _buildFeatureRow(Icons.send, loc.t('sendMoney')),
                _buildFeatureRow(Icons.history, loc.t('scanHistory')),
                const SizedBox(height: 32),

                // Get Premium button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PremiumScreen()),
                      );
                    },
                    icon: const Icon(Icons.workspace_premium, size: 22),
                    label: Text(
                      loc.t('getPremium'),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Try free trial hint
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PremiumScreen()),
                    );
                  },
                  child: Text(
                    loc.t('tryFreeWithAd'),
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}
