// =============================================================================
// Note Counter Pro - Calculator Screen (Multi-Mode with Bottom Sheet Menu)
// =============================================================================
// Modes: Standard, Scientific, Programmer, Date Calculation
// Converters: 12 types (Currency, Length, Weight, etc.)
// All FREE for all users. Free users see ads (from main.dart top banner),
// premium users don't.
//
// NOTE: This screen does NOT use its own Scaffold — main.dart provides
// the Scaffold with a top banner ad. We use a BottomSheet for mode
// selection instead of a Drawer (Drawer needs its own Scaffold).
// =============================================================================

import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/admob_service.dart';
import 'standard_calculator.dart';
import 'scientific_calculator.dart';
import 'programmer_calculator.dart';
import 'date_calculator.dart';
import 'converter_screen.dart';

class CalculatorScreen extends StatefulWidget {
  final double? initialValue;
  final String currencyCode;

  const CalculatorScreen({
    super.key,
    this.initialValue,
    this.currencyCode = 'INR',
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  int _currentMode = 0; // 0=Standard, 1=Scientific, 2=Programmer, 3=Date
  int _modeChangeCount = 0; // For interstitial ad frequency

  static const _modes = [
    {'icon': Icons.calculate, 'name': 'Standard'},
    {'icon': Icons.science, 'name': 'Scientific'},
    {'icon': Icons.code, 'name': 'Programmer'},
    {'icon': Icons.calendar_today, 'name': 'Date Calc'},
  ];

  static const _converters = [
    {'icon': Icons.currency_exchange, 'name': 'Currency'},
    {'icon': Icons.straighten, 'name': 'Length'},
    {'icon': Icons.scale, 'name': 'Weight & Mass'},
    {'icon': Icons.thermostat, 'name': 'Temperature'},
    {'icon': Icons.bolt, 'name': 'Energy'},
    {'icon': Icons.crop_square, 'name': 'Area'},
    {'icon': Icons.speed, 'name': 'Speed'},
    {'icon': Icons.access_time, 'name': 'Time'},
    {'icon': Icons.flash_on, 'name': 'Power'},
    {'icon': Icons.storage, 'name': 'Data'},
    {'icon': Icons.compress, 'name': 'Pressure'},
    {'icon': Icons.architecture, 'name': 'Angle'},
  ];

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Calculator Modes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Calculator modes grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.0,
                  children: List.generate(_modes.length, (i) {
                    final mode = _modes[i];
                    final selected = i == _currentMode;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        if (i != _currentMode) {
                          _modeChangeCount++;
                          // Show interstitial every 3 mode changes
                          if (_modeChangeCount >= 3) {
                            _modeChangeCount = 0;
                            AdMobService.showInterstitial();
                          }
                          setState(() => _currentMode = i);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withOpacity(0.15)
                              : (theme.brightness == Brightness.dark
                                  ? Colors.grey[850]
                                  : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              mode['icon'] as IconData,
                              size: 28,
                              color: selected ? AppColors.primary : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mode['name'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.bold : null,
                                color: selected ? AppColors.primary : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              // Converter section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Converters',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  children: List.generate(_converters.length, (i) {
                    final conv = _converters[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConverterScreen(initialType: i),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(conv['icon'] as IconData, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                conv['name'] as String,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Top bar: menu icon + mode name
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.apps, size: 24),
                onPressed: _showMenu,
                tooltip: 'Calculator Modes & Converters',
              ),
              Text(
                _modes[_currentMode]['name'] as String,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (widget.initialValue != null && widget.initialValue! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${AppConstants.getCurrencySymbol(widget.currencyCode)}${widget.initialValue!.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Calculator content
        Expanded(
          child: _buildCurrentMode(),
        ),
      ],
    );
  }

  Widget _buildCurrentMode() {
    switch (_currentMode) {
      case 1:
        return const ScientificCalculator();
      case 2:
        return const ProgrammerCalculator();
      case 3:
        return const DateCalculator();
      default:
        return StandardCalculator(
          initialValue: widget.initialValue,
          currencyCode: widget.currencyCode,
        );
    }
  }
}
