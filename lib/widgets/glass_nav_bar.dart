// =============================================================================
// Note Counter Pro - Glass Navigation Bar (Floating Glassmorphism)
// =============================================================================
// Custom bottom navigation bar with:
//   - Glass effect (semi-transparent + blur)
//   - Floating (margin from edges + bottom)
//   - No border
//   - 64px height (compact)
//   - Active tab = gold gradient pill
//   - 5 tabs: Counter, Khata, Smart Pay, Pro Tools, Settings
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';

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
        icon: Icons.construction_outlined,
        activeIcon: Icons.construction,
        label: 'Tools',
        color: AppColors.info,
      ),
      _NavBarItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings',
        color: AppColors.textSecondary,
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
                    onTap: () => onDestinationSelected(index),
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
              size: 22,
              color: const Color(0xFF1A1A2E),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: const TextStyle(
                fontSize: 10,
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
              size: 22,
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
            fontSize: 10,
            fontWeight: FontWeight.w500,
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
