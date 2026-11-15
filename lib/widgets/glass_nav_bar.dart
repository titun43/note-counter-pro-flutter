// =============================================================================
// Note Counter Pro - Glass Navigation Bar (Floating Glassmorphism)
// =============================================================================
// Custom bottom navigation bar with:
//   - Glass effect (semi-transparent + blur)
//   - Floating (margin from edges + bottom)
//   - No border
//   - 64px height (compact)
//   - Active tab = gold gradient pill
//   - 5 tabs: Counter, Khata, Smart Pay, Bills, হিসাব ভাগ (Group Split)
// =============================================================================
// Tools moved OUT of the nav bar (v3.61.0) — accessible via the toolbox
// icon (🧰) in the top bar of every main tab screen, beside the gear (⚙️)
// Settings icon. Group Split (হিসাব ভাগ) takes the 5th nav slot because it
// is a flagship consumer feature (split bills with friends) that benefits
// from direct visibility. Settings remains via the gear icon (⚙️) in the
// top bar. Bills & Invoices is a top-level tab (was Khata ⋮ menu, premium).
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';

class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tabs = [
      _NavBarItem(
        icon: Icons.calculate_outlined,
        activeIcon: Icons.calculate,
        label: 'Counter',
        color: AppColors.primary,
      ),
      _NavBarItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet,
        label: 'Khata',
        color: AppColors.success,
      ),
      _NavBarItem(
        icon: Icons.bolt_outlined,
        activeIcon: Icons.bolt,
        label: 'Smart Pay',
        color: const Color(0xFFD4AF37),
        isPremium: true,
      ),
      _NavBarItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'Bills',
        color: const Color(0xFF9333EA),
        isPremium: true,
      ),
      _NavBarItem(
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups,
        label: context.loc.t('groupSplitTab'),
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF16213E).withOpacity(0.8)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final isActive = index == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Professional: navigation is silent (haptic only).
                      // Sound only on important actions (save/delete/etc).
                      HapticFeedback.selectionClick();
                      onDestinationSelected(index);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: _buildTabItem(tab, isActive, isDark, theme),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    _NavBarItem tab,
    bool isActive,
    bool isDark,
    ThemeData theme,
  ) {
    // Active tab = gold gradient pill background
    if (isActive) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.activeIcon,
              size: 24,
              color: const Color(0xFF1A1A2E),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Inactive tab = just icon + label
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              tab.icon,
              size: 24,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
            if (tab.isPremium && !PremiumService().isPremium)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock,
                    size: 7,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          tab.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _NavBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  final bool isPremium;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
    this.isPremium = false,
  });
}
