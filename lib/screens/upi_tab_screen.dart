// =============================================================================
// Note Counter Pro - Smart Pay Tab (Scan QR Only) — v3.36.0
// =============================================================================
// Smart Pay tab wrapper:
//   - Free users  → premium lock screen (unchanged)
//   - Premium users → UpiToolsScreen (scan-only)
//
// The actual scan UI lives in UpiToolsScreen. This file only handles the
// premium gate so the tab can be embedded in the bottom-nav scaffold.
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

    // Free users see lock screen
    if (!PremiumService().isPremium) {
      return _buildLockScreen(isDark, loc, theme);
    }

    // Premium users see the scan-only UpiToolsScreen
    return const UpiToolsScreen();
  }

  // === Lock Screen (Free Users) ===
  Widget _buildLockScreen(bool isDark, AppLocalizations loc, ThemeData theme) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                  child: const Icon(Icons.lock, size: 50, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 24),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                Text(
                  loc.t('upiPremiumLockDesc'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    },
                    icon: const Icon(Icons.workspace_premium, size: 22),
                    label: Text(loc.t('getPremium'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
}
