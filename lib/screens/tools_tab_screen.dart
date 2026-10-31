// =============================================================================
// Note Counter Pro - Tools Tab Screen
// =============================================================================
// Hub for all utility tools:
//   - Calculators (Standard / Scientific / Programmer / Date)
//   - Converters (Currency / Unit / etc.)
//   - Printer (Bluetooth thermal printer)
//
// This screen wraps CalculatorScreen which already has modes + converters
// built-in, and adds a Printer card for easy access.
// =============================================================================

import 'package:flutter/material.dart';
import '../services/admob_service.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';
import 'calculator_screen.dart';
import 'printer_screen.dart';
import 'premium_screen.dart';
import 'qr_generator_screen.dart';
import 'qr_scanner_screen.dart';
import 'barcode_generator_screen.dart';
import 'upi_generate_screen.dart';
import 'send_money_screen.dart';
import 'saved_upi_screen.dart';
import 'converter_screen.dart';
import 'inventory_screen.dart';

class ToolsTabScreen extends StatefulWidget {
  final String currencyCode;

  const ToolsTabScreen({super.key, required this.currencyCode});

  @override
  State<ToolsTabScreen> createState() => _ToolsTabScreenState();
}

class _ToolsTabScreenState extends State<ToolsTabScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = context.loc;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        top: false, // MainScaffold handles top padding for banner ad
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calculators section
              _buildSectionHeader(loc.t('calculators'), Icons.calculate, theme),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.functions,
                iconColor: AppColors.info,
                title: loc.t('calculator'),
                subtitle: loc.t('calculatorDesc'),
                onTap: () {
                  AdMobService.showInterstitial();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalculatorScreen(
                        currencyCode: widget.currencyCode,
                      ),
                    ),
                  );
                },
                theme: theme,
                isDark: isDark,
              ),
              _buildToolCard(
                icon: Icons.account_balance,
                iconColor: const Color(0xFFEC4899),
                title: loc.t('emiCalculator'),
                subtitle: loc.t('emiCalculatorDesc'),
                onTap: () {
                  AdMobService.showInterstitial();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalculatorScreen(
                        currencyCode: widget.currencyCode,
                        initialEmi: true,
                      ),
                    ),
                  );
                },
                theme: theme,
                isDark: isDark,
              ),
              _buildToolCard(
                icon: Icons.percent,
                iconColor: AppColors.warning,
                title: loc.t('gstCalculator'),
                subtitle: loc.t('gstCalculatorDesc'),
                onTap: () {
                  AdMobService.showInterstitial();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalculatorScreen(
                        currencyCode: widget.currencyCode,
                        initialGst: true,
                      ),
                    ),
                  );
                },
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 20),
              _buildSectionHeader(loc.t('qrBarcodeSection'), Icons.qr_code_scanner, theme),
              const SizedBox(height: 8),
              _buildToolCard(icon: Icons.qr_code_2, iconColor: AppColors.info, title: loc.t('qrGenerator'), subtitle: loc.t('qrGeneratorDesc'), onTap: () { AdMobService.showInterstitial(); Navigator.push(context, MaterialPageRoute(builder: (_) => const QrGeneratorScreen())); }, theme: theme, isDark: isDark),
              _buildToolCard(icon: Icons.qr_code_scanner, iconColor: AppColors.success, title: loc.t('qrScanner'), subtitle: loc.t('qrScannerDesc'), onTap: () { AdMobService.showInterstitial(); Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerScreen())); }, theme: theme, isDark: isDark),
              _buildToolCard(icon: Icons.view_quilt, iconColor: AppColors.warning, title: loc.t('barcodeGenerator'), subtitle: loc.t('barcodeGeneratorDesc'), onTap: () { AdMobService.showInterstitial(); Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeGeneratorScreen())); }, theme: theme, isDark: isDark),

              const SizedBox(height: 20),

              // Business section — Inventory Manager (NEW)
              _buildSectionHeader(loc.t('businessSection'), Icons.business_center, theme),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.inventory_2,
                iconColor: const Color(0xFFD4AF37),
                title: loc.t('inventoryManager'),
                subtitle: loc.t('inventoryManagerDesc'),
                onTap: () {
                  AdMobService.showInterstitial();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryScreen()),
                  );
                },
                theme: theme,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // UPI Tools section (moved from Smart Pay)
              _buildSectionHeader(loc.t('upiToolsSection'), Icons.bolt, theme),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.qr_code_2,
                iconColor: AppColors.primary,
                title: loc.t('upiGenerateQr'),
                subtitle: loc.t('upiGenerateQrDesc'),
                isPremium: true,
                onTap: () {
                  if (!PremiumService().isPremium) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  AdMobService.showInterstitial();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UpiGenerateScreen()));
                },
                theme: theme,
                isDark: isDark,
              ),
              _buildToolCard(
                icon: Icons.send,
                iconColor: AppColors.success,
                title: loc.t('upiSendMoney'),
                subtitle: loc.t('upiSendMoneyDesc'),
                isPremium: true,
                onTap: () {
                  if (!PremiumService().isPremium) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  AdMobService.showInterstitial();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SendMoneyScreen()));
                },
                theme: theme,
                isDark: isDark,
              ),
              _buildToolCard(
                icon: Icons.people,
                iconColor: const Color(0xFFEC4899),
                title: loc.t('upiSavedIds'),
                subtitle: loc.t('upiSavedIdsDesc'),
                isPremium: true,
                onTap: () {
                  if (!PremiumService().isPremium) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                    return;
                  }
                  AdMobService.showInterstitial();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedUpiScreen()));
                },
                theme: theme,
                isDark: isDark,
              ),

              // Converters section
              _buildSectionHeader(loc.t('converters'), Icons.swap_horiz, theme),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.currency_exchange,
                iconColor: AppColors.success,
                title: loc.t('currencyConverter'),
                subtitle: loc.t('currencyConverterDesc'),
                onTap: () {
                  AdMobService.showInterstitial();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConverterScreen(initialType: 0),
                    ),
                  );
                },
                theme: theme,
                isDark: isDark,
              ),
              _buildToolCard(
                icon: Icons.calendar_month,
                iconColor: AppColors.warning,
                title: loc.t('dateCalculator'),
                subtitle: loc.t('dateCalculatorDesc'),
                onTap: () {
                  AdMobService.showInterstitial();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalculatorScreen(
                        currencyCode: widget.currencyCode,
                        initialDateCalc: true,
                      ),
                    ),
                  );
                },
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // Hardware section
              _buildSectionHeader(loc.t('hardware'), Icons.print, theme),
              const SizedBox(height: 8),
              _buildToolCard(
                icon: Icons.print,
                iconColor: const Color(0xFFD4AF37),
                title: loc.t('printer'),
                subtitle: loc.t('printerDesc'),
                isPremium: true,
                onTap: () {
                  if (!PremiumService().isPremium) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PremiumScreen()),
                    );
                    return;
                  }
                  AdMobService.showInterstitial();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrinterScreen(),
                    ),
                  );
                },
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Premium hint
              if (!PremiumService().isPremium)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium,
                          color: Color(0xFF1A1A2E), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.t('goPremium'),
                              style: const TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.t('removeAdsForever'),
                              style: const TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PremiumScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1A2E),
                          backgroundColor: Colors.black.withOpacity(0.1),
                        ),
                        child: Text(loc.t('getPremium'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
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

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    bool isPremium = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppColors.bgCardDark : AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPremium) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showInterstitialAndOpen() {
    // Show interstitial ad before opening a tool — natural break point
    AdMobService.showInterstitial();
  }
}
